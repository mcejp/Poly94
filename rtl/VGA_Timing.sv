// An interface type would probably be more appropriate.
// Sadly, Yosys currently has a serious issue: https://github.com/YosysHQ/yosys/issues/1053
//
typedef struct packed {
    logic hsync_n;
    logic vsync_n;
    logic blank_n;          // 1 if pixel visible, 0 if "blanked"
    logic end_of_line;      // strobed just after a line has been fully scanned out
    logic end_of_frame;     // strobed just after a frame has been fully scanned out, simultaneously with end_of_line_o
} VGA_Timing;
