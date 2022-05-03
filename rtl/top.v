module top
(
    input clk_25mhz,
    output [3:0] gpdi_dp,//, gpdi_dn,
    output [7:0] led
);
    // assign wifi_gpio0 = 1'b1;

    wire [23:0] color;
    wire [9:0] x;
    wire [9:0] y;

    assign color = (x<213) ? 24'hff0000 : (x<426) ? 24'hffffff : 24'h0000ff;

    hdmi_video hdmi_video
    (
        .clk_25mhz(clk_25mhz),
        .x(x),
        .y(y),
        .color(color),
        .gpdi_dp(gpdi_dp),
        //.gpdi_dn(gpdi_dn)
        .vga_vsync(led[0])
        //.clk_locked(led[2])
    );

    assign led[1] = ~led[0];
    assign led[2] = 1'b0;
    assign led[3] = 1'b0;
    assign led[4] = 1'b0;
    assign led[5] = 1'b0;
    assign led[6] = 1'b0;
    assign led[7] = 1'b0;
endmodule
