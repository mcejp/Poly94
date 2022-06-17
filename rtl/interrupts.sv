`ifndef INTERRUPTS_SV
`define INTERRUPTS_SV

typedef enum {
    INT_HSYNC,
    INT_VSYNC
} INT_t;

// Yosys requires this to be localparam rather than enum value
localparam INT_MAX = 2'd2;

`endif
