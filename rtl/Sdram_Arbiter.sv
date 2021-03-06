// Poly94 SDRAM Arbider

//
// indent: 2sp

// `define VERBOSE

module Sdram_Arbiter(
  input         clk_i,
  input         rst_i,

  output reg        sdram_rd,
  output reg        sdram_wr,
  output reg[23:0]  sdram_addr_x16,
  output reg[15:0]  sdram_wdata,
  input[15:0]       sdram_rdata,
  output reg        sdram_ack,
  input             sdram_rdy,
  output reg[1:0]   sdram_wmask,
  output reg        sdram_burst,

  input             cpu_sdram_rd,
  input             cpu_sdram_wr,
  input[23:0]       cpu_sdram_addr_x16,
  input[15:0]       cpu_sdram_wdata,
  output reg[15:0]  cpu_sdram_rdata,
  input             cpu_sdram_ack,
  output reg        cpu_sdram_rdy,
  input[1:0]        cpu_sdram_wmask,

  input             video_sdram_rd,
  output reg        video_sdram_rdy,
  input             video_sdram_ack,
  input[23:0]       video_sdram_addr_x16,
  output reg[15:0]  video_sdram_rdata
);

localparam MUX_NONE = 2'd0;
localparam MUX_CPU = 2'd1;
localparam MUX_VIDEO = 2'd2;

reg[1:0] mux;
reg sdram_busy;

reg[1:0] waitstate_counter;

// reg mask_readiness;

always @ (posedge clk_i) begin
  // mask_readiness <= 0;

  if (waitstate_counter > 0)
    waitstate_counter <= waitstate_counter - 1;

  if (rst_i) begin
    sdram_busy <= 1'b0;
    mux <= MUX_NONE;
  end else begin
    if (!sdram_busy) begin
      if (video_sdram_rd) begin
`ifdef VERBOSE
        $display("Sdram_Arb: begin video read @ %08Xh", {video_sdram_addr_x16, 1'b0});
`endif
        mux <= MUX_VIDEO;
        sdram_busy <= 1'b1;
        // mask_readiness <= 1'b1;
        waitstate_counter <= 2;
      end else if (cpu_sdram_rd || cpu_sdram_wr) begin
`ifdef VERBOSE
        $display("Sdram_Arb: begin CPU wr=%d addr=%08Xh", cpu_sdram_wr, {cpu_sdram_addr_x16, 1'b0});
`endif
        mux <= MUX_CPU;
        sdram_busy <= 1'b1;
        // mask_readiness <= 1'b1;
        waitstate_counter <= 2;
      end
    end else begin
      if (mux == MUX_VIDEO && video_sdram_ack) begin
`ifdef VERBOSE
        $display("Sdram_Arb: video ack");
`endif
        sdram_busy <= 1'b0;
        mux <= MUX_NONE;
      end

      if (mux == MUX_CPU && cpu_sdram_ack) begin
`ifdef VERBOSE
        $display("Sdram_Arb: CPU ack");
`endif
        sdram_busy <= 1'b0;
        mux <= MUX_NONE;
      end

      if (sdram_rdy) begin
        // $display("sdram rdy");
      end
    end
  end
end

always @ (*) begin
  if (mux == MUX_VIDEO) begin
    sdram_rd = video_sdram_rd;
    sdram_wr = 1'b0;
    sdram_addr_x16 = video_sdram_addr_x16;
    sdram_wdata = 16'hxxxx;
    sdram_ack = video_sdram_ack;
    sdram_wmask = 2'bxx;
    sdram_burst = 1'b1;

    cpu_sdram_rdy = 1'b0;
    video_sdram_rdy = (waitstate_counter == 0) && sdram_rdy;
  end else if (mux == MUX_CPU) begin
    sdram_rd = cpu_sdram_rd;
    sdram_wr = cpu_sdram_wr;
    sdram_addr_x16 = cpu_sdram_addr_x16;
    sdram_wdata = cpu_sdram_wdata;
    sdram_ack = cpu_sdram_ack;
    sdram_wmask = cpu_sdram_wmask;
    sdram_burst = 1'b0;

    cpu_sdram_rdy = (waitstate_counter == 0) && sdram_rdy;
    video_sdram_rdy = 1'b0;
  end else begin
    sdram_rd = 0;
    sdram_wr = 0;
    sdram_addr_x16 = 'x;
    sdram_wdata = 'x;
    sdram_ack = 0;
    sdram_wmask = 'x;
    sdram_burst = 'x;

    cpu_sdram_rdy = 0;
    video_sdram_rdy = 1'b0;
  end

  cpu_sdram_rdata = sdram_rdata;
  video_sdram_rdata = sdram_rdata;
end

endmodule
