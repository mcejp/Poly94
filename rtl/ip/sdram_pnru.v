// (Adapted from https://github.com/emard/ulx3s-misc/blob/master/examples/sdram/sdram_pnru/sdram_pnru.v)
//
// Simplistic SDRAM controller for 4x4Mx16 chips (e.g. micron MT48LC16M16A2)
//  - makes one sdram access for each system access
//  - can keep all 4 banks open
//  - distributed refresh
//
// This source code is public domain
//
module sdram_pnru (
    // system interface
    input  wire        sys_clk,             // CLK 25 Mhz
    input              cmd_valid_i,         // command valid strobe
    output reg         cmd_ready_o,         // command acceptance strobe
    input  wire        sys_wr,              // write word
    output reg         sys_rdy = 1'b0,      // mem ready
    input  wire        sys_ack,             // mem cycle end
    input  wire [23:0] sys_ab,              // address
    input  wire [15:0] sys_di,              // data in
    output reg  [15:0] sys_do,              // data out
    output reg         resp_valid_o,        // read data valid
    output reg         resp_last_o,         // read data last
    input  wire  [1:0] sys_wmask,           // byte mask
    input              burst_i,

    // sdram interface
    output wire  [3:0] sdr_n_CS_WE_RAS_CAS, // SDRAM nCS, nWE, nRAS, nCAS
    output wire  [1:0] sdr_ba,              // SDRAM bank address
    output reg  [12:0] sdr_ab,              // SDRAM address
    input  wire [15:0] sdr_q,               // SDRAM output data
    output wire [15:0] sdr_d,               // SDRAM input data
    output reg         sdr_dq_oe,
    output reg   [1:0] sdr_dqm = 2'b11      // SDRAM DQM; note: DQM==2'b11 during init
  );

  // Datasheet: https://www.issi.com/WW/pdf/42-45S83200G-16160G.pdf
  // (ulx3s v3.1.7: IS42S16160G-7TL)

  // SDRAM timing parameters
  localparam tRP = 3, tMRD = 2, tRCD = 3, tRC = 9, CL = 2;
  `ifdef SYNTHESIS
  localparam INITLEN = 5000;  // ceil(50MHz * 100us)
  `else
  localparam INITLEN = 3;
  `endif
  localparam RFTIME = 390;    // floor(50 MHz * 7.8125us)

  reg [15:0] di;
  reg [23:0] ab;
  reg wr, ack;
  always @ (*) begin
    di <= sys_di;
    ab <= sys_ab;
    wr <= sys_wr;
    ack <= sys_ack;
  end
 // wire di = sys_di;
  
  // dataflow assignments
  assign sdr_n_CS_WE_RAS_CAS = sdr_cmd;
  assign sdr_ba = (state==CONFIG) ? 2'b00 : ab[10:9];
  assign sdr_d = di;
  assign sdr_dq_oe = (state==RWRDY && is_write);

  // controller states & FSM
  localparam IDLE = 0, RFRSH1 = 1, RFRSH2 = 2, CONFIG = 3, RDWR = 4, RWRDY = 5, ACKWT = 6, WAIT = 7;

  reg  [3:0] sdr_cmd;               // command issued to sdram
  reg  [2:0] state   = IDLE;        // FSM state
  reg  [2:0] next;                  // new state after waiting
  reg [15:0] ctr     = 0;           // refresh/init counter
  reg  [6:0] dly;                   // FSM delay counter
  reg  [3:0] open;                  // open bank flags
  reg [12:0] opnrow[0:3];           // open row numbers
  reg bursting;
  reg  [7:0] burst_count;
  
  reg is_write;

  // convenience signals
  reg         init = 1'b1;
  wire  [8:0] col  = ab[8:0];
  wire [12:0] row  = ab[23:11];
  wire  [1:0] ba   = ab[10:9];
  
  // SDRAM command codes
  localparam NOP  = 4'b1000, PRECHRG = 4'b0001, AUTORFRSH = 4'b0100, MODESET = 4'b0000,
             READ = 4'b0110, WRITE   = 4'b0010, ACTIVATE  = 4'b0101, BURST_STOP = 4'b0011;

  // SDRAM mode register: single word reads & writes, CL=2, sequential access, full page burst
  localparam MODE = 13'b000_1_00_010_0_111;
  
  always @(posedge sys_clk)
  begin
    ctr <= ctr + 1;
    dly <= dly - 1;
    
    // default FSM operations
    sdr_cmd <= NOP;
    state   <= WAIT;
    resp_valid_o <= '0;

    case (state)
    
      IDLE:   if (init) state <= (ctr==INITLEN) ? RFRSH1 : IDLE; // remain in idle for >100us at init
              else begin
                sys_rdy <= 1'b0;
                if (ctr>=RFTIME) state <= RFRSH1;         // as needed, refresh a row
                else if (cmd_valid_i|wr) begin
                  state <= RDWR;           // else respond to rd or wr request
                  sdr_dqm <= !wr ? 2'b00 : ~sys_wmask;
                  bursting <= burst_i;
                  // this can be set to X in other cases
                  is_write <= wr;
                end else begin
                  sys_rdy <= 1'b1;
                  state <= IDLE;                                 // else do nothing
                end
                burst_count <= 0;
              end

      RFRSH1: begin // prior to refresh, close all banks
                sdr_cmd    <= PRECHRG;
                sdr_ab[10] <= 1'b1;    // do all banks
                open       <= 4'b000;
                dly <= tRP-2; next <= (init) ? CONFIG : RFRSH2; // insert config step during init
              end

      RFRSH2: begin // refresh one row, then return to IDLE
                sdr_cmd <= AUTORFRSH;
                init <= 1'b0;
                ctr     <= 0;         // reset timeout
                dly <= tRC-2; next <= (init) ? RFRSH2 : IDLE;  // repeat AUTORFRSH during init
              end

      CONFIG: begin // load the mode register
                sdr_cmd <= MODESET;
                sdr_ab  <= MODE;
                dly <= tMRD-2; next <= RFRSH2;
              end

      RDWR:   begin // issue read or write command
                if (!open[ba]) begin // if not open, open row first & restart
                  sdr_cmd <= ACTIVATE;
                  sdr_ab  <= row;
                  open[ba]   <= 1'b1; // mark as open
                  opnrow[ba] <= row;
                  dly <= tRCD-2; next <= RDWR;
                  end
                else if (opnrow[ba]!=row) begin // if wrong row, close it & restart
                  sdr_cmd      <= PRECHRG;
                  sdr_ab[10]   <= 1'b0;  // for one bank only
                  open[ba] <= 1'b0;  // mark as closed
                  dly <= tRP-2; next <= RDWR;
                  end
                else begin // all good, issue R/W command
                  sdr_cmd <= is_write ? WRITE : READ;
                  sdr_ab  <= {4'b0000, col};
                  dly <= CL-1; next <= RWRDY;
                  if (is_write) state <= RWRDY; // no delay needed for writes
                  end
              end
      
      RWRDY:  begin // latch read result, or write data
                sys_rdy <= 1'b1;
                if (!is_write) sys_do  <= sdr_q;
                if (!is_write) resp_valid_o <= '1;
                resp_last_o <= (!bursting || burst_count == 63);
                if (is_write) sdr_cmd <= BURST_STOP;
                if (bursting) begin
                  // $display("SDRAM burst cnt %d, put out data, stop=%d", burst_count, (burst_count == 64 - CL));
                  // when we receive byte burst_len-CL-1, we issue BURST_STOP in the next cycle (see dsh page 34)

                  // for a burst length of 4 (example) and CL=2, BURST_STOP must be issued upon the 3rd word being read
                  // so we must assign the register upon the 2nd word: burst_count == burst_len - CL - 1
                  if (burst_count == 64 - CL - 1) begin    // might be off by 1 or 2
                    sdr_cmd <= BURST_STOP;
                  end

                  if (burst_count < 63) begin
                    state <= RWRDY;
                  end else begin
                    // $display("SDRAM burst finish, this is the last word");
                    state <= ACKWT;
                  end
                end else begin
                  state <= ACKWT;
                end

                burst_count <= burst_count + 1'b1;
              end
              
      ACKWT:  // wait for system to end current r/w cycle
              state <= (ack) ? IDLE : ACKWT;
      
      WAIT:   // wait 'dly' clocks before progressing to state 'next'   
              begin
                state <= (|dly) ? WAIT : next;
                if (next == RWRDY && dly == CL - 1 && !bursting)
                  sdr_cmd <= BURST_STOP;
              end
              
    endcase
  end

  always @ (*) begin
    cmd_ready_o = (state == IDLE) && !init && (ctr < RFTIME);
  end

endmodule
