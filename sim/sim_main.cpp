#include "sdr_sdram/sdr_sdram.h"
#include "write_ppm.hpp"

#include "Vtop.h"
#include "Vtop_top.h"
#include "Vtop_CPU_Rom.h"
#include "verilated.h"
#include <verilated_vcd_c.h>

#include <array>
#include <sstream>


// SDRAM size
#define SDRAM_BIT_ROWS     (13)
#define SDRAM_BIT_COLS     (9)
#define SDRAM_SIZE         (2 << (SDRAM_BIT_ROWS + SDRAM_BIT_COLS + SDRAM_BIT_BANKS))


int main(int argc, char** argv, char** env) {
   Verilated::commandArgs(argc, argv);
   Verilated::traceEverOn(true);

   // TODO: argument parsing
   auto maybe_rom_filename = getenv("BOOTROM");
   auto maybe_framebuffer_dump_filename = getenv("DUMP_FRAMEBUF");
   auto maybe_num_cycles_str = getenv("NUM_CYCLES");

   //

   long half_cycle = 0;
   long max_half_cycles = 10'000;

   if (maybe_num_cycles_str != nullptr) {
      max_half_cycles = 2 * std::stol(maybe_num_cycles_str);
   }

   // Init SDRAM C++ model (8192 rows, 512 cols)
   vluint8_t sdram_flags = FLAG_DATA_WIDTH_16; // | FLAG_BANK_INTERLEAVING | FLAG_BIG_ENDIAN;
   SDRAM* sdr  = new SDRAM(SDRAM_BIT_ROWS, SDRAM_BIT_COLS, sdram_flags, nullptr /*"sdram.log"*/);

   std::array<uint32_t, 640 * 480> framebuffer {};
   int pixel_i;

   std::stringstream uart_line;

   Vtop top;
   top.clk_25mhz = 0;
   // top.rootp->cpu.resetn = 0;

   VerilatedVcdC trace;
   top.trace(&trace, 99);

   // trace.open("sim.vcd");

   // execute $initial commands -- must be done before loading ROM or forcing any registers
   top.eval();

   // Boot ROM

   if (maybe_rom_filename != nullptr) {
      std::ifstream f(maybe_rom_filename, std::ios::binary);
      if (!f) {
         throw std::runtime_error("Failed to open BOOTROM");
      }
      f.read((char*) &top.top->bootrom->rom[0], sizeof(top.top->bootrom->rom));
      printf("Loaded %d bytes from %s\n", f.gcount(), maybe_rom_filename);
   }

   for (half_cycle = 0; half_cycle < max_half_cycles && !Verilated::gotFinish(); half_cycle++) {
      // if (i > 10) {
      //    top.rootp->cpu.resetn = 1;
      // }
      top.clk_25mhz = !top.clk_25mhz;
      top.eval();
      trace.dump((uint64_t)10 * half_cycle);

      // Evaluate SDRAM C++ model
      vluint64_t sdram_q = 0;
      sdr->eval(half_cycle,
                top.sdram_clk ^ 1, 1,
                top.sdram_csn,  top.sdram_rasn, top.sdram_casn, top.sdram_wen,
                top.sdram_ba,   top.sdram_a,
                top.sdram_dqm, (vluint64_t)top.top->sdr_d,  sdram_q);
      // SDRAM tri-state output
      top.sdram_d = (top.top->sdr_dq_oe) ? top.top->sdr_d : (vluint16_t)sdram_q;

      // UART
      if (top.clk_25mhz && !top.top->uart_tx_busy && top.top->uart_tx_strobe) {
         char c = top.top->uart_tx_data;

         if (c == '\n') {         
            printf("UART  | %s\n", uart_line.str().c_str());
            uart_line.str("");
         }
         else {
            uart_line << c;
         }
      }

      if (top.clk_25mhz && (top.top->timing1 & (1<<2))) {
         if (pixel_i >= 640 * 480) {
               printf("%9ld testbench: begin new frame\n", half_cycle / 2);
               pixel_i = 0;
         }

         framebuffer[pixel_i] = top.top->color2;
         pixel_i++;
      }
   }

   fprintf(stderr, "Simulated %ld cycles\n", half_cycle / 2);

   trace.close();

   if (maybe_framebuffer_dump_filename != nullptr) {
      write_ppm(maybe_framebuffer_dump_filename, 640, 480, &framebuffer[0]);
      fprintf(stderr, "Saved %s\n", maybe_framebuffer_dump_filename);
   }

   if (!uart_line.str().empty()) {
      printf("UART  | %s\n", uart_line.str().c_str());
   }

   return 0;
}
