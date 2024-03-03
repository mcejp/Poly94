========================
Code style & conventions
========================

- ``_i`` and ``_o`` on module ports
- ``_n`` on active-low signals
- ``snake_case`` for signals, regs etc.
- ``Capital_Snake_Case`` for modules & types (why? just for fun!)
- indent: 4 spaces, probably will migrate to 2
- no indent of module body (start at col 1)
- probably want to align port names like this::

    module Memory_Ctrl(
      input             clk_i,        // start port name on col 21
      input             rst_i,

      output reg[31:0]  mem_addr_o,   // blah blah
      ...
    )

- probably want to align wire/reg names like this::

    wire[31:0]  mem_addr;             // name starts at col 13
    wire        is_valid_io_write;

- convention for read/write data? ``rdata``/``wdata``? or is ``_i``/``_o`` suffix sufficient + unambiguous?

Look into:

- ```default_nettype none``
- ``always_comb``/``always_ff``
- negedge rstn ?? (But should verify synth result)
- ``logic`` type
- ``_comb`` suffix on unregistered signals
- ``_strobe`` suffix on single-cycle strobes
- ``'0`` / ``'1`` / ``'x`` across codebase
- suffix: ``_d#, _e#/_f#/_n#`` ? alt: ``_dly#, _early#, _comb``

- File template? (VGA_Timing_Generator.sv a good example?)