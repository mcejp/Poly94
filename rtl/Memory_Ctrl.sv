// Poly94 Memory Control
//  - dispatches transactions to the correct destination
//  - does not include boot ROM, SDRAM controller nor I/O registers
//  - to be heavily optimized...
//
// indent: 2sp

// `define VERBOSE_MEMCTL

`include "memory_map.sv"

module Memory_Ctrl(
  input             clk_i,
  input             rst_i,

  // TODO: missing direction suffixes
  input             cpu_dBus_cmd_valid,
  output reg        cpu_dBus_cmd_ready,
  input             cpu_dBus_cmd_payload_wr,
  input[31:0]       cpu_dBus_cmd_payload_address,
  input[31:0]       cpu_dBus_cmd_payload_data,
  input[3:0]        cpu_dBus_cmd_payload_mask,
  input[2:0]        cpu_dBus_cmd_payload_size,
  output reg        cpu_dBus_rsp_valid,
  output[31:0]      cpu_dBus_rsp_payload_data,

  input             cpu_iBus_cmd_valid,
  output reg        cpu_iBus_cmd_ready,
  input[31:0]       cpu_iBus_cmd_payload_address,
  input[2:0]        cpu_iBus_cmd_payload_size,
  output reg        cpu_iBus_rsp_valid,
  output[31:0]      cpu_iBus_rsp_payload_data,

  // CSR
  output reg        csr_cyc_o,
  output reg        csr_stb_o,
  output reg [5:2]  csr_adr_o,
  output reg        csr_we_o,
  output reg [31:0] csr_dat_o,
  input  wire       csr_ack_i,
  input  wire       csr_stall_i,
  input  wire[31:0] csr_dat_i,

  // SDRAM
  output reg        sdram_cmd_valid,
  input             sdram_cmd_ready,
  output reg        sdram_wr,
  input             sdram_rdy,
  output reg        sdram_ack,
  output reg[23:0]  sdram_addr_x16,     // sdram address in 16-bit words (16Mw => 32MB)
  output reg[15:0]  sdram_wdata,
  input             sdram_resp_valid,
  input[15:0]       sdram_rdata,
  output reg[1:0]   sdram_wmask,

  // Boot ROM; must have exactly 1 cycle read delay
  output[BOOTROM_ADDR_BITS-1:2] bootrom_addr_o,
  input[31:0]                   bootrom_data_i
);


localparam[2:0] CMD_SIZE_8BIT  = 3'd0;
localparam[2:0] CMD_SIZE_16BIT = 3'd1;
localparam[2:0] CMD_SIZE_32BIT = 3'd2;

// keep number of top-level states to a minimum so that high-fanout expressions like 'io_write_valid_o' are simple
enum { STATE_IDLE, STATE_FINISHED, STATE_SDRAM_WAIT, STATE_WAIT_BOOTROM, STATE_BURST_READ_BOOTROM, STATE_SDRAM_ACK, STATE_CSR, STATE_SDRAM_READ } mem_state;

wire dBus_is_csr_addr =     addr_is_csr(cpu_dBus_cmd_payload_address[26:0]);
wire dBus_is_sdram_addr =   addr_is_sdram(cpu_dBus_cmd_payload_address[26:0]);
wire iBus_is_sdram_addr =   addr_is_sdram(cpu_iBus_cmd_payload_address[26:0]);

reg[1:0] waitstate_counter;
reg[2:0] words_remaining;       // up to 7

// Note: to reduce contention we can duplicate mem_addr + words_remaining between ROM access & SDRAM access
reg[31:0] mem_addr;
reg mem_is_wr;
reg[2:0] mem_size;
// verilator lint_off UNUSED
reg[31:0] mem_wdata;          // we never use the lower half, but it will be optimized out
// verilator lint_on UNUSED

enum { PURPOSE_I, PURPOSE_D } mem_purpose;

reg reading_bootrom;

always_comb begin
    // ready must go down in 0 clocks, otherwise we will be flooded with further requests
    cpu_dBus_cmd_ready = (mem_state == STATE_IDLE);
    cpu_iBus_cmd_ready = (mem_state == STATE_IDLE) && !cpu_dBus_cmd_valid;
end

always @ (posedge clk_i) begin
    sdram_ack <= 0;     // really single cycle strobe?

    reading_bootrom <= 0;

    cpu_iBus_rsp_valid <= 0;
    cpu_dBus_rsp_valid <= 0;

    if (rst_i) begin
        mem_state <= STATE_IDLE;
        sdram_cmd_valid <= '0;
        sdram_wr <= 0;
        waitstate_counter <= 0;
    end else begin
        case (mem_state)
        STATE_IDLE: begin
            waitstate_counter <= 0;

            sdram_wmask <= 2'b11;

            // Request to start memory operation?
            // Q: should we prioritize D-requests or I-requests?

            // Permissible operations:
            //
            //  - I-bus read from ROM (burst)
            //
            //  - D-bus read from ROM (always treated as 32-bit, burst allowed?)
            //  - D-bus read from IO (always treated as 32-bit, burst allowed?)
            //  - D-bus read from SDRAM (??, burst allowed)
            //
            //  - D-bus write to IO (always treated as 32-bit)
            //  - D-bus write to SDRAM

            if (cpu_dBus_cmd_valid) begin
              mem_addr <= cpu_dBus_cmd_payload_address;
              mem_is_wr <= cpu_dBus_cmd_payload_wr;
              mem_size <= cpu_dBus_cmd_payload_size;
              mem_wdata <= cpu_dBus_cmd_payload_data;

              if (dBus_is_csr_addr) begin
                mem_state <= STATE_CSR;

`ifdef VERBOSE_MEMCTL
                $display("begin CSR [%08Xh] is_wr=%d msk=%04b sz=%d wdata=%08X", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_wr, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size, cpu_dBus_cmd_payload_data);
