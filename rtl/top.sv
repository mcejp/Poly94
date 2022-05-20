`default_nettype none
`include "VGA_Timing.sv"

module top
(
    input clk_25mhz,
    output [3:0] gpdi_dp,//, gpdi_dn,
    output [7:0] led,

    // SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output sdram_csn,       // chip select
    output sdram_clk,       // clock to SDRAM
    output sdram_cke,       // clock enable to SDRAM
    output sdram_rasn,      // SDRAM RAS
    output sdram_casn,      // SDRAM CAS
    output sdram_wen,       // SDRAM write-enable
    output [12:0] sdram_a,  // SDRAM address bus
    output [1:0] sdram_ba,  // SDRAM bank-address
    output [1:0] sdram_dqm, // byte select
    inout [15:0] sdram_d,   // data bus to/from SDRAM

    output ftdi_rxd
);
    // assign wifi_gpio0 = 1'b1;

    // begin PLL
`ifndef SYNTHESIS
    wire clk_sys = clk_25mhz;
    assign sdram_clk = clk_25mhz;
`else
    wire locked;
    wire [3:0] clocks;
    ecp5pll
    #(
        .in_hz(  25_000_000),
        .out0_hz(25_000_000),
        .out1_hz(25_000_000), .out1_deg(90) // phase shifted for SDRAM chip
    )
    ecp5pll_inst
    (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(locked)
    );

    wire clk_sys     = clocks[0];
    assign sdram_clk = clocks[1];
`endif

    assign sdram_cke = 1'b1;
    // end PLL

    // Memory control-related
    reg         sdram_rd;
    reg         sdram_wr;
    wire[23:0]  sdram_addr_x16;
    wire[15:0]  sdram_wdata;
    wire[15:0]  sdram_rdata;
    wire        sdram_ack;
    wire        sdram_rdy;
    wire[1:0]   sdram_wmask;

    wire[31:0]  mem_addr;                // TODO: trim down useless bits?
    wire        mem_io_write_valid;
    wire[31:0]  mem_io_addr;
    wire[31:0]  mem_io_wdata;

    // TODO: can we use some SystemVerilog structure for this?
    wire VGA_Timing timing0;
    wire hsync_n1, vsync_n1, blank_n1, end_of_line1, end_of_frame1;
    wire hsync_n2, vsync_n2, blank_n2, end_of_line2, end_of_frame2;

    wire [23:0] color1, color2;
    reg[23:0] bg_col;

    VGA_Timing_Generator vgatm(
        .clk_i(clk_sys),
        .rst_i(1'b0),       // no HW POR on ulx3s?

        .timing_o(timing0)
    );

    RGB_Color_Bars_Generator tpg(
        .clk_i(clk_sys),
    
        .visible_i(timing0.blank_n),
        .end_of_frame_i(timing0.end_of_frame),
        .end_of_line_i(timing0.end_of_line),
        .hsync_n_i(timing0.hsync_n),
        .vsync_n_i(timing0.vsync_n),

        .end_of_frame_o(end_of_frame1),
        .end_of_line_o(end_of_line1),
        .hsync_n_o(hsync_n1),
        .vsync_n_o(vsync_n1),
        .visible_o(blank_n1),
        .rgb_o(color1)
    );

    Text_Generator tg(
        .clk_i(clk_sys),
        .rst_i(1'b0),

        .end_of_frame_i(end_of_frame1),
        .end_of_line_i(end_of_line1),
        .hsync_n_i(hsync_n1),
        .vsync_n_i(vsync_n1),
        .visible_i(blank_n1),

        .bg_rgb_i(bg_col),
        .fg_rgb_i(~color1),//24'hffffff),

        .visible_o(blank_n2),
        .end_of_frame_o(end_of_frame2),
        .end_of_line_o(end_of_line2),
        .hsync_n_o(hsync_n2),
        .vsync_n_o(vsync_n2),

        .rgb_o(color2),

        // Memory interface
        // addr_o,         // address in 16-bit words
        // rd_strobe_o,    // read strobe: we expect the data exactly 3 cycles after signalling this

        .data_i(8'd32)
    );

`ifdef SYNTHESIS
    hdmi_video hdmi_video
    (
        .clk_25mhz(clk_sys),

        .hsync_n_i(hsync_n2),
        .vsync_n_i(vsync_n2),
        .blank_n_i(blank_n2),

        .color_i(color2),

        .gpdi_dp(gpdi_dp)
        //.gpdi_dn(gpdi_dn)
        // .vga_vsync(led[0])
        //.clk_locked(led[2])
    );
