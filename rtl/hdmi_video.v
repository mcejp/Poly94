`default_nettype none

module hdmi_video(
  input clk_25mhz,
  input hsync_n_i,
  input vsync_n_i,
  input blank_n_i,
  input [23:0] color_i,
  output [3:0] gpdi_dp,// gpdi_dn,

  output clk_locked
);
    // clock generator
    wire clk_250MHz, clk_125MHz, clk_25MHz;
    clk_25_250_125_25
    clock_instance
    (
      .clki(clk_25mhz),
      .clko(clk_250MHz),
      .clks1(clk_125MHz),
      .clks2(clk_25MHz),
      .locked(clk_locked)
    );
   
    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid vga2dvid_instance
    (
      .clk_pixel(clk_25MHz),
      .clk_shift(clk_125MHz),
      .in_color(color_i),
      .in_hsync(hsync_n_i),
      .in_vsync(vsync_n_i),
      .in_blank(~blank_n_i),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0]),
      .resetn(clk_locked),
    );

    // output TMDS SDR/DDR data to fake differential lanes
    // fake_differential fake_differential_instance
    // (
    //   .clk_shift(clk_125MHz),
    //   .in_clock(tmds[3]),
    //   .in_red(tmds[2]),
    //   .in_green(tmds[1]),
    //   .in_blue(tmds[0]),
    //   .out_p(gpdi_dp),
    //   .out_n(gpdi_dn)
    // );

    ODDRX1F ddr0_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_125MHz), .RST(0));
    ODDRX1F ddr0_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_125MHz), .RST(0));
    ODDRX1F ddr0_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_125MHz), .RST(0));
    ODDRX1F ddr0_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_125MHz), .RST(0));
endmodule
