#ifndef __CHEBY__VIDEO__H__
#define __CHEBY__VIDEO__H__
#define VIDEO_SIZE 16 /* 0x10 */

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

/* Framebuffer position in screen pixels; placeholder for future implementation */
#define VIDEO_FB_POS 0x8UL
#define VIDEO_FB_POS_Y_MASK 0x3ff0000UL
#define VIDEO_FB_POS_Y_SHIFT 16
#define VIDEO_FB_POS_X_MASK 0x3ffUL
#define VIDEO_FB_POS_X_SHIFT 0

/* Framebuffer dimensions and scaling; placeholder for future implementation */
#define VIDEO_FB_SIZE 0xcUL
#define VIDEO_FB_SIZE_YSCALE_MASK 0xf0000000UL
#define VIDEO_FB_SIZE_YSCALE_SHIFT 28
#define VIDEO_FB_SIZE_HEIGHT_MASK 0x3ff0000UL
#define VIDEO_FB_SIZE_HEIGHT_SHIFT 16
#define VIDEO_FB_SIZE_XSCALE_MASK 0xf000UL
#define VIDEO_FB_SIZE_XSCALE_SHIFT 12
#define VIDEO_FB_SIZE_WIDTH_MASK 0x3ffUL
#define VIDEO_FB_SIZE_WIDTH_SHIFT 0

struct video {
  /* [0x0]: REG (rw) Control register */
  uint32_t CTRL;

  /* [0x4]: REG (rw) Display background color in RGB888 format */
  uint32_t BG_COLOR;

  /* [0x8]: REG (ro) Framebuffer position in screen pixels; placeholder for future implementation */
  uint32_t FB_POS;

  /* [0xc]: REG (ro) Framebuffer dimensions and scaling; placeholder for future implementation */
  uint32_t FB_SIZE;
};

#endif /* __CHEBY__VIDEO__H__ */
