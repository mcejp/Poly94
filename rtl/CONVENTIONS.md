- `_strobe` on single-cycle strobes
- `_n` on negated signals
- `_i` and `_o` on module ports

- snake_case for signals, regs etc.
- Capital_Snake_Case for modules & types (why? just for fun!)

- indent: 4 spaces, probably will migrate to 2
- no indent of module body (start at col 1)

- probably want to align port names like this:

```systemverilog
module Memory_Ctrl(
  input             clk_i,        // start port name on col 21
  input             rst_i,

  output reg[31:0]  mem_addr_o,   // blah blah
  ...
)
```

- probably want to align wire/reg names like this:

```systemverilog
wire[31:0]  mem_addr;             // name starts at col 13
wire        is_valid_io_write;
```

- convention for read/write data? `rdata`/`wdata`? or `_i`/`_o` suffix sufficient + unambiguous?


good reference style: ??
