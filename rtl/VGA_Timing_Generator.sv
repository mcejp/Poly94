// A pipelined VGA timing generator
// Martin Cejp, May 2022
//
// TABLE OF CONTENTS
// - Module definition
// - Timing constants
// - Line/pixel counting
// - Generate HSYNC & VSYNC
// - Generate End-of-Line output
// - Generate End-of-Frame output

`default_nettype none
`include "VGA_Timing.sv"

module VGA_Timing_Generator #(
    CLK_DIV
)(
    clk_i,
    rst_i,

    timing_o
);

input clk_i;
input rst_i;

output VGA_Timing timing_o;

// Timing constants

localparam H_VISIBLE = 640;
localparam H_FRONT_PORCH = 16;
localparam H_BACK_PORCH = 44;
localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + 96 + H_BACK_PORCH;

localparam V_VISIBLE = 480;
localparam V_FRONT_PORCH = 10;
localparam V_BACK_PORCH = 31;
localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + 2 + V_BACK_PORCH;

// Clock divider; probably should be externalized
logic[$clog2(CLK_DIV)-1:0] prescaler = 0;
logic clk_en = 0;       // pipelined to minimize extra cost

// Line/pixel counting

// line in frame
reg[$clog2(V_TOTAL)-1:0] scanline;
reg[$clog2(V_TOTAL)-1:0] next_scanline;     // scanline in *next clock tick*, not generally "scanline + 1"

// clock in line
// 0 to 795 -> 10 bits
// verilator lint_off UNUSED
reg[$clog2(H_TOTAL)-1:0] i;
// verilator lint_on UNUSED
reg[$clog2(H_TOTAL)-1:0] next_i;

// are we in picture area? (vertically)
reg is_picture_line;

// Clock prescaling logic

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        prescaler <= '0;
        clk_en <= '0;
    end else begin
        if (prescaler == '0) begin
            prescaler <= CLK_DIV - 1;
            clk_en <= '1;
        end else begin
            prescaler <= prescaler - 1;
            clk_en <= '0;
        end
    end
end

always @ (posedge clk_i) begin
    if (rst_i) begin
        scanline <= 0;
        next_scanline <= 0;
        i <= 0;
        next_i <= 0;
        is_picture_line <= 1'b0;
    end else if (clk_en) begin
        if (next_i == 0) begin
            // end of line. handle here everything that should be handled synchronously with EOL (F, V flags)

            if (next_scanline == 0) begin
                is_picture_line <= 1'b1;
            end

            if (next_scanline == V_VISIBLE) begin
                is_picture_line <= 1'b0;
            end
        end

        i <= next_i;
        scanline <= next_scanline;

        if (next_i < H_TOTAL-1) begin
            next_i <= next_i + 1'b1;
        end else begin
            next_i <= '0;

            if (scanline < V_TOTAL-1) begin
                next_scanline <= scanline + 1'b1;
            end else begin
                next_scanline <= 0;
            end
        end
    end
end

// Generate HSYNC & VSYNC & visible

localparam H_SYNC_BEGIN =   H_VISIBLE + H_FRONT_PORCH;
localparam H_SYNC_END =     H_TOTAL - H_BACK_PORCH;

localparam V_SYNC_BEGIN =   V_VISIBLE + V_FRONT_PORCH;
localparam V_SYNC_END =     V_TOTAL - V_BACK_PORCH;

always @ (posedge clk_i) begin
    if (rst_i) begin
        timing_o.hsync_n <= 1'b1;
        timing_o.vsync_n <= 1'b1;
    end else if (clk_en) begin
        // TODO: explore the most efficient way to implement these

        if (next_i == H_SYNC_BEGIN) begin
            timing_o.hsync_n <= 1'b0;
        end else if (next_i == H_SYNC_END) begin
            timing_o.hsync_n <= 1'b1;
        end

        if (next_i == 0 && next_scanline == V_SYNC_BEGIN) begin
            timing_o.vsync_n <= 1'b0;
        end else if (next_i == 0 && next_scanline == V_SYNC_END) begin
            timing_o.vsync_n <= 1'b1;
        end

        if (next_i < H_VISIBLE && next_scanline < V_VISIBLE) begin
            timing_o.blank_n <= 1'b1;
        end else begin
            timing_o.blank_n <= 1'b0;
        end
    end
end

// Generate End-of-Line output

always @ (posedge clk_i) begin
    if (clk_en && is_picture_line && next_i == H_VISIBLE) begin
        timing_o.end_of_line <= 1'b1;
    end else begin
        timing_o.end_of_line <= 1'b0;
    end
end

// Generate End-of-Frame output

always @ (posedge clk_i) begin
    // just after the last pixel of last visible scanline
    if (clk_en && is_picture_line && next_i == H_VISIBLE && next_scanline == V_VISIBLE - 1) begin
        timing_o.end_of_frame <= 1'b1;
    end else begin
        timing_o.end_of_frame <= 1'b0;
    end
end

//

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        timing_o.valid <= '0;
    end else begin
        timing_o.valid <= clk_en;
    end
end

endmodule
