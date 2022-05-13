
0..0x1000 -> Program ROM (4k)

0x1000  TRACE_REG
  - write to send on UART (8 bits)
  - read to see if UART busy (1) or idle (0)

0x1004  BG_COLOR
  - write to set background color (24-bit)
