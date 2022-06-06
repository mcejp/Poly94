ALL_SRC = top.cheby uart.cheby video.cheby

all: \
	generated/top.v \
	generated/top_inc.sv \
	generated/uart_inc.sv \
	generated/video_inc.sv \
	../doc/generated/top.html \
	../sdk/include/top.h \
	../sdk/include/uart.h \
	../sdk/include/video.h \

generated/%_inc.sv: %.cheby
	cheby --gen-const --consts-style=sv -i $< > $@

generated/top.v: $(ALL_SRC)
	cheby --gen-hdl --hdl=verilog --no-header -i $< > $@

generated/%.v: %.cheby
	cheby --gen-hdl --hdl=verilog -i $< > $@

../doc/generated/top.html: $(ALL_SRC)
	cheby --gen-doc -i top.cheby > $@

../sdk/include/top.h: $(ALL_SRC)
	cheby --gen-c -i $< > $@

../sdk/include/%.h: %.cheby
	cheby --gen-c -i $< > $@
