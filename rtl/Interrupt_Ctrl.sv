// Poly94 Interrupt Control
//
// indent: 4sp

// `define INT_VERBOSE

module Interrupt_Ctrl #(
    NUM_INT
)(
    input                       clk_i,
    input                       rst_i,

    input logic[NUM_INT-1:0]    enabled_i,

    input logic[NUM_INT-1:0]    set_strobe_i,
    input logic[NUM_INT-1:0]    clear_strobe_i,

    output logic[NUM_INT-1:0]   interrupts_pending_o,
    output logic                any_pending_o
);

logic[NUM_INT-1:0] pending;

always_ff @ (posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
        pending <= '0;
    end else begin
        pending <= (pending & ~clear_strobe_i) | set_strobe_i;

`ifdef INT_VERBOSE
        if (clear_strobe_i != 0)
            $display("pending %08X <- %08X", pending, clear_strobe_i);

        if (set_strobe_i != 0)
            $display("pending %08X <+ %08X", pending, set_strobe_i);
`endif
    end
end

always_comb begin
    interrupts_pending_o = pending;
    any_pending_o = |(pending & enabled_i);
end

endmodule
