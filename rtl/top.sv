`default_nettype none
`include "VGA_Timing.sv"

module top
(
    input clk_sys,

    output [7:0] led,

    // SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output sdram_csn,       // chip select
    output sdram_cke,       // clock enable to SDRAM
    output sdram_rasn,      // SDRAM RAS
    output sdram_casn,      // SDRAM CAS
    output sdram_wen,       // SDRAM write-enable
    output [12:0] sdram_a,  // SDRAM address bus
    output [1:0] sdram_ba,  // SDRAM bank-address
    output [1:0] sdram_dqm, // byte select
    inout [15:0] sdram_d,   // data bus to/from SDRAM

    output ftdi_rxd,
    input ftdi_txd,

    output hsync_n_o,
    output vsync_n_o,
    output blank_n_o,
    output[23:0] vga_color_o
);
    parameter CLK_SYS_HZ = 50_000_000;

`ifndef SYNTHESIS
    wire pixel_valid /* verilator public */ = timing1.blank_n == 1 && timing1.valid;
`endif

    assign sdram_cke = 1'b1;

    // Memory control-related
    reg         sdram_rd;
    reg         sdram_wr;
    wire[23:0]  sdram_addr_x16;
    wire[15:0]  sdram_wdata;
    wire[15:0]  sdram_rdata;
    wire        sdram_ack;
    wire        sdram_rdy;
    wire[1:0]   sdram_wmask;
    wire        sdram_burst;

    wire[15:0]  sdr_d           /* verilator public */;
    wire        sdr_dq_oe       /* verilator public */;

    wire        cpu_sdram_rd;
    wire        cpu_sdram_wr;
    wire[23:0]  cpu_sdram_addr_x16;
    wire[15:0]  cpu_sdram_wdata;
    wire[15:0]  cpu_sdram_rdata;
    wire        cpu_sdram_ack;
    wire        cpu_sdram_rdy;
    wire[1:0]   cpu_sdram_wmask;

    reg         video_fb_en;

    wire        video_sdram_rd;
    wire        video_sdram_rdy;
    wire        video_sdram_ack;
    wire[23:0]  video_sdram_addr_x16;
    wire[15:0]  video_sdram_rdata;

    wire[31:0]  mem_addr;                // TODO: trim down useless bits?

    logic       csr_cyc;
    logic       csr_stb;
    logic[5:2]  csr_adr;
    logic       csr_we;
    logic[31:0] csr_dat_i;
    logic       csr_ack;
    logic       csr_stall;
    logic[31:0] csr_dat_o;

    wire VGA_Timing timing0;
    wire VGA_Timing timing1         /* verilator public */;
    // wire hsync_n1, vsync_n1, blank_n1, end_of_line1, end_of_frame1;
    wire hsync_n2, vsync_n2, blank_n2, end_of_line2, end_of_frame2;

    wire [23:0] /*color1,*/ color2      /* verilator public */;
    reg[23:0] bg_col;

    VGA_Timing_Generator #(.CLK_DIV(2)) vgatm(
        .clk_i(clk_sys),
        .rst_i(~reset_n),       // no HW POR on ulx3s?

        .timing_o(timing0)
    );

    // RGB_Color_Bars_Generator tpg(
    //     .clk_i(clk_sys),
    
    //     .visible_i(timing0.blank_n),
    //     .end_of_frame_i(timing0.end_of_frame),
    //     .end_of_line_i(timing0.end_of_line),
    //     .hsync_n_i(timing0.hsync_n),
    //     .vsync_n_i(timing0.vsync_n),

    //     .end_of_frame_o(end_of_frame1),
    //     .end_of_line_o(end_of_line1),
    //     .hsync_n_o(hsync_n1),
    //     .vsync_n_o(vsync_n1),
    //     .visible_o(blank_n1),
    //     .rgb_o(color1)
    // );

    // Text_Generator tg(
    //     .clk_i(clk_sys),
    //     .rst_i(1'b0),

    //     .end_of_frame_i(end_of_frame1),
    //     .end_of_line_i(end_of_line1),
    //     .hsync_n_i(hsync_n1),
    //     .vsync_n_i(vsync_n1),
    //     .visible_i(blank_n1),

    //     .bg_rgb_i(bg_col),
    //     .fg_rgb_i(~color1),//24'hffffff),

    //     .visible_o(blank_n2),
    //     .end_of_frame_o(end_of_frame2),
    //     .end_of_line_o(end_of_line2),
    //     .hsync_n_o(hsync_n2),
    //     .vsync_n_o(vsync_n2),

    //     .rgb_o(color2),

    //     // Memory interface
    //     // addr_o,         // address in 16-bit words
    //     // rd_strobe_o,    // read strobe: we expect the data exactly 3 cycles after signalling this

    //     .data_i(8'd32)
    // );

    Video_Ctrl video_inst(
      .clk_i(clk_sys),
      .rst_i(~reset_n),

      .fb_en_i(video_fb_en),

      // SDRAM
      .sdram_rd(video_sdram_rd),
      .sdram_rdy(video_sdram_rdy),
      .sdram_ack(video_sdram_ack),
      .sdram_addr_x16(video_sdram_addr_x16),
      .sdram_rdata(video_sdram_rdata),

      .timing_i(timing0),
      .timing_o(timing1),

      .rgb_o(color2)
    );


    wire[31:0] bootrom_data;
    reg[31:0] mem_io_rdata;

    reg uart_rx_strobe;
    wire[7:0] uart_rx_data;
    wire uart_rx_valid;
    wire uart_tx_strobe     /* verilator public */;
    wire[7:0] uart_tx_data  /* verilator public */;
    wire uart_tx_busy       /* verilator public */;

    reg reset_n = 1'b0;
    logic[7:0] reset_cnt = 0;

    always @ (posedge clk_sys) begin
        if (reset_cnt < 10) begin
            reset_cnt <= reset_cnt + 1;
        end else begin
            reset_n <= 1'b1;
        end
    end

    wire cpu_dBus_cmd_valid;
    reg cpu_dBus_cmd_ready;
    wire cpu_dBus_cmd_payload_wr;
    wire[31:0] cpu_dBus_cmd_payload_address;
    wire[31:0] cpu_dBus_cmd_payload_data;
    wire[3:0] cpu_dBus_cmd_payload_mask;
    wire[2:0] cpu_dBus_cmd_payload_size;
    wire cpu_dBus_cmd_payload_last;
    reg cpu_dBus_rsp_valid;
    wire[31:0] cpu_dBus_rsp_payload_data;
    //reg cpu_dBus_rsp_payload_last;  -- seems to be happily ignored

    wire cpu_iBus_cmd_valid;
    wire cpu_iBus_cmd_ready;
    wire[31:0] cpu_iBus_cmd_payload_address;
    wire[2:0] cpu_iBus_cmd_payload_size;
    reg cpu_iBus_rsp_valid;
    wire[31:0] cpu_iBus_rsp_payload_data;

    // This interface took a bunch of reverse engineering:
    //  - cmd_payload_address is always in bytes
    //
    //  - dBus_cmd_ready must go down in 0 cycles otherwise the CPU will keep feeding commands
    //  - dBus_cmd_valid will go down simultaneously with dBus_cmd_ready; in that sense, it is a 1-cycle strobe
    //    However, it may be asserted even while dBus_cmd_ready and it will sit around and wait until cmd_ready=1 to clear itself
    //  - dBus_rsp_valid must be strobed for a single cycle when data is valid and ONLY WHEN READING!
    //  - *Bus_cmd_payload_size is log2 of the size in bytes. Note, however, that the interface always operates in units of 32 bits.
    //  - as the commands are pipelined, all parameters of the transaction must be latched at cmd_valid=1
    //
    VexRiscv cpu(
        .clk(clk_sys),
        .reset(~reset_n),

        .dBus_cmd_valid(cpu_dBus_cmd_valid),
        .dBus_cmd_ready(cpu_dBus_cmd_ready),
        .dBus_cmd_payload_wr(cpu_dBus_cmd_payload_wr),
        //output              dBus_cmd_payload_uncached,
        .dBus_cmd_payload_address(cpu_dBus_cmd_payload_address),
        .dBus_cmd_payload_data(cpu_dBus_cmd_payload_data),
        .dBus_cmd_payload_mask(cpu_dBus_cmd_payload_mask),
        .dBus_cmd_payload_size(cpu_dBus_cmd_payload_size),
        .dBus_cmd_payload_last(cpu_dBus_cmd_payload_last),
        .dBus_rsp_valid(cpu_dBus_rsp_valid),
        .dBus_rsp_payload_last('0),
        .dBus_rsp_payload_data(cpu_dBus_rsp_payload_data),
        .dBus_rsp_payload_error('0),

        .iBus_cmd_valid(cpu_iBus_cmd_valid),
        .iBus_cmd_ready(cpu_iBus_cmd_ready),    // this must be a 0-cycle signal
        .iBus_cmd_payload_address(cpu_iBus_cmd_payload_address),
        .iBus_cmd_payload_size(cpu_iBus_cmd_payload_size),
        .iBus_rsp_valid(cpu_iBus_rsp_valid),
        .iBus_rsp_payload_data(cpu_iBus_rsp_payload_data),
        .iBus_rsp_payload_error('0),

        .timerInterrupt('0),
        .externalInterrupt('0),
        .softwareInterrupt('0)
    );

    CPU_Rom bootrom(
        .clk_i(clk_sys),
        .addr_i(mem_addr[31:2]),

        .q_o(bootrom_data)
    );

    sdram_pnru sdram_pnru_inst(
        .sys_clk(clk_sys),
        .sys_rd(sdram_rd),
        .sys_wr(sdram_wr),
        .sys_ab(sdram_addr_x16),
        .sys_di(sdram_wdata),
        .sys_do(sdram_rdata),
        .sys_ack(sdram_ack),
        .sys_rdy(sdram_rdy),
        .sys_wmask(sdram_wmask),
        .burst_i(sdram_burst),

        .sdr_ab(sdram_a),
        .sdr_d(sdr_d),
        .sdr_q(sdram_d),
        .sdr_dq_oe(sdr_dq_oe),
        .sdr_ba(sdram_ba),
        .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}),
        .sdr_dqm(sdram_dqm)
    );

    assign sdram_d = sdr_dq_oe ? sdr_d : 16'hzzzz;

    Sdram_Arbiter sdram_arb_inst(
      .clk_i(clk_sys),
      .rst_i(~reset_n),

      .sdram_rd,
      .sdram_wr,
      .sdram_addr_x16,
      .sdram_wdata,
      .sdram_rdata,
      .sdram_ack,
      .sdram_rdy,
      .sdram_wmask,
      .sdram_burst,

      .cpu_sdram_rd,
      .cpu_sdram_wr,
      .cpu_sdram_addr_x16,
      .cpu_sdram_wdata,
      .cpu_sdram_rdata,
      .cpu_sdram_ack,
      .cpu_sdram_rdy,
      .cpu_sdram_wmask,

      .video_sdram_rd,
      .video_sdram_rdy,
      .video_sdram_ack,
      .video_sdram_addr_x16,
      .video_sdram_rdata
    );

`ifdef SYNTHESIS
    parameter UART_BAUDRATE = 115_200;
`else
    parameter UART_BAUDRATE = 0;
`endif

    uart uart_inst(
        .clk(clk_sys),
        .rst(~reset_n),

        // AXI input
        .s_axis_tdata(uart_tx_data),
        .s_axis_tvalid(uart_tx_strobe),
        //.s_axis_tready,   unclear how this differs from ~busy

        // AXI output
        .m_axis_tdata(uart_rx_data),
        .m_axis_tvalid(uart_rx_valid),
        .m_axis_tready(uart_rx_strobe),

        // UART interface
        .rxd(ftdi_txd),
        .txd(ftdi_rxd),
    
        // Status
        .tx_busy(uart_tx_busy),
        // output wire                   rx_busy,
        // output wire                   rx_overrun_error,
        // output wire                   rx_frame_error,

        .prescale(UART_BAUDRATE > 0 ? CLK_SYS_HZ / UART_BAUDRATE / 8 : 1)
    );

    // reg[7:0] col_data;

    // Memory control

    Memory_Ctrl mem(
      .clk_i(clk_sys),
      .rst_i(~reset_n),

      .cpu_dBus_cmd_valid,
      .cpu_dBus_cmd_ready,
      .cpu_dBus_cmd_payload_wr,
      .cpu_dBus_cmd_payload_address,
      .cpu_dBus_cmd_payload_data,
      .cpu_dBus_cmd_payload_mask,
      .cpu_dBus_cmd_payload_size,
      .cpu_dBus_rsp_valid,
      .cpu_dBus_rsp_payload_data,

      .cpu_iBus_cmd_valid,
      .cpu_iBus_cmd_ready,
      .cpu_iBus_cmd_payload_address,
      .cpu_iBus_cmd_payload_size,
      .cpu_iBus_rsp_valid,
      .cpu_iBus_rsp_payload_data,

      .csr_cyc_o(csr_cyc),
      .csr_stb_o(csr_stb),
      .csr_adr_o(csr_adr),
      .csr_we_o(csr_we),
      .csr_dat_o(csr_dat_i),
      .csr_ack_i(csr_ack),
      .csr_stall_i(csr_stall),
      .csr_dat_i(csr_dat_o),

      .sdram_rd(cpu_sdram_rd),
      .sdram_wr(cpu_sdram_wr),
      .sdram_rdy(cpu_sdram_rdy),
      .sdram_ack(cpu_sdram_ack),
      .sdram_addr_x16(cpu_sdram_addr_x16),
      .sdram_wdata(cpu_sdram_wdata),
      .sdram_rdata(cpu_sdram_rdata),
      .sdram_wmask(cpu_sdram_wmask),

      .addr_o(mem_addr),
      .bootrom_data_i(bootrom_data)
    );

    // Control/status registers

    top_csr csr(
        .rst_n_i(reset_n),
        .clk_i(clk_sys),

        .wb_cyc_i(csr_cyc),
        .wb_stb_i(csr_stb),
        .wb_adr_i(csr_adr),
        .wb_sel_i(4'b1111),
        .wb_we_i(csr_we),
        .wb_dat_i(csr_dat_i),
        .wb_ack_o(csr_ack),
        .wb_err_o(),
        .wb_rty_o(),
        .wb_stall_o(csr_stall),
        .wb_dat_o(csr_dat_o),

        .UART_STATUS_TX_BUSY_i(uart_tx_busy),
        .UART_STATUS_RX_NOT_EMPTY_i(uart_rx_valid),

        .UART_DATA_DATA_i(uart_rx_data),
        .UART_DATA_DATA_o(uart_tx_data),
        .UART_DATA_wr_o(uart_tx_strobe),

        .VIDEO_CTRL_FB_EN_o(video_fb_en),

        .VIDEO_BG_COLOR_R_o(bg_col[23:16]),
        .VIDEO_BG_COLOR_G_o(bg_col[15:8]),
        .VIDEO_BG_COLOR_B_o(bg_col[7:0])
    );

    // System control

    always @ (posedge clk_sys) begin
        if (uart_tx_strobe) begin
            // $display("WRITE CHAR '%c'", uart_tx_data);
        end
    end

    assign hsync_n_o = timing1.hsync_n;
    assign vsync_n_o = timing1.vsync_n;
    assign blank_n_o = timing1.blank_n;
    assign vga_color_o = color2;

    // assign led[0] = cpu_mem_valid;
    // assign led[1] = cpu_mem_ready;
    // assign led[2] = 0;
    // assign led[3] = 0;
    // assign led[4] = 0;
    // assign led[5] = is_valid_io_write;
    // assign led[6] = (mem_state != STATE_SDRAM_WAIT);
    // assign led[7] = (mem_state == STATE_SDRAM_WAIT);
    assign led = uart_tx_data;

// Not sure where else to put this
`ifdef COCOTB_SIM
initial begin
  $dumpfile ("cocotb_sim.vcd");
//   $dumpvars (0, clk_sys);
//   $dumpvars (0, timing1);
  $dumpvars (0, top);
  #1;
end
`endif

endmodule
