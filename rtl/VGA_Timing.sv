// An interface type would probably be more appropriate.
// Sadly, Yosys currently has a serious issue: https://github.com/YosysHQ/yosys/issues/1053
//

`ifndef VGA_TIMING_SV
`define VGA_TIMING_SV

typedef struct packed {
    logic hsync_n;
    logic vsync_n;
    logic blank_n;          // 1 if pixel visible, 0 if "blanked"
    logic end_of_line;      // strobed just after the last visible pixel of a visible line
    logic end_of_frame;     // strobed just after the last visible pixel of the last visible line (simultaneously with end_of_line_o)
    logic valid;
} VGA_Timing;

`endif
