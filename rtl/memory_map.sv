`ifndef MEMORY_MAP_SV
`define MEMORY_MAP_SV

localparam ADDR_CSR_START   = 27'h0000000;
localparam ADDR_SDRAM_START = 27'h4000000;

localparam BOOTROM_ADDR_BITS = 12;

// verilator lint_off unused
function automatic addr_is_csr(input[26:0] addr);
begin
    addr_is_csr = (addr[26:24] == ADDR_CSR_START[26:24]);
end
endfunction

function automatic addr_is_sdram(input[26:0] addr);
begin
    addr_is_sdram = (addr[26] == ADDR_SDRAM_START[26]);
end
endfunction
// verilator lint_on unused

`endif
