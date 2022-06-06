package uart_Consts;
  localparam UART_SIZE = 8;
  localparam ADDR_UART_STATUS = 'h0;
  localparam UART_STATUS_TX_BUSY_OFFSET = 0;
  localparam UART_STATUS_TX_BUSY = 32'h1;
  localparam UART_STATUS_RX_NOT_EMPTY_OFFSET = 1;
  localparam UART_STATUS_RX_NOT_EMPTY = 32'h2;
  localparam ADDR_UART_DATA = 'h4;
  localparam UART_DATA_DATA_OFFSET = 0;
  localparam UART_DATA_DATA = 32'hff;
endpackage
