`default_nettype none

module top
(
    input clk_25mhz,
    output [3:0] gpdi_dp,//, gpdi_dn,
    output [7:0] led
);
    // assign wifi_gpio0 = 1'b1;

    wire hsync_n, vsync_n, blank_n;
    wire end_of_line;

    wire [23:0] color;

    VGA_Timing_Generator vgatm(
        .clk_i(clk_25mhz),
        .rst_i(1'b0),       // no HW POR on ulx3s?

        .end_of_line_o(end_of_line),
        // .end_of_frame_o,

        .hsync_n_o(hsync_n),
        .vsync_n_o(vsync_n),
        .blank_n_o(blank_n)
    );

    RGB_Color_Bars_Generator tpg(
       .clk_i(clk_25mhz),
    
       .visible_i(blank_n),
       .end_of_line_i(end_of_line),
    
       .rgb_o(color),
    );

    hdmi_video hdmi_video
    (
        .clk_25mhz(clk_25mhz),

        .hsync_n_i(hsync_n),
        .vsync_n_i(vsync_n),
        .blank_n_i(blank_n),

        .color_i(color),

        .gpdi_dp(gpdi_dp)
        //.gpdi_dn(gpdi_dn)
        // .vga_vsync(led[0])
        //.clk_locked(led[2])
    );

    assign led[0] = ~vsync_n;
    assign led[1] = ~led[0];
    assign led[2] = 1'b0;
    assign led[3] = 1'b0;
    assign led[4] = 1'b0;
    assign led[5] = 1'b0;
    assign led[6] = 1'b0;
    assign led[7] = 1'b0;
endmodule
