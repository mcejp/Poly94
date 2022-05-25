// Poly94 Video Control

//
// indent: 2sp

// `define VERBOSE_VIDCTL

`default_nettype none
`include "VGA_Timing.sv"

module Video_Ctrl(
  clk_i,
  rst_i,

  fb_en_i,

  sdram_rd,
  sdram_rdy,
  sdram_ack,
  sdram_addr_x16,
  sdram_rdata,

  timing_i,
  timing_o,

  rgb_o
);

input             clk_i;
input             rst_i;

input             fb_en_i;

// SDRAM
output reg        sdram_rd;           // not strobe -- keep up until ACK (TODO verify)
input             sdram_rdy;
output reg        sdram_ack;
output reg[23:0]  sdram_addr_x16;     // sdram address in 16-bit words (16Mw => 32MB)
input[15:0]       sdram_rdata;

input VGA_Timing  timing_i;
output VGA_Timing timing_o;

output reg[23:0]  rgb_o;


wire[5:0] fb_page = 6'h20;            // frame buffer can be moved in 512k increments in the 32MB of SDRAM (bits 24..19 of byte address -> 23..18 of word address)
                                      // CPU addr = 0x0400'0000 + fb_page * 0x8'0000

reg[15:0] line_buffer[0:1023];
reg[9:0] line_read_ptr;
wire[15:0] line_read_data = line_buffer[line_read_ptr];

reg[9:0] line_write_ptr;

reg[1:0] waitstate;                   // TODO: this needs to be validated for correctness
                                      // (or better yet, replaced by better readiness signalling)

localparam BURST_LEN = 64;
localparam BURST_BITS = 6;

always @ (posedge clk_i) begin
  sdram_ack <= 1'b0;

  if (waitstate > 0)
    waitstate <= waitstate - 1;

  if (rst_i) begin
    sdram_rd <= 1'b0;
    sdram_addr_x16 <= 0;
    rgb_o <= 24'h000000;

    line_read_ptr <= 10'd0;
    line_write_ptr <= 10'd0;
  end else begin
    if (fb_en_i) begin
      rgb_o <= {line_read_data[15:11], line_read_data[15:13], // r
                line_read_data[10:5], line_read_data[10:9],   // g
                line_read_data[4:0], line_read_data[2:0]};    // b
    end else begin
      rgb_o <= 24'hFF00FF;
    end

    if (timing_i.end_of_line) begin
      $display("Video: EOL; en=%d vsync_n=%d", fb_en_i, timing_i.vsync_n);
    end

    if (timing_i.end_of_line && timing_i.vsync_n == 1'b1) begin   // FIXME: should start loading if *next* line is not blanked
      line_read_ptr <= 10'd0;
      line_write_ptr <= 10'd0;

      if (fb_en_i) begin
        // if framebuffer enabled, begin sdram read
        sdram_rd <= 1'b1;
        $display("VIDEO_CTRL: request read");
        waitstate <= 3;
      end
    end else if (timing_i.blank_n) begin
      // visible pixel
      line_read_ptr <= line_read_ptr + 1'b1;
    end

    if (sdram_ack) begin
      sdram_ack <= 1'b0;

      // sdram cycle finished, decide if we need to do another one
      if (line_write_ptr < 320) begin
        sdram_rd <= 1'b1;
        $display("VIDEO_CTRL: request new read");
        waitstate <= 3;
      end
    end else if (sdram_rd && sdram_rdy && waitstate == 0) begin
      $display("VIDEO_CTRL: got data word [%03d] => %04Xh", line_write_ptr, sdram_rdata);
      if (line_write_ptr[BURST_BITS-1:0] == BURST_LEN - 1) begin
        $display("video ctrl: ACK burst @ %d", line_write_ptr);
        sdram_ack <= 1'b1;
        sdram_rd <= 1'b0;
        sdram_addr_x16[17:0] <= sdram_addr_x16[17:0] + BURST_LEN;
      end

      line_buffer[line_write_ptr] <= sdram_rdata;
      line_write_ptr <= line_write_ptr + 1'b1;
      // sdram_addr_x16 <= sdram_addr_x16 + 1'b1;
    end

    if (timing_i.end_of_frame) begin
      sdram_addr_x16[17:0] <= 18'h00000;
    end
  end

  timing_o <= timing_i;
  sdram_addr_x16[23:18] <= fb_page;
end

endmodule
