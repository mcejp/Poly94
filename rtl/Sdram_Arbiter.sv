// Poly94 SDRAM Arbider

//
// indent: 2sp

/*
Even if the SDRAM controller could accept multiple pipelined commands,
we only accept one read command for processing at a time.

It works like this:
- CPU or video requests SDRAM access
- we propagate the command (in the same clock cycle) and set the mux + busy state
- we wait for command to be finished (sdram_ack, later sdram_resp_valid && sdram_resp_last ?)
- then we become ready again (this could be maybe advanced by 1 cycle)

Note:
- the ready output is combinatorial
*/

// `define VERBOSE

module Sdram_Arbiter(
  input         clk_i,
  input         rst_i,

  output reg        sdram_cmd_valid,
  input             sdram_cmd_ready,
  output reg        sdram_rd,
  output reg        sdram_wr,
  output reg[23:0]  sdram_addr_x16,
  output reg[15:0]  sdram_wdata,
  input             sdram_resp_valid,
  input[15:0]       sdram_rdata,
  output reg        sdram_ack,
  input             sdram_rdy,
  output reg[1:0]   sdram_wmask,
  output reg        sdram_burst,

  input             cpu_sdram_cmd_valid,
  output reg        cpu_sdram_cmd_ready,
  input             cpu_sdram_rd,
  input             cpu_sdram_wr,
  input[23:0]       cpu_sdram_addr_x16,
  input[15:0]       cpu_sdram_wdata,
  output reg        cpu_sdram_resp_valid,
  output reg[15:0]  cpu_sdram_rdata,
  input             cpu_sdram_ack,
  output reg        cpu_sdram_rdy,
  input[1:0]        cpu_sdram_wmask,

  input             video_sdram_cmd_valid,
  output reg        video_sdram_cmd_ready,
  output reg        video_sdram_rdy,
  input             video_sdram_ack,
  input[23:0]       video_sdram_addr_x16,
  output reg        video_sdram_resp_valid,
  output reg[15:0]  video_sdram_rdata
);

localparam MUX_NONE = 2'd0;
localparam MUX_CPU = 2'd1;
localparam MUX_VIDEO = 2'd2;

reg[1:0] mux;
reg sdram_busy;

reg[1:0] waitstate_counter;   // Ignore sdram_rdy for 2 cycles after issuing request

// reg mask_readiness;

always_comb begin
  video_sdram_cmd_ready = (!rst_i && !sdram_busy && sdram_cmd_ready);
  cpu_sdram_cmd_ready = (video_sdram_cmd_ready && !video_sdram_cmd_valid);

  sdram_cmd_valid = cpu_sdram_cmd_valid || video_sdram_cmd_valid;
end

always @ (posedge clk_i) begin
  // mask_readiness <= 0;

  if (waitstate_counter > 0)
    waitstate_counter <= waitstate_counter - 1;

  if (rst_i) begin
    sdram_busy <= 1'b0;
    mux <= MUX_NONE;
  end else begin
    if (!sdram_busy) begin
      if (sdram_cmd_ready && video_sdram_cmd_valid) begin
        // Pipelined video command is being accepted
`ifdef VERBOSE
        $display("Sdram_Arb: begin PIPELINED video read @ %08Xh", {video_sdram_addr_x16, 1'b0});
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
  if (mux == MUX_VIDEO || (mux == MUX_NONE && video_sdram_cmd_ready && video_sdram_cmd_valid)) begin
    sdram_rd = '0;
    sdram_wr = 1'b0;
    sdram_addr_x16 = video_sdram_addr_x16;
    sdram_wdata = 16'hxxxx;
    sdram_ack = video_sdram_ack;
    sdram_wmask = 2'bxx;
    sdram_burst = 1'b1;

    cpu_sdram_rdy = 1'b0;
    cpu_sdram_resp_valid = '0;
    video_sdram_rdy = (waitstate_counter == 0) && sdram_rdy;
    video_sdram_resp_valid = sdram_resp_valid;
  end else if (mux == MUX_CPU) begin
    sdram_rd = cpu_sdram_rd;
    sdram_wr = cpu_sdram_wr;
    sdram_addr_x16 = cpu_sdram_addr_x16;
    sdram_wdata = cpu_sdram_wdata;
    sdram_ack = cpu_sdram_ack;
    sdram_wmask = cpu_sdram_wmask;
    sdram_burst = 1'b0;

    cpu_sdram_rdy = (waitstate_counter == 0) && sdram_rdy;
    cpu_sdram_resp_valid = sdram_resp_valid;
    video_sdram_rdy = 1'b0;
    video_sdram_resp_valid = '0;
  end else begin
    sdram_rd = 0;
    sdram_wr = 0;
    sdram_addr_x16 = 'x;
    sdram_wdata = 'x;
    sdram_ack = 0;
    sdram_wmask = 'x;
    sdram_burst = 'x;

    cpu_sdram_rdy = 0;
    cpu_sdram_resp_valid = '0;
    video_sdram_rdy = 1'b0;
    video_sdram_resp_valid = '0;
  end

  cpu_sdram_rdata = sdram_rdata;
  video_sdram_rdata = sdram_rdata;
end

endmodule
