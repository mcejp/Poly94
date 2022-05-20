## Memory map

    0x0000_0000 .. 0x0000_ffff   64k  Trap region (currently not implemented)

    0x0100_0000 .. 0x0100_0fff    4k  System control registers

    0x0700_0000 .. 0x0700_0fff    4k  Boot ROM
    0x0700_1000 .. 0x07ff_ffff        (images)

    0x0800_0000 .. 0x09ff_ffff   32M  SDRAM
    0x0a00_0000 .. 0x0fff_ffff   96M  (images)

    0x8000_0000 .. 0xffff_ffff        uncached mirror of the lower half
                                      (note: instructions are always cached)


Note: should take advantage of RV32's single-instruction calls relative to x0 to place some
      commonly needed library functions (if GCC is able to benefit from them)

TODO: reorganize memory map so that SDRAM addresses are more easily recognizable.
      The '8' is confusing since it is also bit 31 for cache bypass.

## Decoding table

    bit  31     -> cache bypass
    bits 27..24 -> region (4 bits)
                    0 = trap
                    1 = I/O space
                    7 = rom
                    8..f = sdram    (in other words: bit 27 -> SDRAM(1) / non-SDRAM(0))
    bit  23..0  -> address within 16M region
                    (not necessarily fully decoded)

CPU external address bus is effectively 28 bits wide.


## Detailed description

### System control registers

0x0100_0000  TRACE_REG
  - write to send on UART (8 bits)
  - read to see if UART busy (1) or idle (0)

0x0100_0004  BG_COLOR
  - write to set background color (24-bit)


---

Some inspiration:

- https://psx-spx.consoledev.net/memorymap/
- https://ultra64.ca/files/tools/DETAILED_N64_MEMORY_MAP.txt
- https://problemkaputt.de/gbatek.htm#dsmemorymaps
