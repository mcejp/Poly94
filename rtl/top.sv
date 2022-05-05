`default_nettype none
`include "VGA_Timing.sv"

module top
(
    input clk_25mhz,
    output [3:0] gpdi_dp,//, gpdi_dn,
    output [7:0] led
);
    // assign wifi_gpio0 = 1'b1;

    // TODO: can we use some SystemVerilog structure for this?
    wire VGA_Timing timing0;
    wire hsync_n1, vsync_n1, blank_n1, end_of_line1, end_of_frame1;
    wire hsync_n2, vsync_n2, blank_n2, end_of_line2, end_of_frame2;

    wire [23:0] color1, color2;

    VGA_Timing_Generator vgatm(
        .clk_i(clk_25mhz),
        .rst_i(1'b0),       // no HW POR on ulx3s?

        .timing_o(timing0)
    );

    RGB_Color_Bars_Generator tpg(
        .clk_i(clk_25mhz),
    
        .visible_i(timing0.blank_n),
        .end_of_frame_i(timing0.end_of_frame),
        .end_of_line_i(timing0.end_of_line),
        .hsync_n_i(timing0.hsync_n),
        .vsync_n_i(timing0.vsync_n),

        .end_of_frame_o(end_of_frame1),
        .end_of_line_o(end_of_line1),
        .hsync_n_o(hsync_n1),
        .vsync_n_o(vsync_n1),
        .visible_o(blank_n1),
        .rgb_o(color1),
    );

    Text_Generator tg(
        .clk_i(clk_25mhz),
        .rst_i(1'b0),

        .end_of_frame_i(end_of_frame1),
        .end_of_line_i(end_of_line1),
        .hsync_n_i(hsync_n1),
        .vsync_n_i(vsync_n1),
        .visible_i(blank_n1),

        .bg_rgb_i(color1),
        .fg_rgb_i(~color1),//24'hffffff),

        .visible_o(blank_n2),
        .end_of_frame_o(end_of_frame2),
        .end_of_line_o(end_of_line2),
        .hsync_n_o(hsync_n2),
        .vsync_n_o(vsync_n2),

        .rgb_o(color2),

        // Memory interface
        // addr_o,         // address in 16-bit words
        // rd_strobe_o,    // read strobe: we expect the data exactly 3 cycles after signalling this

        .data_i(8'd32)
    );

    hdmi_video hdmi_video
    (
        .clk_25mhz(clk_25mhz),

        .hsync_n_i(hsync_n2),
        .vsync_n_i(vsync_n2),
        .blank_n_i(blank_n2),

        .color_i(color2),

        .gpdi_dp(gpdi_dp)
        //.gpdi_dn(gpdi_dn)
        // .vga_vsync(led[0])
        //.clk_locked(led[2])
    );

    assign led[0] = 1'b0;
    assign led[1] = 1'b0;
    assign led[2] = 1'b0;
    assign led[3] = 1'b0;
    assign led[4] = 1'b0;
    assign led[5] = 1'b0;
    assign led[6] = 1'b0;
    assign led[7] = 1'b0;
endmodule
