
module top_csr
  (
    input   wire rst_n_i,
    input   wire clk_i,
    input   wire wb_cyc_i,
    input   wire wb_stb_i,
    input   wire [5:2] wb_adr_i,
    input   wire [3:0] wb_sel_i,
    input   wire wb_we_i,
    input   wire [31:0] wb_dat_i,
    output  wire wb_ack_o,
    output  wire wb_err_o,
    output  wire wb_rty_o,
    output  wire wb_stall_o,
    output  reg [31:0] wb_dat_o,

    // Interrupt enable
    // HSYNC interrupt enabled
    output  wire SYS_IE_HSYNC_o,
    // VSYNC interrupt enabled
    output  wire SYS_IE_VSYNC_o,

    // Interrupt pending
    // HSYNC interrupt pending
    input   wire SYS_IP_HSYNC_i,
    output  wire SYS_IP_HSYNC_o,
    // VSYNC interrupt pending
    input   wire SYS_IP_VSYNC_i,
    output  wire SYS_IP_VSYNC_o,
    output  wire SYS_IP_wr_o,

    // REG STATUS
    // Indicates whether the transmitter is busy (1) or ready to send data (0)
    input   wire UART_STATUS_TX_BUSY_i,
    // Indicates whether the receive FIFO (currently single-element) contains data received
    input   wire UART_STATUS_RX_NOT_EMPTY_i,

    // REG DATA
    // Read to pop byte from the receive FIFO (requiring RX_NOT_EMPTY == 1).
    // Write to send a character (requiring TX_BUSY == 0).
    // The transmission is always 8-bit.

    input   wire [7:0] UART_DATA_DATA_i,
    output  wire [7:0] UART_DATA_DATA_o,
    output  wire UART_DATA_wr_o,
    output  reg UART_DATA_rd_o,

    // Control register
    // Write 1 to enable framebuffer display.
    // Note that this reduces system performance since the GPU needs to contend with CPU over the SDRAM bus.

    output  wire VIDEO_CTRL_FB_EN_o,

    // Display background color in RGB888 format
    // Red component
    output  wire [7:0] VIDEO_BG_COLOR_R_o,
    // Green component
    output  wire [7:0] VIDEO_BG_COLOR_G_o,
    // Blue component
    output  wire [7:0] VIDEO_BG_COLOR_B_o
  );
  wire rd_req_int;
  wire wr_req_int;
  reg rd_ack_int;
  reg wr_ack_int;
  wire wb_en;
  wire ack_int;
  reg wb_rip;
  reg wb_wip;
  reg SYS_IE_HSYNC_reg;
  reg SYS_IE_VSYNC_reg;
  reg SYS_IE_wreq;
  reg SYS_IE_wack;
  reg SYS_IP_wreq;
  reg UART_DATA_wreq;
  reg VIDEO_CTRL_FB_EN_reg;
  reg VIDEO_CTRL_wreq;
  reg VIDEO_CTRL_wack;
  reg [7:0] VIDEO_BG_COLOR_R_reg;
  reg [7:0] VIDEO_BG_COLOR_G_reg;
  reg [7:0] VIDEO_BG_COLOR_B_reg;
  reg VIDEO_BG_COLOR_wreq;
  reg VIDEO_BG_COLOR_wack;
  reg rd_ack_d0;
  reg [31:0] rd_dat_d0;
  reg wr_req_d0;
  reg [5:2] wr_adr_d0;
  reg [31:0] wr_dat_d0;

  // WB decode signals
  assign wb_en = wb_cyc_i & wb_stb_i;

  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      wb_rip <= 1'b0;
    else
      wb_rip <= (wb_rip | (wb_en & !wb_we_i)) & !rd_ack_int;
  end
  assign rd_req_int = (wb_en & !wb_we_i) & !wb_rip;

  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      wb_wip <= 1'b0;
    else
      wb_wip <= (wb_wip | (wb_en & wb_we_i)) & !wr_ack_int;
  end
  assign wr_req_int = (wb_en & wb_we_i) & !wb_wip;

  assign ack_int = rd_ack_int | wr_ack_int;
  assign wb_ack_o = ack_int;
  assign wb_stall_o = !ack_int & wb_en;
  assign wb_rty_o = 1'b0;
  assign wb_err_o = 1'b0;

  // pipelining for wr-in+rd-out
  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      begin
        rd_ack_int <= 1'b0;
        wr_req_d0 <= 1'b0;
      end
    else
      begin
        rd_ack_int <= rd_ack_d0;
        wb_dat_o <= rd_dat_d0;
        wr_req_d0 <= wr_req_int;
        wr_adr_d0 <= wb_adr_i;
        wr_dat_d0 <= wb_dat_i;
      end
  end

  // Register SYS_DEBUG

  // Register SYS_IE
  assign SYS_IE_HSYNC_o = SYS_IE_HSYNC_reg;
  assign SYS_IE_VSYNC_o = SYS_IE_VSYNC_reg;
  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      begin
        SYS_IE_HSYNC_reg <= 1'b0;
        SYS_IE_VSYNC_reg <= 1'b0;
        SYS_IE_wack <= 1'b0;
      end
    else
      begin
        if (SYS_IE_wreq == 1'b1)
          begin
            SYS_IE_HSYNC_reg <= wr_dat_d0[0];
            SYS_IE_VSYNC_reg <= wr_dat_d0[1];
          end
        SYS_IE_wack <= SYS_IE_wreq;
      end
  end

  // Register SYS_IP
  assign SYS_IP_HSYNC_o = wr_dat_d0[0];
  assign SYS_IP_VSYNC_o = wr_dat_d0[1];
  assign SYS_IP_wr_o = SYS_IP_wreq;

  // Register UART_STATUS

  // Register UART_DATA
  assign UART_DATA_DATA_o = wr_dat_d0[7:0];
  assign UART_DATA_wr_o = UART_DATA_wreq;

  // Register VIDEO_CTRL
  assign VIDEO_CTRL_FB_EN_o = VIDEO_CTRL_FB_EN_reg;
  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      begin
        VIDEO_CTRL_FB_EN_reg <= 1'b0;
        VIDEO_CTRL_wack <= 1'b0;
      end
    else
      begin
        if (VIDEO_CTRL_wreq == 1'b1)
          VIDEO_CTRL_FB_EN_reg <= wr_dat_d0[0];
        VIDEO_CTRL_wack <= VIDEO_CTRL_wreq;
      end
  end

  // Register VIDEO_BG_COLOR
  assign VIDEO_BG_COLOR_R_o = VIDEO_BG_COLOR_R_reg;
  assign VIDEO_BG_COLOR_G_o = VIDEO_BG_COLOR_G_reg;
  assign VIDEO_BG_COLOR_B_o = VIDEO_BG_COLOR_B_reg;
  always @(posedge(clk_i) or negedge(rst_n_i))
  begin
    if (!rst_n_i)
      begin
        VIDEO_BG_COLOR_R_reg <= 8'b00000000;
        VIDEO_BG_COLOR_G_reg <= 8'b00000000;
        VIDEO_BG_COLOR_B_reg <= 8'b00000000;
        VIDEO_BG_COLOR_wack <= 1'b0;
      end
    else
      begin
        if (VIDEO_BG_COLOR_wreq == 1'b1)
          begin
            VIDEO_BG_COLOR_R_reg <= wr_dat_d0[23:16];
            VIDEO_BG_COLOR_G_reg <= wr_dat_d0[15:8];
            VIDEO_BG_COLOR_B_reg <= wr_dat_d0[7:0];
          end
        VIDEO_BG_COLOR_wack <= VIDEO_BG_COLOR_wreq;
      end
  end

  // Register VIDEO_FB_POS

  // Register VIDEO_FB_SIZE

  // Process for write requests.
  always @(wr_adr_d0, wr_req_d0, SYS_IE_wack, VIDEO_CTRL_wack, VIDEO_BG_COLOR_wack)
      begin
        SYS_IE_wreq <= 1'b0;
        SYS_IP_wreq <= 1'b0;
        UART_DATA_wreq <= 1'b0;
        VIDEO_CTRL_wreq <= 1'b0;
        VIDEO_BG_COLOR_wreq <= 1'b0;
        case (wr_adr_d0[5:2])
        4'b0000:
          // Reg SYS_DEBUG
          wr_ack_int <= wr_req_d0;
        4'b0001:
          begin
            // Reg SYS_IE
            SYS_IE_wreq <= wr_req_d0;
            wr_ack_int <= SYS_IE_wack;
          end
        4'b0010:
          begin
            // Reg SYS_IP
            SYS_IP_wreq <= wr_req_d0;
            wr_ack_int <= wr_req_d0;
          end
        4'b0100:
          // Reg UART_STATUS
          wr_ack_int <= wr_req_d0;
        4'b0101:
          begin
            // Reg UART_DATA
            UART_DATA_wreq <= wr_req_d0;
            wr_ack_int <= wr_req_d0;
          end
        4'b1000:
          begin
            // Reg VIDEO_CTRL
            VIDEO_CTRL_wreq <= wr_req_d0;
            wr_ack_int <= VIDEO_CTRL_wack;
          end
        4'b1001:
          begin
            // Reg VIDEO_BG_COLOR
            VIDEO_BG_COLOR_wreq <= wr_req_d0;
            wr_ack_int <= VIDEO_BG_COLOR_wack;
          end
        4'b1010:
          // Reg VIDEO_FB_POS
          wr_ack_int <= wr_req_d0;
        4'b1011:
          // Reg VIDEO_FB_SIZE
          wr_ack_int <= wr_req_d0;
        default:
          wr_ack_int <= wr_req_d0;
        endcase
      end

  // Process for read requests.
  always @(wb_adr_i, rd_req_int, SYS_IE_HSYNC_reg, SYS_IE_VSYNC_reg, SYS_IP_HSYNC_i, SYS_IP_VSYNC_i, UART_STATUS_TX_BUSY_i, UART_STATUS_RX_NOT_EMPTY_i, UART_DATA_DATA_i, VIDEO_CTRL_FB_EN_reg, VIDEO_BG_COLOR_B_reg, VIDEO_BG_COLOR_G_reg, VIDEO_BG_COLOR_R_reg)
      begin
        // By default ack read requests
        rd_dat_d0 <= {32{1'bx}};
        UART_DATA_rd_o <= 1'b0;
        case (wb_adr_i[5:2])
        4'b0000:
          begin
            // Reg SYS_DEBUG
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0 <= 32'b00000000000000000000000000000000;
          end
        4'b0001:
          begin
            // Reg SYS_IE
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[0] <= SYS_IE_HSYNC_reg;
            rd_dat_d0[1] <= SYS_IE_VSYNC_reg;
            rd_dat_d0[31:2] <= 30'b0;
          end
        4'b0010:
          begin
            // Reg SYS_IP
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[0] <= SYS_IP_HSYNC_i;
            rd_dat_d0[1] <= SYS_IP_VSYNC_i;
            rd_dat_d0[31:2] <= 30'b0;
          end
        4'b0100:
          begin
            // Reg UART_STATUS
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[0] <= UART_STATUS_TX_BUSY_i;
            rd_dat_d0[1] <= UART_STATUS_RX_NOT_EMPTY_i;
            rd_dat_d0[31:2] <= 30'b0;
          end
        4'b0101:
          begin
            // Reg UART_DATA
            UART_DATA_rd_o <= rd_req_int;
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[7:0] <= UART_DATA_DATA_i;
            rd_dat_d0[31:8] <= 24'b0;
          end
        4'b1000:
          begin
            // Reg VIDEO_CTRL
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[0] <= VIDEO_CTRL_FB_EN_reg;
            rd_dat_d0[31:1] <= 31'b0;
          end
        4'b1001:
          begin
            // Reg VIDEO_BG_COLOR
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[7:0] <= VIDEO_BG_COLOR_B_reg;
            rd_dat_d0[15:8] <= VIDEO_BG_COLOR_G_reg;
            rd_dat_d0[23:16] <= VIDEO_BG_COLOR_R_reg;
            rd_dat_d0[31:24] <= 8'b0;
          end
        4'b1010:
          begin
            // Reg VIDEO_FB_POS
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[9:0] <= 10'b0000000000;
            rd_dat_d0[15:10] <= 6'b0;
            rd_dat_d0[25:16] <= 10'b0000000000;
            rd_dat_d0[31:26] <= 6'b0;
          end
        4'b1011:
          begin
            // Reg VIDEO_FB_SIZE
            rd_ack_d0 <= rd_req_int;
            rd_dat_d0[9:0] <= 10'b0101000000;
            rd_dat_d0[11:10] <= 2'b0;
            rd_dat_d0[15:12] <= 4'b0000;
            rd_dat_d0[25:16] <= 10'b0011110000;
            rd_dat_d0[27:26] <= 2'b0;
            rd_dat_d0[31:28] <= 4'b0000;
          end
        default:
          rd_ack_d0 <= rd_req_int;
        endcase
      end
endmodule
