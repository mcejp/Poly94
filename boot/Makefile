TOOLCHAIN=riscv-none-embed-
ARCHFLAGS=-march=rv32i -mabi=ilp32

AS=$(TOOLCHAIN)as
CC=$(TOOLCHAIN)gcc
LD=$(TOOLCHAIN)ld
OBJCOPY=$(TOOLCHAIN)objcopy
OBJDUMP=$(TOOLCHAIN)objdump
SIZE=$(TOOLCHAIN)size
STRIP=$(TOOLCHAIN)strip

CFLAGS=-I../sdk/include -ffreestanding -ffunction-sections -fdata-sections -Os -Wall -Werror
LDFLAGS=-Wl,--gc-sections -nostartfiles -nostdlib

OUTPUT=boot.bin
OUTPUT_VH=boot.vh
ELF=boot.elf
OBJS=boot.o start.o

all: $(OUTPUT) $(OUTPUT_VH)

clean:
	rm -f $(OUTPUT) $(ELF) *.o

$(OUTPUT): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(OUTPUT_VH): $(OUTPUT)
	#$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@  # hopelessly broken
	hexdump -v -e '1/4 "%08x\n"' $< > $@

$(ELF): $(OBJS) boot.ld
	$(CC) $(ARCHFLAGS) $(LDFLAGS) -T boot.ld -o $@ $(OBJS) -lgcc
	$(OBJDUMP) -D $@ >boot.objdump.txt
	$(SIZE) $@

%.o: %.c 
	$(CC) $(ARCHFLAGS) $(CFLAGS) -c -o $@ $<

%.o: %.s
	$(AS) $(ARCHFLAGS) -c -o $@ $<

.PHONY: all clean
