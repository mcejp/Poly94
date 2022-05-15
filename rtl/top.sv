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
`ifdef VERILATOR
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
        .rgb_o(color1),
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

`ifndef VERILATOR
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
    reg[31:0] cpu_io_rdata;
    reg[31:0] cpu_sdram_rdata;
    enum { MEM_BOOTROM, MEM_IO, MEM_SDRAM } cpu_mem_select;

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
    //reg cpu_dBus_rsp_payload_last;  -- seems to be happily ignored

    wire cpu_iBus_cmd_valid;
    wire cpu_iBus_cmd_ready;
    wire[31:0] cpu_iBus_cmd_payload_address;
    wire[2:0] cpu_iBus_cmd_payload_size;
    reg cpu_iBus_rsp_valid;

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
        .dBus_rsp_payload_data(cpu_mem_select == MEM_IO ? cpu_io_rdata :
                               cpu_mem_select == MEM_BOOTROM ? bootrom_data :
                               cpu_sdram_rdata),
        .dBus_rsp_payload_error(0),

        .iBus_cmd_valid(cpu_iBus_cmd_valid),
        .iBus_cmd_ready(cpu_iBus_cmd_ready),    // this must be a 0-cycle signal
        .iBus_cmd_payload_address(cpu_iBus_cmd_payload_address),
        .iBus_cmd_payload_size(cpu_iBus_cmd_payload_size),
        .iBus_rsp_valid(cpu_iBus_rsp_valid),
        .iBus_rsp_payload_data(cpu_mem_select == MEM_BOOTROM ? bootrom_data :
                               cpu_sdram_rdata),
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

    reg sdram_rd;      // not strobe -- keep up until ACK (TODO verify)
    reg sdram_wr;
    reg[23:0] sdram_addr_x16;   // sdram address in 16-bit words (16M => 32MB)
    reg[15:0] sdram_wdata;
    wire[15:0] sdram_rdata;
    reg sdram_ack;
    wire sdram_rdy;

    sdram_pnru sdram_pnru_inst(
        .sys_clk(clk_sys),
        .sys_rd(sdram_rd),
        .sys_wr(sdram_wr),
        .sys_ab(sdram_addr_x16),
        .sys_di(sdram_wdata),
        .sys_do(sdram_rdata),
        .sys_ack(sdram_ack),
        .sys_rdy(sdram_rdy),

        .sdr_ab(sdram_a),
        .sdr_db(sdram_d),
        .sdr_ba(sdram_ba),
        .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}),
        .sdr_dqm(sdram_dqm)
    );

    uart #(
        .CLK_FREQ_HZ(25_000_000),
        .BAUDRATE(115_200)
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

    localparam CMD_SIZE_16BIT = 2'd1;
    localparam CMD_SIZE_32BIT = 2'd2;

    // keep number of top-level states to a minimum so that high-fanout expressions like 'is_valid_io_write' are simple
    enum { STATE_IDLE, STATE_FINISHED, STATE_SDRAM_WAIT, STATE_BURST_READ_BOOTROM, STATE_SDRAM_ACK } mem_state;

    wire is_io_addr =        (cpu_dBus_cmd_payload_address[27:24] == 4'h1);
    wire is_sdram_addr =     (cpu_dBus_cmd_payload_address[27] == 1'b1);
    wire is_valid_io_write = (mem_state == STATE_IDLE && cpu_dBus_cmd_valid && is_io_addr && cpu_dBus_cmd_payload_wr);

    reg[1:0] waitstate_counter;
    reg[2:0] words_remaining;       // up to 7

    reg[31:0] mem_addr;
    reg mem_is_wr;
    reg[2:0] mem_size;
    reg[31:0] mem_wdata;          // we never use the lower half, but it will be optimized out

    enum { PURPOSE_I, PURPOSE_D } mem_purpose;

    reg reading_bootrom;

    always @ (*) begin
        // ready must go down in 0 clocks, otherwise we will be flooded with further requests
        cpu_dBus_cmd_ready <= (mem_state == STATE_IDLE);
    end

    always @ (posedge clk_sys) begin
        sdram_ack <= 0;     // really single cycle strobe?

        reading_bootrom <= 0;

        cpu_iBus_rsp_valid <= 0;
        cpu_dBus_rsp_valid <= 0;

        if (!reset_n) begin
            mem_state <= STATE_IDLE;
            cpu_mem_select <= MEM_BOOTROM;
            sdram_rd <= 0;
            sdram_wr <= 0;
            waitstate_counter <= 0;
        end else begin
            case (mem_state)
            STATE_IDLE: begin
                waitstate_counter <= 0;

                // Request to start memory operation?
                // Q: should we prioritize D-requests or I-requests?

                // Permissible operations:
                //
                //  - I-bus read from ROM (burst)
                //
                //  - D-bus read from ROM (always treated as 32-bit, burst allowed?)
                //  - D-bus read from IO (always treated as 32-bit, burst allowed?)
                //  - D-bus read from SDRAM (??, burst allowed)
                //
                //  - D-bus write to IO (always treated as 32-bit)
                //  - D-bus write to SDRAM

                if (cpu_dBus_cmd_valid) begin
                  mem_addr <= cpu_dBus_cmd_payload_address;
                  mem_is_wr <= cpu_dBus_cmd_payload_wr;
                  mem_size <= cpu_dBus_cmd_payload_size;
                  mem_wdata <= cpu_dBus_cmd_payload_data;

                  if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT) begin
                    // 32-bit write. ASSUMING SDRAM.

                    $display("begin 32-bit write [%08Xh] <= %08Xh sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data, cpu_dBus_cmd_payload_size);

                    mem_state <= STATE_SDRAM_WAIT;

                    // low halfword first
                    sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:2], 1'b0};
                    sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                    sdram_wr <= 1;
                  end else if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_16BIT) begin
                    // 16-bit write. ASSUMING SDRAM.

                    $display("begin 16-bit write [%08Xh] <= %04Xh", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data[15:0]);

                    mem_state <= STATE_SDRAM_WAIT;

                    sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:1]};
                    sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                    sdram_wr <= 1;
                  end else if (!cpu_dBus_cmd_payload_wr) begin
                    if (cpu_dBus_cmd_payload_size >= CMD_SIZE_32BIT) begin
                      words_remaining <= (1 << (cpu_dBus_cmd_payload_size - 2)) - 1;
                    end else begin
                      words_remaining <= 0;
                    end

                    // 32-bit read. Can be BootROM or SDRAM
                    if (is_sdram_addr) begin
                        $display("begin 32-bit read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);

                        // low halfword first
                        sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:2], 1'b0};
                        sdram_rd <= 1;

                        cpu_mem_select <= MEM_SDRAM;
                        mem_state <= STATE_SDRAM_WAIT;
                    end else if (is_io_addr && cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT) begin
                        $display("begin IO read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);

                        cpu_mem_select <= MEM_IO;

                        mem_state <= STATE_FINISHED;
                        cpu_dBus_rsp_valid <= 1;
                    end else begin
                        // ROM read (or a futile attempt to write)
                        // ROM read finishes simultaneously and so will the setting of the RDATA mux
                        $display("begin ROM read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);

                        cpu_mem_select <= MEM_BOOTROM;
                        mem_state <= STATE_BURST_READ_BOOTROM;

                        mem_purpose <= PURPOSE_D;
                    end
                  end else begin
                    $display("begin INVALID OP [%08Xh] is_wr=%d msk=%04b sz=%d", cpu_dBus_cmd_payload_address,
                        cpu_dBus_cmd_payload_wr, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
                  end
                end else if (cpu_iBus_cmd_valid) begin
                    // Instruction bus read. Always a series of 32-bit words. ASSUMING BOOTROM.
                    // There is no 'last' signal; we have to look at 'size' (which is log2(bytes_to_read)) and loop

                    $display("begin 32-bit burst ROM read via I-bus [%08Xh]", cpu_iBus_cmd_payload_address);

                    words_remaining <= (1 << (cpu_iBus_cmd_payload_size - 2)) - 1;

                    mem_addr <= cpu_iBus_cmd_payload_address;
                    mem_state <= STATE_BURST_READ_BOOTROM;
                    mem_purpose <= PURPOSE_I;
                end
            end

            STATE_SDRAM_WAIT: begin
                // 1 cycle to propagate request to SDRAM
                // 1 cycle to see de-asserted SDRAM rdy
                if (waitstate_counter < 2) begin
                    waitstate_counter <= waitstate_counter + 1;
                end else if (sdram_addr_x16[0] == 0 && sdram_ack == 1) begin
                    // in process of acknowledging 1st half of 32-bit read/write

                    if (mem_is_wr) begin
                        sdram_wr <= 1;
                    end else begin
                        sdram_rd <= 1;
                    end

                    sdram_ack <= 0;

                    // high halfword now
                    sdram_addr_x16 <= {mem_addr[31:2], 1'b1};
                    sdram_wdata <= mem_wdata[31:16];

                    waitstate_counter <= 0;
                end else if (sdram_rdy) begin
                    // NB: None of this is async-safe

                    if (mem_is_wr) begin
                      if (mem_size == CMD_SIZE_32BIT) begin
                        // 32-bit write

                        if (sdram_addr_x16[0] == 0 && sdram_ack == 0) begin
                            sdram_wr <= 0;
                            sdram_ack <= 1;

                            mem_state <= STATE_SDRAM_WAIT;
                        end else if (sdram_addr_x16[0] == 1) begin
                            // addr=1, sdram ready, wait done -> 32-bit write finished
                            sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                            sdram_wr <= 0;
                            mem_state <= STATE_FINISHED;
                        end
                      end else begin
                        // 16-bit write

                        sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                        sdram_wr <= 0;
                        mem_state <= STATE_FINISHED;

                      end
                    end else begin
                        // 32-bit read

                        if (sdram_addr_x16[0] == 0 && sdram_ack == 0) begin
                            // Acknowledge low halfword

                            cpu_sdram_rdata[15:0] <= sdram_rdata;
                            sdram_rd <= 0;
                            sdram_ack <= 1;

                            mem_state <= STATE_SDRAM_WAIT;
                        end else if (sdram_addr_x16[0] == 1) begin
                            cpu_sdram_rdata[31:16] <= sdram_rdata;

                            // addr=1, sdram ready, wait done -> 32-bit read finished
                            sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                            sdram_wr <= 0;

                            cpu_dBus_rsp_valid <= 1;

                            $display("  finished 32-bit SDRAM read [%08X]", mem_addr);

                            if (words_remaining == 0) begin
                                mem_state <= STATE_FINISHED;
                            end else begin
                                mem_state <= STATE_SDRAM_ACK;

                                cpu_mem_select <= MEM_SDRAM;
                                sdram_ack <= 1;   // not async safe etc.
                            end

                            waitstate_counter <= 0;

                            mem_addr <= mem_addr + 4;
                            words_remaining <= words_remaining - 1;
                        end
                    end
                end

            end

            STATE_SDRAM_ACK: begin
              // low halfword first
              sdram_addr_x16 <= {mem_addr[31:2], 1'b0};
              sdram_rd <= 1;
              mem_state <= STATE_SDRAM_WAIT;
              sdram_ack <= 0;
            end

            STATE_FINISHED: begin
                mem_state <= STATE_IDLE;
                sdram_ack <= 1;         // OK to only be ACKing when already ready for next request?
            end

            STATE_BURST_READ_BOOTROM: begin
                if (mem_purpose == PURPOSE_I) begin
                    cpu_iBus_rsp_valid <= 1'b1;
                end else begin
                    cpu_dBus_rsp_valid <= 1;
                end

                reading_bootrom <= 1;

                cpu_mem_select <= MEM_BOOTROM;

                if (words_remaining == 0) begin
                    mem_state <= STATE_FINISHED;
                end else begin
                    mem_state <= STATE_BURST_READ_BOOTROM;
                end

                mem_addr <= mem_addr + 4;
                words_remaining <= words_remaining - 1;
            end
            endcase
        end

        if (reading_bootrom) begin
          $display("  ROM read => %08X", bootrom_data);
        end
    end

    // System control

    always @ (posedge clk_sys) begin
        uart_wr_strobe <= 1'b0;

        if (!reset_n) begin
            bg_col <= 0;
        end else begin
            // write TRACE_REG
            if (is_valid_io_write && cpu_dBus_cmd_payload_address[11:0] == 12'h000) begin
                $display("WRITE CHAR '%c'", cpu_dBus_cmd_payload_data[7:0]);

                uart_wr_strobe <= 1;
                uart_data <= cpu_dBus_cmd_payload_data[7:0];
            end

            // write BG_COLOR
            if (is_valid_io_write && cpu_dBus_cmd_payload_address[11:0] == 12'h004) begin
                $display("WRITE BG_COL %08X", cpu_dBus_cmd_payload_data);
                if (cpu_dBus_cmd_payload_data != 0) begin
                    bg_col <= cpu_dBus_cmd_payload_data;
                    //col_data <= cpu_mem_wdata[7:0] | cpu_mem_wdata[15:8] | cpu_mem_wdata[23:16] | cpu_mem_wdata[31:24];
                end
            end

            //
            cpu_io_rdata = {31'h00000000, uart_busy};
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
