// Poly94 Video Control

//
// indent: 2sp

// `define VERBOSE_VIDCTL

`default_nettype none
`include "VGA_Timing.sv"

module Video_Ctrl(
  clk_i,
  rst_i,

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

// SDRAM
output reg        sdram_rd;           // not strobe -- keep up until ACK (TODO verify)
input             sdram_rdy;
output reg        sdram_ack;
output reg[23:0]  sdram_addr_x16;     // sdram address in 16-bit words (16Mw => 32MB)
input[15:0]       sdram_rdata;

input VGA_Timing  timing_i;
output VGA_Timing timing_o;

output reg[23:0]  rgb_o;

always @ (posedge clk_i) begin
  if (rst_i) begin
  end else begin
  end

  timing_o <= timing_i;
  rgb_o <= 24'hFF00FF;
end

endmodule
