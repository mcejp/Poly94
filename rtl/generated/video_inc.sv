package video_Consts;
  localparam VIDEO_SIZE = 8;
  localparam ADDR_VIDEO_CTRL = 'h0;
  localparam VIDEO_CTRL_FB_EN_OFFSET = 0;
  localparam VIDEO_CTRL_FB_EN = 32'h1;
  localparam ADDR_VIDEO_BG_COLOR = 'h4;
  localparam VIDEO_BG_COLOR_R_OFFSET = 16;
  localparam VIDEO_BG_COLOR_R = 32'hff0000;
  localparam VIDEO_BG_COLOR_G_OFFSET = 8;
  localparam VIDEO_BG_COLOR_G = 32'hff00;
  localparam VIDEO_BG_COLOR_B_OFFSET = 0;
  localparam VIDEO_BG_COLOR_B = 32'hff;
endpackage
