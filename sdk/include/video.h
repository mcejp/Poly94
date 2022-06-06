#ifndef __CHEBY__VIDEO__H__
#define __CHEBY__VIDEO__H__
#define VIDEO_SIZE 8 /* 0x8 */

/* Control register */
#define VIDEO_CTRL 0x0UL
#define VIDEO_CTRL_FB_EN 0x1UL

/* Display background color in RGB888 format */
#define VIDEO_BG_COLOR 0x4UL
#define VIDEO_BG_COLOR_R_MASK 0xff0000UL
#define VIDEO_BG_COLOR_R_SHIFT 16
#define VIDEO_BG_COLOR_G_MASK 0xff00UL
#define VIDEO_BG_COLOR_G_SHIFT 8
#define VIDEO_BG_COLOR_B_MASK 0xffUL
#define VIDEO_BG_COLOR_B_SHIFT 0

struct video {
  /* [0x0]: REG (rw) Control register */
  uint32_t CTRL;

  /* [0x4]: REG (rw) Display background color in RGB888 format */
  uint32_t BG_COLOR;
};

#endif /* __CHEBY__VIDEO__H__ */
