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


ulx3s.bit: firmware/build/boot.vh ulx3s_out.config
	ecpbram --from build/boot_syn.vh --to firmware/build/boot.vh --in ulx3s_out.config --out ulx3s_final.config
	ecppack ulx3s_final.config ulx3s.bit

ulx3s_out.config: poly94.json ulx3s_v20.lpf
	mkdir -p build
	nextpnr-ecp5 --85k --json poly94.json \
		--lpf ulx3s_v20.lpf \
		--textcfg ulx3s_out.config \
		--report build/nextpnr-report.json \
		2>&1 | tee nextpnr.log

build/boot_syn.vh:
	mkdir -p build
	ecpbram --generate build/boot_syn.vh --width 32 --depth 1024 --seed 0

poly94.json: poly94.ys \
		lib/verilog-uart/rtl/uart_rx.v \
		lib/verilog-uart/rtl/uart_tx.v \
		lib/verilog-uart/rtl/uart.v \
		rtl/clk_25_250_125_25.v \
		rtl/CPU_Rom.sv \
		rtl/fake_differential.v \
		rtl/hdmi_video.v \
		rtl/Memory_Ctrl.sv \
		rtl/pll.v \
		rtl/RGB_Color_Bars_Generator.v \
		rtl/Sdram_Arbiter.sv \
		rtl/Text_Generator.v \
		rtl/tmds_encoder.v \
		rtl/top.sv \
		rtl/VGA_Timing_Generator.sv \
		rtl/vga2dvid.v \
		rtl/Video_Ctrl.sv \
		rtl/ecp5/ecp5pll.sv \
		rtl/generated/VexRiscv.v \
		rtl/ip/sdram_pnru.v \
		build/boot_syn.vh
	yosys -m ghdl poly94.ys | tee yosys.log

prog: ulx3s.bit
	fujprog ulx3s.bit

sim:
	verilator --assert --top-module top -Ilib/verilog-uart/rtl -Irtl -Irtl/ip -Wall -Wwarn-style -Wno-fatal --cc --exe --trace sim/sim_main.cpp sim/sdr_sdram/sdr_sdram.cpp rtl/top.sv
	$(MAKE) -C obj_dir -f Vtop.mk -j
	obj_dir/Vtop
