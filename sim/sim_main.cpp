#include "Vtop.h"
#include "verilated.h"
#include <verilated_vcd_c.h>

int main(int argc, char** argv, char** env) {
   Verilated::commandArgs(argc, argv);
   Verilated::traceEverOn(true);

   Vtop top;
   top.clk_25mhz = 0;
   // top.rootp->cpu.resetn = 0;

   VerilatedVcdC trace;
   top.trace(&trace, 99);

   trace.open("sim.vcd");

   for (int i = 0; i < 3000 && !Verilated::gotFinish(); i++) {
      // if (i > 10) {
      //    top.rootp->cpu.resetn = 1;
      // }
      top.clk_25mhz = !top.clk_25mhz;
      top.eval();
      trace.dump(10 * i);
   }

   trace.close();
   return 0;
}
