module CPU_Rom(
    input clk_i,
    input [(addr_width-1):0] addr_i,

    output reg [(data_width-1):0] q_o
);
    parameter data_width = 32;
    parameter addr_width = 8;

    reg [data_width-1:0] rom[2**addr_width-1:0];
    initial
    begin
        $readmemh("boot/boot.vh", rom);
    end

    always @ (posedge clk_i)
    begin
        q_o <= rom[addr_i];
    end
endmodule
