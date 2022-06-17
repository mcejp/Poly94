#ifndef __CHEBY__SYS__H__
#define __CHEBY__SYS__H__
#define SYS_SIZE 12 /* 0xc */

/* TODO */
#define SYS_DEBUG 0x0UL
#define SYS_DEBUG_PRESET 0x0UL

/* Interrupt enable */
#define SYS_IE 0x4UL
#define SYS_IE_HSYNC 0x1UL
#define SYS_IE_VSYNC 0x2UL

/* Interrupt pending */
#define SYS_IP 0x8UL
#define SYS_IP_HSYNC 0x1UL
#define SYS_IP_VSYNC 0x2UL

struct sys {
  /* [0x0]: REG (ro) TODO */
  uint32_t DEBUG;

  /* [0x4]: REG (rw) Interrupt enable */
  uint32_t IE;

  /* [0x8]: REG (rw) Interrupt pending */
  uint32_t IP;
};

#endif /* __CHEBY__SYS__H__ */
