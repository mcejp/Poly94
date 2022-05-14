#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv, char** env) {   
   Vtop top;
   top.clk_25mhz = 0;
   // top.rootp->cpu.resetn = 0;

   for (int i = 0; i < 1000 && !Verilated::gotFinish(); i++) {
      // if (i > 10) {
      //    top.rootp->cpu.resetn = 1;
      // }
      top.clk_25mhz = !top.clk_25mhz;
      top.eval();
   }
   return 0;
}