`endif

                assert(cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT);
              end else if (dBus_is_sdram_addr && cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT) begin
                // 32-bit SDRAM write

`ifdef VERBOSE_MEMCTL
                $display("begin 32-bit write [%08Xh] <= %08Xh sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data, cpu_dBus_cmd_payload_size);
`endif

                mem_state <= STATE_SDRAM_WAIT;

                // low halfword first
                sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[$left(sdram_addr_x16) + 1:2], 1'b0};
                sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                sdram_wr <= 1;
              end else if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_8BIT) begin
                // 8-bit write. ASSUMING SDRAM.

                // assert byte is repeated across halfword so we can pass it unchanged
                assert(cpu_dBus_cmd_payload_data[15:8] == cpu_dBus_cmd_payload_data[7:0]);

`ifdef VERBOSE_MEMCTL
                $display("begin 8-bit write [%08Xh] <= %02Xh msk=%04b", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data[7:0], cpu_dBus_cmd_payload_mask);
`endif

                mem_state <= STATE_SDRAM_WAIT;

                sdram_addr_x16 <= cpu_dBus_cmd_payload_address[$left(sdram_addr_x16) + 1:1];
                sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                sdram_wr <= 1;
                sdram_wmask <= cpu_dBus_cmd_payload_mask[1:0] | cpu_dBus_cmd_payload_mask[3:2];
              end else if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_16BIT) begin
                // 16-bit write. ASSUMING SDRAM.

`ifdef VERBOSE_MEMCTL
                $display("begin 16-bit write [%08Xh] <= %04Xh", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data[15:0]);
`endif

                mem_state <= STATE_SDRAM_WAIT;

                sdram_addr_x16 <= cpu_dBus_cmd_payload_address[$left(sdram_addr_x16) + 1:1];
                sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                sdram_wr <= 1;
              end else if (!cpu_dBus_cmd_payload_wr) begin
                // TODO: move out? or just wait until complete rewrite?
                if (cpu_dBus_cmd_payload_size >= CMD_SIZE_32BIT) begin
                  words_remaining <= (1 << (cpu_dBus_cmd_payload_size - 2)) - 1;
                end else begin
                  words_remaining <= 0;
                end

                // 32-bit read. Can be BootROM or SDRAM
                if (dBus_is_sdram_addr) begin
`ifdef VERBOSE_MEMCTL
                    $display("begin 32-bit read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
`endif

                    // low halfword first
                    sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[$left(sdram_addr_x16) + 1:2], 1'b0};
                    sdram_cmd_valid <= '1;

                    mem_state <= STATE_SDRAM_READ;
                end else begin
                    // ROM read (or a futile attempt to write)
                    // ROM read finishes simultaneously and so will the setting of the RDATA mux
`ifdef VERBOSE_MEMCTL
                    $display("begin ROM read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
`endif

                    mem_state <= STATE_WAIT_BOOTROM;

                    mem_purpose <= PURPOSE_D;
                end
              end else begin
                $display("begin INVALID OP [%08Xh] is_wr=%d msk=%04b sz=%d", cpu_dBus_cmd_payload_address,
                    cpu_dBus_cmd_payload_wr, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
              end

              mem_purpose <= PURPOSE_D;
            end else if (cpu_iBus_cmd_valid) begin
                // Instruction bus read. Always a series of 32-bit words. ASSUMING BOOTROM.
                // There is no 'last' signal; we have to look at 'size' (which is log2(bytes_to_read)) and loop

                mem_addr <= cpu_iBus_cmd_payload_address;
                mem_is_wr <= 0;

                if (iBus_is_sdram_addr) begin
`ifdef VERBOSE_MEMCTL
                    $display("begin 32-bit SDRAM read via I-bus [%08Xh] sz=%d", cpu_iBus_cmd_payload_address, cpu_iBus_cmd_payload_size);
`endif

                    // low halfword first
                    sdram_addr_x16 <= {cpu_iBus_cmd_payload_address[$left(sdram_addr_x16) + 1:2], 1'b0};
                    sdram_cmd_valid <= 1;

                    mem_state <= STATE_SDRAM_READ;
                end else begin
`ifdef VERBOSE_MEMCTL
                    $display("begin 32-bit burst ROM read via I-bus [%08Xh]", cpu_iBus_cmd_payload_address);
`endif

                    mem_addr <= cpu_iBus_cmd_payload_address;
                    mem_state <= STATE_WAIT_BOOTROM;
                end

                mem_purpose <= PURPOSE_I;
                words_remaining <= (1 << (cpu_iBus_cmd_payload_size - 2)) - 1;
            end
        end

        STATE_SDRAM_READ: begin
            if (sdram_cmd_ready) begin
                sdram_cmd_valid <= '0;
            end

            if (sdram_resp_valid) begin
                if (sdram_addr_x16[0] == '0) begin
                    // Acknowledge low halfword
                    sdram_ack <= '1;
                end else begin
                    // addr=1 -> 32-bit read finished
                    sdram_wr <= 0;

                    if (mem_purpose == PURPOSE_I) begin
                        cpu_iBus_rsp_valid <= 1'b1;
                    end else begin
                        cpu_dBus_rsp_valid <= 1;
                    end

                    if (words_remaining == 0) begin
                        mem_state <= STATE_FINISHED;
                    end else begin
                        mem_state <= STATE_SDRAM_ACK;

                        sdram_ack <= 1;   // not async safe etc.
                    end

                    mem_addr <= mem_addr + 4;
                    words_remaining <= words_remaining - 1;
                end

            end else if (sdram_addr_x16[0] == 0 && sdram_ack == 1) begin
                // in process of acknowledging 1st half of 32-bit read

                sdram_cmd_valid <= '1;
                sdram_ack <= '0;

                // high halfword now
                sdram_addr_x16 <= {mem_addr[$left(sdram_addr_x16) + 1:2], 1'b1};
            end
        end

        STATE_SDRAM_WAIT: begin
            assert(mem_is_wr);

            // 1 cycle to propagate request to SDRAM
            // 1 cycle to see de-asserted SDRAM rdy
            if (waitstate_counter < 2) begin
                waitstate_counter <= waitstate_counter + 1;
            end else if (sdram_addr_x16[0] == 0 && sdram_ack == 1) begin
                // in process of acknowledging 1st half of 32-bit write

                sdram_wr <= 1;
                sdram_ack <= 0;

                // high halfword now
                sdram_addr_x16 <= {mem_addr[$left(sdram_addr_x16) + 1:2], 1'b1};
                sdram_wdata <= mem_wdata[31:16];

                waitstate_counter <= 0;
            end else if (sdram_rdy) begin
                // NB: None of this is async-safe

                if (mem_size == CMD_SIZE_32BIT) begin
                    // 32-bit write

                    if (sdram_addr_x16[0] == 0 && sdram_ack == 0) begin
                        sdram_wr <= 0;
                        sdram_ack <= 1;

                        mem_state <= STATE_SDRAM_WAIT;
                    end else if (sdram_addr_x16[0] == 1) begin
                        // addr=1, sdram ready, wait done -> 32-bit write finished
                        sdram_wr <= 0;
                        mem_state <= STATE_FINISHED;
                    end
                end else begin
                    // 16-bit write

                    sdram_wr <= 0;
                    mem_state <= STATE_FINISHED;

                end
            end

        end

        STATE_SDRAM_ACK: begin
          // low halfword first
          sdram_addr_x16 <= {mem_addr[$left(sdram_addr_x16) + 1:2], 1'b0};
          sdram_cmd_valid <= 1;
          mem_state <= STATE_SDRAM_READ;
          sdram_ack <= 0;
        end

        STATE_FINISHED: begin
            mem_state <= STATE_IDLE;
            sdram_ack <= 1;         // OK to only be ACKing when already ready for next request?
        end

        // TODO: possible to get rid of this extra wait-state?
        //       (adding a mux to cpu_dBus_rsp_payload_data won't work, brings down f_max)
        STATE_WAIT_BOOTROM: begin
            mem_addr <= mem_addr + 4;
            mem_state <= STATE_BURST_READ_BOOTROM;
        end

        STATE_BURST_READ_BOOTROM: begin
            if (mem_purpose == PURPOSE_I) begin
                cpu_iBus_rsp_valid <= 1'b1;
            end else begin
                cpu_dBus_rsp_valid <= 1;
            end

            reading_bootrom <= 1;

            if (words_remaining == 0) begin
                mem_state <= STATE_FINISHED;
            end else begin
                mem_state <= STATE_BURST_READ_BOOTROM;
            end

            mem_addr <= mem_addr + 4;
            words_remaining <= words_remaining - 1;
        end

        STATE_CSR: begin
            if (csr_ack_i) begin
                // send response only if reading
                cpu_dBus_rsp_valid <= !csr_we_o;

                mem_state <= STATE_FINISHED;
            end
        end
        endcase
    end

    if (reading_bootrom) begin
`ifdef VERBOSE_MEMCTL
      $display("  ROM read => %08X", bootrom_data_i);
`endif
    end
end

// indent: 4sp
always @ (posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
        csr_cyc_o <= '0;
        csr_stb_o <= '0;
        csr_adr_o <= '0;
        csr_we_o <= '0;
        csr_dat_o <= '0;
    end else begin
        if (mem_state == STATE_IDLE) begin
            if (cpu_dBus_cmd_valid && dBus_is_csr_addr) begin
                csr_cyc_o <= '1;
                csr_stb_o <= '1;
            end

            // Slightly tricky, as csr_adr_o doesn't go down to 0.
            csr_adr_o[$left(csr_adr_o):2] <= cpu_dBus_cmd_payload_address[$left(csr_adr_o):2];

            csr_we_o <= cpu_dBus_cmd_payload_wr;
            csr_dat_o <= cpu_dBus_cmd_payload_data;
        end else if (mem_state == STATE_CSR) begin
            if (!csr_stall_i) csr_stb_o <= '0;
            if (csr_ack_i) csr_cyc_o <= '0;
        end
    end
end

reg[15:0] sdram_rdata_low;
reg[31:0] cpu_rdata;

always_ff @ (posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
        sdram_rdata_low <= '0;
        cpu_rdata <= '0;
    end else begin
        // TOOD: how to give hint that all ifs exclusive?

        cpu_rdata <= 'x;        // data read response only matters during a single-cycle strobe

        if (csr_ack_i) begin
            cpu_rdata <= csr_dat_i;
        end

        if (mem_state == STATE_BURST_READ_BOOTROM) begin
            cpu_rdata <= bootrom_data_i;
        end

        if (mem_state == STATE_SDRAM_READ) begin
            if (sdram_resp_valid) begin
                if (sdram_addr_x16[0] == 0)
                    sdram_rdata_low <= sdram_rdata;
                else begin
`ifdef VERBOSE_MEMCTL
                    $display("  finished 32-bit SDRAM read [%08X] => %08X", mem_addr, {sdram_rdata, sdram_rdata_low});
`endif

                    cpu_rdata <= {sdram_rdata, sdram_rdata_low};
                end
            end
        end
    end
end

assign bootrom_addr_o[$left(bootrom_addr_o):2] = mem_addr[$left(bootrom_addr_o):2];

assign cpu_dBus_rsp_payload_data = cpu_rdata;
assign cpu_iBus_rsp_payload_data = cpu_rdata;

endmodule
