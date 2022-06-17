ALL_SRC = sys.cheby top.cheby uart.cheby video.cheby

all: \
	generated/top_csr.v \
	../doc/generated/top.html \
	../sdk/include/top.h \
	../sdk/include/sys.h \
	../sdk/include/uart.h \
	../sdk/include/video.h \

generated/top_csr.v: $(ALL_SRC)
	cheby --gen-hdl --hdl=verilog --no-header -i top.cheby > $@

generated/%.v: %.cheby
	cheby --gen-hdl --hdl=verilog -i $< > $@

../doc/generated/top.html: top_doc.cheby $(ALL_SRC)
	cheby --gen-doc -i $< > $@

../sdk/include/top.h: $(ALL_SRC)
	cheby --gen-c -i top.cheby > $@

../sdk/include/%.h: %.cheby
	cheby --gen-c -i $< > $@
