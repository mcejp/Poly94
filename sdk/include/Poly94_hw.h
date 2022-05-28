#ifndef POLY94_HW_H
#define POLY94_HW_H

#include <stdint.h>

/* memory map */

enum { SDRAM_START          = 0x04000000 };

/* I/O region (with cache bypass bit set) */

#define TRACE_REG           (*(uint32_t volatile*)0x81000000)
#define BG_COLOR            (*(uint32_t volatile*)0x81000004)
#define UART_DATA           (*(uint32_t volatile*)0x81000008)
#define VIDEO_CTRL          (*(uint32_t volatile*)0x8100000c)

enum { UART_TX_BUSY         = 0x01 };
enum { UART_RX_NOT_EMPTY    = 0x02 };

enum { VIDEO_CTRL_FB_EN     = 0x01 };

#endif
