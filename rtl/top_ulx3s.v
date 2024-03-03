`default_nettype none

module top_ulx3s
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

    output ftdi_rxd,
    input ftdi_txd
);

// assign wifi_gpio0 = 1'b1;

wire hsync_n;
wire vsync_n;
wire blank_n;
wire[23:0] vga_color;

parameter CLK_SYS_HZ = 50_000_000;

wire [3:0] clocks;

wire clk_sys     = clocks[0];
assign sdram_clk = clocks[1];

ecp5pll
#(
    .in_hz(  25_000_000),
    .out0_hz(CLK_SYS_HZ),
    .out1_hz(CLK_SYS_HZ), .out1_deg(330) // phase shifted for SDRAM chip
)
ecp5pll_inst
(
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked()
);

top #(
    .CLK_SYS_HZ(CLK_SYS_HZ)
)
top_inst(
    .clk_sys,

    .led,

    .sdram_csn,
    .sdram_cke,
    .sdram_rasn,
    .sdram_casn,
    .sdram_wen,
    .sdram_a,
    .sdram_ba,
    .sdram_dqm,
    .sdram_d,

    .ftdi_rxd,
    .ftdi_txd,

    .hsync_n_o(hsync_n),
    .vsync_n_o(vsync_n),
    .blank_n_o(blank_n),
    .vga_color_o(vga_color)
);

hdmi_video hdmi_video
(
    .clk_25mhz(clk_25mhz),

    .hsync_n_i(hsync_n),
    .vsync_n_i(vsync_n),
    .blank_n_i(blank_n),

    .color_i(vga_color),

    .gpdi_dp(gpdi_dp)
    //.gpdi_dn(gpdi_dn)
);

endmodule
