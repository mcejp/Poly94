// Original code: https://www.excamera.com/sphinx/fpga-uart.html
// Adapted to Poly94 coding style

`default_nettype none

module uart(
    clk_i,
    rst_i,

    uart_wr_strobe_i,   // Raise to transmit byte
    uart_data_i,        // 8-bit data

    uart_busy_o,        // High means UART is transmitting
    uart_tx_o           // UART transmit wire
);

parameter CLK_FREQ_HZ;
parameter BAUDRATE;

input uart_wr_strobe_i;
input [7:0] uart_data_i;
input clk_i;
input rst_i;

output uart_busy_o;
output uart_tx_o;

reg [3:0] bitcount;
reg [8:0] shifter;
reg uart_tx_o;

wire uart_busy_o = |bitcount[3:1];
wire sending = |bitcount;

reg [28:0] d;
wire [28:0] dInc = d[28] ? (BAUDRATE) : (BAUDRATE - CLK_FREQ_HZ);
wire [28:0] dNxt = d + dInc;
always @(posedge clk_i)
begin
    d = dNxt;
end
wire ser_clk = ~d[28]; // this is the bit clock

always @(posedge clk_i)
begin
    if (rst_i) begin
        uart_tx_o <= 1;
        bitcount <= 0;
        shifter <= 0;
    end else begin
        // just got a new byte
        if (uart_wr_strobe_i & ~uart_busy_o) begin
            shifter <= { uart_data_i[7:0], 1'h0 };
            bitcount <= (1 + 8 + 2);
        end

        if (sending & ser_clk) begin
            { shifter, uart_tx_o } <= { 1'h1, shifter };
            bitcount <= bitcount - 1;
        end
    end
end

endmodule
