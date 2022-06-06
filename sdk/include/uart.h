#ifndef __CHEBY__UART__H__
#define __CHEBY__UART__H__
#define UART_SIZE 8 /* 0x8 */

/* None */
#define UART_STATUS 0x0UL
#define UART_STATUS_TX_BUSY 0x1UL
#define UART_STATUS_RX_NOT_EMPTY 0x2UL

/* None */
#define UART_DATA 0x4UL
#define UART_DATA_DATA_MASK 0xffUL
#define UART_DATA_DATA_SHIFT 0

struct uart {
  /* [0x0]: REG (ro) (no description) */
  uint32_t STATUS;

  /* [0x4]: REG (rw) (no description) */
  uint32_t DATA;
};

#endif /* __CHEBY__UART__H__ */
