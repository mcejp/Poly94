module CPU_Rom(
    input clk_i,
    input [(addr_width-1):0] addr_i,

    output reg [(data_width-1):0] q_o
);
    // 1024 words x 32 bits
    parameter data_width = 32;
    parameter addr_width = 10;

    reg [data_width-1:0] rom[2**addr_width-1:0]     /* verilator public */;
    initial
    begin
        `ifdef SYNTHESIS
        $readmemh("build/boot_syn.vh", rom);    // placeholder that is patched at later stage
                                                // thus permitting ROM update without resynthesis
        `else
        $readmemh("firmware/build/boot.vh", rom);
        `endif
    end

    always @ (posedge clk_i)
    begin
        q_o <= rom[addr_i];
    end
endmodule
