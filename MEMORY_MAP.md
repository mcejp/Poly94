## Memory map

    0x0000_0000 .. 0x0000_ffff   64k  Trap region (currently not implemented)

    0x0100_0000 .. 0x0100_0fff    4k  System control registers

    0x0300_0000 .. 0x0300_0fff    4k  Boot ROM
    0x0300_1000 .. 0x03ff_ffff        (images)

    0x0400_0000 .. 0x05ff_ffff   32M  SDRAM
    0x0600_0000 .. 0x07ff_ffff   32M  (image)

    0x8000_0000 .. 0xffff_ffff        uncached mirror of the lower half
                                      (note: instructions are always cached)


Note: might want to take advantage of RV32's single-instruction calls relative to x0 to place some
      commonly needed library functions (if GCC is able to benefit from them)

## Decoding table

    bit  31     -> cache bypass
    bits 26..24 -> region (3 bits)
                    0 = trap
                    1 = I/O space
                    3 = rom
                    4..7 = sdram    (in other words: bit 26 -> SDRAM(1) / non-SDRAM(0))
    bit  23..0  -> address within 16M region
                    (not necessarily fully decoded)

CPU external address bus is effectively 28 bits wide.


## Detailed description

### Control/status registers

See doc/generated/top.html.


---

Some inspiration:

- https://psx-spx.consoledev.net/memorymap/
- https://ultra64.ca/files/tools/DETAILED_N64_MEMORY_MAP.txt
- https://problemkaputt.de/gbatek.htm#dsmemorymaps
