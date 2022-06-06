#ifndef __CHEBY__TOP__H__
#define __CHEBY__TOP__H__

#include "uart.h"
#include "video.h"
#define TOP_SIZE 40 /* 0x28 */

/* An included submap */
#define TOP_UART 0x10UL
#define ADDR_MASK_TOP_UART 0x38UL
#define TOP_UART_SIZE 8 /* 0x8 */

/* An included submap */
#define TOP_VIDEO 0x20UL
#define ADDR_MASK_TOP_VIDEO 0x38UL
#define TOP_VIDEO_SIZE 8 /* 0x8 */

struct top {

  /* padding to: 4 words */
  uint32_t __padding_0[4];
  /* [0x10]: SUBMAP An included submap */
  struct uart UART;

  /* padding to: 8 words */
  uint32_t __padding_1[2];

  /* [0x20]: SUBMAP An included submap */
  struct video VIDEO;
};

#endif /* __CHEBY__TOP__H__ */
