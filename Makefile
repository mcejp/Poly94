.PHONY: all sim
.DELETE_ON_ERROR:
TOPMOD  := top
VLOGFIL := $(TOPMOD).v
BINFILE := $(TOPMOD).bin
VDIRFB  := ./obj_dir
all: $(VCDFILE)

GCC := g++
CFLAGS = -g -Wall -I$(VINC) -I $(VDIRFB)
#
# Modern versions of Verilator and C++ may require an -faligned-new flag
# CFLAGS = -g -Wall -faligned-new -I$(VINC) -I $(VDIRFB)

VERILATOR=verilator
VFLAGS := -O3 -MMD --trace -Wall

## Find the directory containing the Verilog sources.  This is given from
## calling: "verilator -V" and finding the VERILATOR_ROOT output line from
## within it.  From this VERILATOR_ROOT value, we can find all the components
## we need here--in particular, the verilator include directory
VERILATOR_ROOT ?= $(shell bash -c '$(VERILATOR) -V|grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')
##
## The directory containing the verilator includes
VINC := $(VERILATOR_ROOT)/include

$(VDIRFB)/V$(TOPMOD).cpp: $(TOPMOD).v
	$(VERILATOR) $(VFLAGS) -cc $(VLOGFIL)

$(VDIRFB)/V$(TOPMOD)__ALL.a: $(VDIRFB)/V$(TOPMOD).cpp
	make --no-print-directory -C $(VDIRFB) -f V$(TOPMOD).mk

$(SIMPROG): $(SIMFILE) $(VDIRFB)/V$(TOPMOD)__ALL.a $(COSIMS)
	$(GCC) $(CFLAGS) $(VINC)/verilated.cpp				\
		$(VINC)/verilated_vcd_c.cpp $(SIMFILE) $(COSIMS)	\
		$(VDIRFB)/V$(TOPMOD)__ALL.a -o $(SIMPROG)

test: $(VCDFILE)

$(VCDFILE): $(SIMPROG)
	./$(SIMPROG)

## 
.PHONY: clean
clean:
	rm -rf $(VDIRFB)/ $(SIMPROG) $(VCDFILE) poly94/ $(BINFILE) $(RPTFILE)
	rm -rf poly94.json ulx3s_out.config ulx3s.bit

##
## Find all of the Verilog dependencies and submodules
##
DEPS := $(wildcard $(VDIRFB)/*.d)

## Include any of these submodules in the Makefile
## ... but only if we are not building the "clean" target
## which would (oops) try to build those dependencies again
##
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(DEPS),)
include $(DEPS)
endif
endif


ulx3s.bit: boot/boot.vh ulx3s_out.config
	ecpbram --from boot/boot_syn.vh --to boot/boot.vh --in ulx3s_out.config --out ulx3s_final.config
	ecppack ulx3s_final.config ulx3s.bit

ulx3s_out.config: poly94.json ulx3s_v20.lpf
	nextpnr-ecp5 --85k --json poly94.json \
		--lpf ulx3s_v20.lpf \
		--textcfg ulx3s_out.config 

boot/boot_syn.vh:
	ecpbram --generate boot/boot_syn.vh --width 32 --depth 1024 --seed 0

poly94.json: poly94.ys \
		rtl/clk_25_250_125_25.v \
		rtl/CPU_Rom.sv \
		rtl/fake_differential.v \
		rtl/hdmi_video.v \
		rtl/pll.v \
		rtl/RGB_Color_Bars_Generator.v \
		rtl/Text_Generator.v \
		rtl/tmds_encoder.v \
		rtl/top.sv \
		rtl/VGA_Timing_Generator.sv \
		rtl/vga2dvid.v \
		rtl/ecp5/ecp5pll.sv \
		rtl/ip/picorv32.v \
		rtl/ip/sdram_pnru.v \
		rtl/ip/VexRiscv.v \
		rtl/ip/uart.sv \
		boot/boot_syn.vh
	yosys -m ghdl poly94.ys

prog: ulx3s.bit
	fujprog ulx3s.bit

sim:
	verilator --top-module top -Irtl -Irtl/ip -Wno-fatal --cc --exe --trace sim/sim_main.cpp rtl/top.sv
	$(MAKE) -C obj_dir -f Vtop.mk -j
	obj_dir/Vtop