`endif

    wire[31:0] bootrom_data;
    reg[31:0] mem_io_rdata;

    reg uart_wr_strobe;
    reg[7:0] uart_data;
    wire uart_busy;

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
        .dBus_rsp_payload_last(0),
        .dBus_rsp_payload_data(cpu_dBus_rsp_payload_data),
        .dBus_rsp_payload_error(0),

        .iBus_cmd_valid(cpu_iBus_cmd_valid),
        .iBus_cmd_ready(cpu_iBus_cmd_ready),    // this must be a 0-cycle signal
        .iBus_cmd_payload_address(cpu_iBus_cmd_payload_address),
        .iBus_cmd_payload_size(cpu_iBus_cmd_payload_size),
        .iBus_rsp_valid(cpu_iBus_rsp_valid),
        .iBus_rsp_payload_data(cpu_iBus_rsp_payload_data),
        .iBus_rsp_payload_error(0),

        .timerInterrupt(0),
        .externalInterrupt(0),
        .softwareInterrupt(0)
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

        .sdr_ab(sdram_a),
        .sdr_db(sdram_d),
        .sdr_ba(sdram_ba),
        .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}),
        .sdr_dqm(sdram_dqm)
    );

`ifdef SYNTHESIS
    parameter UART_BAUDRATE = 115_200;
`else
    parameter UART_BAUDRATE = 12_500_000;
`endif

    uart #(
        .CLK_FREQ_HZ(25_000_000),
        .BAUDRATE(UART_BAUDRATE)
    ) uart_inst(
        .clk_i(clk_sys),
        .rst_i(~reset_n),

        .uart_wr_strobe_i(uart_wr_strobe),
        .uart_data_i(uart_data),

        .uart_busy_o(uart_busy),
        .uart_tx_o(ftdi_rxd)
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

      .sdram_rd,
      .sdram_wr,
      .sdram_rdy,
      .sdram_ack,
      .sdram_addr_x16,
      .sdram_wdata,
      .sdram_rdata,
      .sdram_wmask,

      .addr_o(mem_addr),
      .bootrom_data_i(bootrom_data),

      .io_write_valid_o(mem_io_write_valid),
      .io_addr_o(mem_io_addr),
      .io_rdata_i(mem_io_rdata),
      .io_wdata_o(mem_io_wdata)
    );

    // System control

    always @ (posedge clk_sys) begin
        uart_wr_strobe <= 1'b0;

        if (!reset_n) begin
            bg_col <= 0;
        end else begin
            // write TRACE_REG
            if (mem_io_write_valid && mem_io_addr[11:0] == 12'h000) begin
                $display("WRITE CHAR '%c'", mem_io_wdata[7:0]);

                uart_wr_strobe <= 1;
                uart_data <= mem_io_wdata[7:0];
            end

            // write BG_COLOR
            if (mem_io_write_valid && mem_io_addr[11:0] == 12'h004) begin
                $display("WRITE BG_COL %08X", mem_io_wdata);
                if (mem_io_wdata != 0) begin
                    bg_col <= mem_io_wdata;
                    //col_data <= cpu_mem_wdata[7:0] | cpu_mem_wdata[15:8] | cpu_mem_wdata[23:16] | cpu_mem_wdata[31:24];
                end
            end

            //
            mem_io_rdata = {31'h00000000, uart_busy};
        end
    end

    // assign led[0] = cpu_mem_valid;
    // assign led[1] = cpu_mem_ready;
    // assign led[2] = 0;
    // assign led[3] = 0;
    // assign led[4] = 0;
    // assign led[5] = is_valid_io_write;
    // assign led[6] = (mem_state != STATE_SDRAM_WAIT);
    // assign led[7] = (mem_state == STATE_SDRAM_WAIT);
    assign led = uart_data;
endmodule
