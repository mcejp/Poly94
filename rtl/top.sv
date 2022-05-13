`default_nettype none
`include "VGA_Timing.sv"

module top
(
    input clk_25mhz,
    output [3:0] gpdi_dp,//, gpdi_dn,
    output [7:0] led,

    output ftdi_rxd
);
    // assign wifi_gpio0 = 1'b1;

    wire clk_sys = clk_25mhz;

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
    enum { MEM_BOOTROM, MEM_IO } cpu_mem_select;

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
        .mem_rdata(cpu_mem_select == MEM_BOOTROM ? bootrom_data : cpu_io_rdata)

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

    enum { STATE_IDLE, STATE_FINISHED } mem_state;

    wire is_io_addr = (cpu_mem_addr[31:12] == IO_SPACE_START[31:12]);       // TODO: can be relaxed
    wire is_valid_io_write = (mem_state == STATE_IDLE && cpu_mem_valid && is_io_addr && cpu_mem_wstrb != 0);

    always @ (posedge clk_sys) begin
        cpu_mem_ready <= 1'b0;

        if (!reset_n) begin
            cpu_mem_select <= MEM_BOOTROM;
        end else begin
            if (cpu_mem_valid) begin
                // $display("MEM VALID %08X", cpu_mem_addr);
            end

            case (mem_state)
            STATE_IDLE: begin
                // Request to start memory operation?

                if (cpu_mem_valid) begin
                    if (is_io_addr) begin
                        // IO read/write is processed simultaneously, we can go directly to FINISHED
                        // (CPU just needs 1 clock to de-assert valid_o)

                        cpu_mem_ready <= 1'b1;
                        cpu_mem_select <= MEM_IO;
                        mem_state <= STATE_FINISHED;
                    end else begin
                        // ROM read (or a futile attempt to write)
                        // ROM read finishes simultaneously and so will the setting of the RDATA mux

                        cpu_mem_ready <= 1'b1;
                        cpu_mem_select <= MEM_BOOTROM;
                        mem_state <= STATE_FINISHED;
                    end
                end
            end

            STATE_FINISHED: begin
                mem_state <= STATE_IDLE;
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

    assign led[0] = cpu_mem_valid;
    assign led[1] = cpu_mem_ready;
    assign led[2] = cpu_mem_wstrb[0];
    assign led[3] = cpu_mem_wstrb[1];
    assign led[4] = cpu_mem_wstrb[2];
    assign led[5] = cpu_mem_wstrb[3];
    assign led[6] = 1'b0;
    assign led[7] = bg_col[23];
    // assign led = col_data;
endmodule
