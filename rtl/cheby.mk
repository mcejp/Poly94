ALL_SRC = top.cheby uart.cheby video.cheby

all: \
	generated/top_csr.v \
	../doc/generated/top.html \
	../sdk/include/top.h \
	../sdk/include/uart.h \
	../sdk/include/video.h \

generated/top_csr.v: $(ALL_SRC)
	cheby --gen-hdl --hdl=verilog --no-header -i $< > $@

generated/%.v: %.cheby
	cheby --gen-hdl --hdl=verilog -i $< > $@

../doc/generated/top.html: $(ALL_SRC)
	cheby --gen-doc -i top.cheby > $@

../sdk/include/top.h: $(ALL_SRC)
	cheby --gen-c -i $< > $@

../sdk/include/%.h: %.cheby
	cheby --gen-c -i $< > $@
