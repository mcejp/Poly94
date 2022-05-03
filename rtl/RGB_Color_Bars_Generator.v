`default_nettype none

module RGB_Color_Bars_Generator(
    clk_i,

    visible_i,
    end_of_line_i,

    rgb_o
);

localparam PIXELS_PER_VISIBLE_LINE = 640;
localparam PIXELS_PER_STRIPE = PIXELS_PER_VISIBLE_LINE / 8;

input clk_i;
input visible_i, end_of_line_i;

output reg[23:0] rgb_o;

wire[23:0] RGB_table[0:7];

// 100% color bars
assign RGB_table[0] = {8'd255, 8'd255, 8'd255};
assign RGB_table[1] = {8'd255, 8'd255, 8'd0  };
assign RGB_table[2] = {8'd0  , 8'd255, 8'd255};
assign RGB_table[3] = {8'd0  , 8'd255, 8'd0  };
assign RGB_table[4] = {8'd255, 8'd0  , 8'd255};
assign RGB_table[5] = {8'd255, 8'd0  , 8'd0  };
assign RGB_table[6] = {8'd0  , 8'd0  , 8'd255};
assign RGB_table[7] = {8'd0  , 8'd0  , 8'd0  };

reg[2:0] index; // 0 to 7
reg[$clog2(PIXELS_PER_STRIPE)-1:0] cnt;

always @ (posedge clk_i) begin
    if (end_of_line_i == 1'b1) begin
        index <= 0;
        cnt <= 0;
    end else if (visible_i) begin
        if (cnt < PIXELS_PER_STRIPE-1) begin
            cnt <= cnt + 1'b1;
        end else begin
            // since a pixel is not consumed every cycle, a "slow" assignment is sufficient
            index <= index + 1'b1;
            cnt <= 0;
        end;
    end;

    rgb_o <= RGB_table[index];
end

endmodule
