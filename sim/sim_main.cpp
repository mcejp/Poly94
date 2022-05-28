#include "sdr_sdram/sdr_sdram.h"
#include "write_ppm.hpp"

#include "Vtop.h"
#include "Vtop_top.h"
#include "verilated.h"
#include <verilated_vcd_c.h>

#include <array>


// SDRAM size
#define SDRAM_BIT_ROWS     (13)
#define SDRAM_BIT_COLS     (9)
#define SDRAM_SIZE         (2 << (SDRAM_BIT_ROWS + SDRAM_BIT_COLS + SDRAM_BIT_BANKS))


int main(int argc, char** argv, char** env) {
   Verilated::commandArgs(argc, argv);
   Verilated::traceEverOn(true);

   // Init SDRAM C++ model (8192 rows, 512 cols)
   vluint8_t sdram_flags = FLAG_DATA_WIDTH_16; // | FLAG_BANK_INTERLEAVING | FLAG_BIG_ENDIAN;
   SDRAM* sdr  = new SDRAM(SDRAM_BIT_ROWS, SDRAM_BIT_COLS, sdram_flags, nullptr /*"sdram.log"*/);

   std::array<uint32_t, 640 * 480> framebuffer {};
   int pixel_i;

   Vtop top;
   top.clk_25mhz = 0;
   // top.rootp->cpu.resetn = 0;

   VerilatedVcdC trace;
   top.trace(&trace, 99);

   trace.open("sim.vcd");

   for (int i = 0; i < 10'000 && !Verilated::gotFinish(); i++) {
      // if (i > 10) {
      //    top.rootp->cpu.resetn = 1;
      // }
      top.clk_25mhz = !top.clk_25mhz;
      top.eval();
      trace.dump(10 * i);

      // Evaluate SDRAM C++ model
      vluint64_t sdram_q = 0;
      sdr->eval(i,
                top.sdram_clk ^ 1, 1,
                top.sdram_csn,  top.sdram_rasn, top.sdram_casn, top.sdram_wen,
                top.sdram_ba,   top.sdram_a,
                top.sdram_dqm, (vluint64_t)top.top->sdr_d,  sdram_q);
      // SDRAM tri-state output
      top.sdram_d = (top.top->sdr_dq_oe) ? top.top->sdr_d : (vluint16_t)sdram_q;

      // UART
      if (top.clk_25mhz && !top.top->uart_tx_busy && top.top->uart_tx_strobe) {
         printf("UART  | %c\n", (int) top.top->uart_tx_data);
      }

      if (top.clk_25mhz && (top.top->timing1 & (1<<2))) {
         if (pixel_i >= 640 * 480) {
               printf("%9d testbench: begin new frame\n", i);
               pixel_i = 0;
         }

         framebuffer[pixel_i] = top.top->color2;
         pixel_i++;
      }
   }

   trace.close();

   write_ppm("framebuffer.ppm", 640, 480, &framebuffer[0]);

   return 0;
}
