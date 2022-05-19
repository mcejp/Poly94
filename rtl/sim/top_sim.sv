`default_nettype none

module top_sim(
    input clk_25mhz
);

wire sdram_csn;
wire sdram_clk;
wire sdram_cke;
wire sdram_rasn;
wire sdram_casn;
wire sdram_wen;
wire[12:0] sdram_a;
wire[1:0] sdram_ba;
wire[1:0] sdram_dqm;
wire[15:0] sdram_d;

wire ftdi_rxd;

top top_inst(
    .clk_25mhz,

    .sdram_csn,
    .sdram_clk,
    .sdram_cke,
    .sdram_rasn,
    .sdram_casn,
    .sdram_wen,
    .sdram_a,
    .sdram_ba,
    .sdram_dqm,
    .sdram_d,

    .ftdi_rxd
);

mt48lc16m16a2 mt48lc16m16a2_inst(
    .Dq(sdram_d),
    .Addr(sdram_a),
    .Ba(sdram_ba),
    .Clk(sdram_clk),
    .Cke(sdram_cke),
    .Cs_n(sdram_csn),
    .Ras_n(sdram_rasn),
    .Cas_n(sdram_casn),
    .We_n(sdram_wen),
    .Dqm(sdram_dqm)
);

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("ftdi_rxd.vcd");
  $dumpvars (0, clk_25mhz);
  $dumpvars (1, ftdi_rxd);
  #1;
end
`endif

endmodule
