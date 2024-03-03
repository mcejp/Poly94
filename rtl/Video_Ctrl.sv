// Poly94 Video Control
//
// TABLE OF CONTENTS
// - Address generation & memory interface
// - Framebuffer scan-out
// - RGB output generation
//
// indent: 2sp

// `define VERBOSE

`default_nettype none
`include "VGA_Timing.sv"

module Video_Ctrl(
  clk_i,
  rst_i,

  fb_en_i,

  sdram_cmd_valid,
  sdram_cmd_ready,
  sdram_rd,
  sdram_rdy,
  sdram_ack,
  sdram_addr_x16,
  sdram_resp_valid,
  sdram_rdata,

  timing_i,
  timing_o,

  rgb_o
);

input             clk_i;
input             rst_i;

input             fb_en_i;

// SDRAM
output reg        sdram_cmd_valid;
input             sdram_cmd_ready;
output reg        sdram_rd;           // not strobe -- keep up until ACK (TODO verify)
input             sdram_rdy;
output reg        sdram_ack;
output reg[23:0]  sdram_addr_x16;     // sdram address in 16-bit words (16Mw => 32MB)
input             sdram_resp_valid;
input[15:0]       sdram_rdata;

input VGA_Timing  timing_i;
output VGA_Timing timing_o;

output reg[23:0]  rgb_o;


wire[5:0] fb_page = 6'h20;            // frame buffer can be moved in 512k increments in the 32MB of SDRAM (bits 24..19 of byte address -> 23..18 of word address)
                                      // CPU addr = 0x0400'0000 + fb_page * 0x8'0000

reg[15:0] line_buffer[0:1023];
reg[15:0] line_read_data;

reg[9:0] line_write_ptr;

reg[9:0] line_no;

localparam DISPLAY_W = 320;
localparam DISPLAY_H = 240;

localparam BURST_LEN = 64;
localparam BURST_BITS = 6;

// Address generation & memory interface

always @ (posedge clk_i) begin
  sdram_ack <= 1'b0;

  if (sdram_cmd_valid && sdram_cmd_ready) begin
    sdram_cmd_valid <= '0;
  end

  if (rst_i) begin
    sdram_addr_x16 <= 0;

    line_write_ptr <= 10'd0;
    line_no <= '0;
  end else begin
    if (timing_i.end_of_visible_line) begin
`ifdef VERBOSE
      $display("Video: EOL; en=%d vsync_n=%d", fb_en_i, timing_i.vsync_n);
`endif
    end

    if (timing_i.end_of_line && timing_i.next_line_visible) begin
      line_write_ptr <= 10'd0;

      if (fb_en_i && line_no < DISPLAY_H) begin
        // if framebuffer enabled, begin sdram read
        sdram_cmd_valid <= '1;
      end
    end

    if (sdram_ack) begin
      sdram_ack <= 1'b0;

      // sdram cycle finished, decide if we need to do another one
      if (line_write_ptr < DISPLAY_W) begin
        sdram_cmd_valid <= '1;
      end
    end else if (sdram_resp_valid) begin
`ifdef VERBOSE
      $display("VIDEO_CTRL: got data word [%03d:%03d] => %04Xh", line_no, line_write_ptr, sdram_rdata);
`endif
      // TODO: should have sdram_resp_last instead of having to count
      if (line_write_ptr[BURST_BITS-1:0] == BURST_LEN - 1) begin
`ifdef VERBOSE
        $display("video ctrl: ACK burst @ %d", line_write_ptr);
`endif
        sdram_ack <= 1'b1;
        sdram_addr_x16[17:0] <= sdram_addr_x16[17:0] + BURST_LEN;
      end

      line_buffer[line_write_ptr] <= sdram_rdata;
      line_write_ptr <= line_write_ptr + 1'b1;
      // sdram_addr_x16 <= sdram_addr_x16 + 1'b1;
    end

    if (timing_i.end_of_visible_line) begin
      line_no <= line_no + 1;
    end

    if (timing_i.end_of_frame) begin
      sdram_addr_x16[17:0] <= 18'h00000;
      line_no <= '0;
    end
  end

  sdram_addr_x16[23:18] <= fb_page;
end

// Framebuffer scan-out

reg[9:0] line_read_ptr;

always_ff @ (posedge clk_i) begin
  if (rst_i) begin
    line_read_ptr <= 10'd0;
  end else begin
    if (timing_i.end_of_visible_line) begin
      line_read_ptr <= 10'd0;
    end else if (timing_i.valid && timing_i.blank_n == '1) begin
      // must not increment only during visible pixels, because the counter gets reset
      // just after the last visible pixel in a line
      line_read_ptr <= line_read_ptr + 1'b1;
    end
  end
end

always_comb begin
  line_read_data = line_buffer[line_read_ptr];
end

// RGB output generation

always_ff @ (posedge clk_i) begin
  if (rst_i) begin
    rgb_o <= 24'h000000;
  end else begin
    if (fb_en_i) begin
      if (line_no < DISPLAY_H) begin
        rgb_o <= {line_read_data[15:11], line_read_data[15:13], // r
                  line_read_data[10:5], line_read_data[10:9],   // g
                  line_read_data[4:0], line_read_data[2:0]};    // b
      end else begin
        // TODO: use configured background color, etc.
        rgb_o <= 24'h000000;
      end
    end else begin
      rgb_o <= 24'hFF00FF;
    end
  end

  timing_o <= timing_i;
end

assign sdram_rd = '0;

endmodule

`undef VERBOSE
