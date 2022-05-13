
0x0000_0000 .. 0x0000_0fff    4k  Boot ROM
0x0000_1000 .. 0x0000_1fff    4k  System registers

0x4000_0000 .. 0x40ff_ffff   16M  SDRAM


0x0000_1000  TRACE_REG
  - write to send on UART (8 bits)
  - read to see if UART busy (1) or idle (0)

0x0000_1004  BG_COLOR
  - write to set background color (24-bit)
