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

module VGA_Timing_Generator(
    clk_i,
    rst_i,

    hsync_n_o,
    vsync_n_o,
    blank_n_o,          // 1 if pixel visible, 0 if "blanked"

    end_of_line_o,      // strobed just after a line has been fully scanned out
    end_of_frame_o      // strobed just after a frame has been fully scanned out, simultaneously with end_of_line_o
);

input clk_i;
input rst_i;

output reg end_of_line_o;
output reg end_of_frame_o;
output reg hsync_n_o;
output reg vsync_n_o;
output reg blank_n_o;

// Timing constants

localparam H_VISIBLE = 640;
localparam H_FRONT_PORCH = 16;
localparam H_BACK_PORCH = 44;
localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + 96 + H_BACK_PORCH;

localparam V_VISIBLE = 480;
localparam V_FRONT_PORCH = 10;
localparam V_BACK_PORCH = 31;
localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + 2 + V_BACK_PORCH;

// Line/pixel counting

// line in frame
reg[$clog2(V_TOTAL)-1:0] scanline;
reg[$clog2(V_TOTAL)-1:0] next_scanline;     // scanline in *next clock tick*, not generally "scanline + 1"

// clock in line
// 0 to 795 -> 10 bits
reg[$clog2(H_TOTAL)-1:0] i;
reg[$clog2(H_TOTAL)-1:0] next_i;

// are we in picture area? (vertically)
reg is_picture_line;

always @ (posedge clk_i) begin
    if (rst_i) begin
        scanline <= 0;
        next_scanline <= 0;
        i <= 0;
        next_i <= 1;
    end else begin
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
            next_i <= 1'b0;

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
        hsync_n_o <= 1'b1;
        vsync_n_o <= 1'b1;
    end else begin
        // TODO: explore the most efficient way to implement these

        if (next_i == H_SYNC_BEGIN) begin
            hsync_n_o <= 1'b0;
        end else if (next_i == H_SYNC_END) begin
            hsync_n_o <= 1'b1;
        end

        if (next_i == 0 && next_scanline == V_SYNC_BEGIN) begin
            vsync_n_o <= 1'b0;
        end else if (next_i == 0 && next_scanline == V_SYNC_END) begin
            vsync_n_o <= 1'b1;
        end

        if (next_i < H_VISIBLE && next_scanline < V_VISIBLE) begin
            blank_n_o <= 1'b1;
        end else begin
            blank_n_o <= 1'b0;
        end
    end
end

// Generate End-of-Line output

always @ (posedge clk_i) begin
    if (is_picture_line && next_i == H_VISIBLE) begin
        end_of_line_o <= 1'b1;
    end else begin
        end_of_line_o <= 1'b0;
    end
end

// Generate End-of-Frame output

always @ (posedge clk_i) begin
    // just after the last pixel of last visible scanline
    if (is_picture_line && next_i == H_VISIBLE && next_scanline == V_VISIBLE - 1) begin
        end_of_frame_o <= 1'b1;
    end else begin
        end_of_frame_o <= 1'b0;
    end
end

endmodule
