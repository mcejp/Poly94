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

    wire cpu_mem_valid;
    reg cpu_mem_ready;

    wire[31:0] cpu_mem_addr;
    wire[31:0] cpu_mem_wdata;
    wire[ 3:0] cpu_mem_wstrb;
    wire[31:0] bootrom_data;
    reg[31:0] cpu_io_rdata;
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

    picorv32 cpu// #(
        // parameter [ 0:0] ENABLE_COUNTERS = 1,
        // parameter [ 0:0] ENABLE_COUNTERS64 = 1,
        // parameter [ 0:0] ENABLE_REGS_16_31 = 1,
        // parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
        // parameter [ 0:0] LATCHED_MEM_RDATA = 0,
        // parameter [ 0:0] TWO_STAGE_SHIFT = 1,
        // parameter [ 0:0] BARREL_SHIFTER = 0,
        // parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
        // parameter [ 0:0] TWO_CYCLE_ALU = 0,
        // parameter [ 0:0] COMPRESSED_ISA = 0,
        // parameter [ 0:0] CATCH_MISALIGN = 1,
        // parameter [ 0:0] CATCH_ILLINSN = 1,
        // parameter [ 0:0] ENABLE_PCPI = 0,
        // parameter [ 0:0] ENABLE_MUL = 0,
        // parameter [ 0:0] ENABLE_FAST_MUL = 0,
        // parameter [ 0:0] ENABLE_DIV = 0,
        // parameter [ 0:0] ENABLE_IRQ = 0,
        // parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
        // parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
        // parameter [ 0:0] ENABLE_TRACE = 0,
        // parameter [ 0:0] REGS_INIT_ZERO = 0,
        // parameter [31:0] MASKED_IRQ = 32'h 0000_0000,
        // parameter [31:0] LATCHED_IRQ = 32'h ffff_ffff,
        // parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
        // parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010,
        // parameter [31:0] STACKADDR = 32'h ffff_ffff
    //)
    (
        .clk(clk_sys),
        .resetn(reset_n),      // needed!

        .mem_valid(cpu_mem_valid),
        // output reg        mem_instr,
        .mem_ready(cpu_mem_ready),

        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_wstrb(cpu_mem_wstrb),
        .mem_rdata(cpu_mem_select == MEM_BOOTROM ? bootrom_data :
                   cpu_mem_select == MEM_SDRAM ? sdram_rdata :
                   cpu_io_rdata)

        // Look-Ahead Interface
        // output            mem_la_read,
        // output            mem_la_write,
        // output     [31:0] mem_la_addr,
        // output reg [31:0] mem_la_wdata,
        // output reg [ 3:0] mem_la_wstrb,

        // Pico Co-Processor Interface (PCPI)
        // output reg        pcpi_valid,
        // output reg [31:0] pcpi_insn,
        // output     [31:0] pcpi_rs1,
        // output     [31:0] pcpi_rs2,
        // input             pcpi_wr,
        // input      [31:0] pcpi_rd,
        // input             pcpi_wait,
        // input             pcpi_ready,

        // IRQ Interface
        // input      [31:0] irq,
        // output reg [31:0] eoi,

        // Trace Interface
        // output reg        trace_valid,
        // output reg [35:0] trace_data
    );

    CPU_Rom bootrom(
        .clk_i(clk_sys),
        .addr_i(cpu_mem_addr[31:2]),

        .q_o(bootrom_data)
    );

    reg sdram_rd;      // not strobe -- keep up until ACK (TODO verify)
    reg sdram_wr;
    wire[15:0] sdram_rdata;
    reg sdram_ack;
    wire sdram_rdy;

    sdram_pnru sdram_pnru_inst(
        .sys_clk(clk_sys),
        .sys_rd(sdram_rd),
        .sys_wr(sdram_wr),
        .sys_ab(cpu_mem_addr[23:1]),
        .sys_di(cpu_mem_wdata),
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

    parameter IO_SPACE_START = 32'h0000_1000;
    parameter SDRAM_START = 32'h4000_0000;

    // keep number of top-level states to a minimum so that high-fanout expressions like 'is_valid_io_write' are simple
    enum { STATE_IDLE, STATE_FINISHED, STATE_SDRAM_WAIT } mem_state;

    wire is_io_addr = (cpu_mem_addr[31:12] == IO_SPACE_START[31:12]);       // TODO: can be relaxed
    wire is_sdram_addr = (cpu_mem_addr[31:29] == SDRAM_START[31:29]);       // TODO: can be relaxed
    wire is_valid_io_write = (mem_state == STATE_IDLE && cpu_mem_valid && is_io_addr && cpu_mem_wstrb != 0);

    reg[1:0] waitstate_counter;

    always @ (posedge clk_sys) begin
        cpu_mem_ready <= 1'b0;
        sdram_ack <= 0;     // really single cycle strobe?

        if (!reset_n) begin
            mem_state <= STATE_IDLE;
            cpu_mem_select <= MEM_BOOTROM;
            sdram_rd <= 0;
            sdram_wr <= 0;
            waitstate_counter <= 0;
        end else begin
            if (cpu_mem_valid) begin
                // $display("MEM VALID %08X", cpu_mem_addr);
            end

            case (mem_state)
            STATE_IDLE: begin
                waitstate_counter <= 0;

                // Request to start memory operation?

                if (cpu_mem_valid) begin
                    if (is_io_addr) begin
                        // IO read/write is processed simultaneously, we can go directly to FINISHED
                        // (CPU just needs 1 clock to de-assert valid_o)

                        cpu_mem_ready <= 1'b1;
                        cpu_mem_select <= MEM_IO;
                        mem_state <= STATE_FINISHED;
                    end else if (is_sdram_addr) begin
                        // TODO: implement 32-bit access
                        // FIXME: do we need to stall in this state if SDRAM is not ready? (initing/refreshing)
                        if (cpu_mem_wstrb == 0) begin
                            sdram_rd <= 1;      // TODO: can we short these to be asserted one cycle faster?
                        end else begin
                            sdram_wr <= 1;
                        end

                        cpu_mem_select <= MEM_SDRAM;
                        mem_state <= STATE_SDRAM_WAIT;
                    end else begin
                        // ROM read (or a futile attempt to write)
                        // ROM read finishes simultaneously and so will the setting of the RDATA mux

                        cpu_mem_ready <= 1'b1;
                        cpu_mem_select <= MEM_BOOTROM;
                        mem_state <= STATE_FINISHED;
                    end
                end
            end

            STATE_SDRAM_WAIT: begin
                // 1 cycle to propagate request to SDRAM
                // 1 cycle to see de-asserted SDRAM rdy
                if (waitstate_counter < 2) begin
                    waitstate_counter <= waitstate_counter + 1;
                end else if (sdram_rdy) begin
                    sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK? what if ACK arrives 1 cycle earlier?
                    sdram_wr <= 0;
                    mem_state <= STATE_FINISHED;
                    cpu_mem_ready <= 1'b1;
                end

            end

            STATE_FINISHED: begin
                mem_state <= STATE_IDLE;
                sdram_ack <= 1;         // OK to only be ACKing when already ready for next request?
            end
            endcase
        end
    end

    // System control

    always @ (posedge clk_sys) begin
        uart_wr_strobe <= 1'b0;

        if (!reset_n) begin
            bg_col <= 0;
        end else begin
            // write TRACE_REG
            if (is_valid_io_write && cpu_mem_addr[11:0] == 12'h000) begin
                $display("WRITE CHAR '%c'", cpu_mem_wdata);

                uart_wr_strobe <= 1;
                uart_data <= cpu_mem_wdata;
            end

            // write BG_COLOR
            if (is_valid_io_write && cpu_mem_addr[11:0] == 12'h004) begin
                $display("WRITE BG_COL %08X", cpu_mem_wdata);
                if (cpu_mem_wdata != 0) begin
                    bg_col <= cpu_mem_wdata;
                    //col_data <= cpu_mem_wdata[7:0] | cpu_mem_wdata[15:8] | cpu_mem_wdata[23:16] | cpu_mem_wdata[31:24];
                end
            end

            //
            cpu_io_rdata = {31'h00000000, uart_busy};
        end
    end

    // misc old shit

    always @ (posedge clk_sys) begin
        if (cpu_mem_valid && cpu_mem_wstrb != 0) begin
            // $display("WRITE %08X <= %08X", cpu_mem_addr, cpu_mem_wdata);
        end

        // if (cpu_mem_valid && !cpu_mem_ready && cpu_mem_wstrb != 0)
        //     col_data <= cpu_mem_addr[7:0];

        if (cpu_mem_valid && cpu_mem_ready) begin
            // $display("READ %08X => %08X", cpu_mem_addr, cpu_mem_rdata);
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
