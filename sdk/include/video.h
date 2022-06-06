#ifndef __CHEBY__VIDEO__H__
#define __CHEBY__VIDEO__H__
#define VIDEO_SIZE 8 /* 0x8 */

/* None */
#define VIDEO_CTRL 0x0UL
#define VIDEO_CTRL_FB_EN 0x1UL

/* None */
#define VIDEO_BG_COLOR 0x4UL
#define VIDEO_BG_COLOR_COLOR_MASK 0xffffffUL
#define VIDEO_BG_COLOR_COLOR_SHIFT 0

struct video {
  /* [0x0]: REG (wo) (no description) */
  uint32_t CTRL;

  /* [0x4]: REG (rw) (no description) */
  uint32_t BG_COLOR;
};

#endif /* __CHEBY__VIDEO__H__ */
