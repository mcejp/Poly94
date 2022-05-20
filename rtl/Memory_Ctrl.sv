// Poly94 Memory Control
//  - dispatches transactions to the correct destination
//  - does not include boot ROM, SDRAM controller nor I/O registers
//  - to be heavily optimized...
//
// indent: 2sp

// `define VERBOSE_MEMCTL

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
  output            cpu_iBus_cmd_ready,
  input[31:0]       cpu_iBus_cmd_payload_address,
  input[2:0]        cpu_iBus_cmd_payload_size,
  output reg        cpu_iBus_rsp_valid,
  output[31:0]      cpu_iBus_rsp_payload_data,

  // SDRAM
  output reg        sdram_rd,           // not strobe -- keep up until ACK (TODO verify)
  output reg        sdram_wr,
  output            sdram_rdy,
  output reg        sdram_ack,
  output reg[23:0]  sdram_addr_x16,     // sdram address in 16-bit words (16Mw => 32MB)
  output reg[15:0]  sdram_wdata,
  output[15:0]      sdram_rdata,
  output reg[1:0]   sdram_wmask,

  output[31:0]      addr_o,             // applies to Boot ROM (only?)
  input[31:0]       bootrom_data_i,

  // these change in 0 cycles from the CPU request
  // (probably unnecessary & should be pipelined & folded into addr_o)
  output            io_write_valid_o,
  output[31:0]      io_addr_o,
  input[31:0]       io_rdata_i,
  output[31:0]      io_wdata_o
);

// Read data multiplex


reg[31:0] cpu_sdram_rdata;

enum { MEM_BOOTROM, MEM_IO, MEM_SDRAM } cpu_mem_select;

//

localparam CMD_SIZE_8BIT  = 2'd0;
localparam CMD_SIZE_16BIT = 2'd1;
localparam CMD_SIZE_32BIT = 2'd2;

// keep number of top-level states to a minimum so that high-fanout expressions like 'io_write_valid_o' are simple
enum { STATE_IDLE, STATE_FINISHED, STATE_SDRAM_WAIT, STATE_BURST_READ_BOOTROM, STATE_SDRAM_ACK } mem_state;

wire is_io_addr =        (cpu_dBus_cmd_payload_address[27:24] == 4'h1);
wire is_sdram_addr =     (cpu_dBus_cmd_payload_address[27] == 1'b1);
assign io_write_valid_o = (mem_state == STATE_IDLE && cpu_dBus_cmd_valid && is_io_addr && cpu_dBus_cmd_payload_wr);

reg[1:0] waitstate_counter;
reg[2:0] words_remaining;       // up to 7

reg[31:0] mem_addr;
reg mem_is_wr;
reg[2:0] mem_size;
reg[31:0] mem_wdata;          // we never use the lower half, but it will be optimized out

enum { PURPOSE_I, PURPOSE_D } mem_purpose;

reg reading_bootrom;

always @ (*) begin
    // ready must go down in 0 clocks, otherwise we will be flooded with further requests
    cpu_dBus_cmd_ready <= (mem_state == STATE_IDLE);
end

always @ (posedge clk_i) begin
    sdram_ack <= 0;     // really single cycle strobe?

    reading_bootrom <= 0;

    cpu_iBus_rsp_valid <= 0;
    cpu_dBus_rsp_valid <= 0;

    if (rst_i) begin
        mem_state <= STATE_IDLE;
        cpu_mem_select <= MEM_BOOTROM;
        sdram_rd <= 0;
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

              if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT) begin
                // 32-bit write. ASSUMING SDRAM.

`ifdef VERBOSE_MEMCTL
                $display("begin 32-bit write [%08Xh] <= %08Xh sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data, cpu_dBus_cmd_payload_size);
`endif

                mem_state <= STATE_SDRAM_WAIT;

                // low halfword first
                sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:2], 1'b0};
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

                sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:1]};
                sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                sdram_wr <= 1;
                sdram_wmask <= cpu_dBus_cmd_payload_mask[1:0] | cpu_dBus_cmd_payload_mask[3:2];
              end else if (cpu_dBus_cmd_payload_wr && cpu_dBus_cmd_payload_size == CMD_SIZE_16BIT) begin
                // 16-bit write. ASSUMING SDRAM.

`ifdef VERBOSE_MEMCTL
                $display("begin 16-bit write [%08Xh] <= %04Xh", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_data[15:0]);
`endif

                mem_state <= STATE_SDRAM_WAIT;

                sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:1]};
                sdram_wdata <= cpu_dBus_cmd_payload_data[15:0];
                sdram_wr <= 1;
              end else if (!cpu_dBus_cmd_payload_wr) begin
                if (cpu_dBus_cmd_payload_size >= CMD_SIZE_32BIT) begin
                  words_remaining <= (1 << (cpu_dBus_cmd_payload_size - 2)) - 1;
                end else begin
                  words_remaining <= 0;
                end

                // 32-bit read. Can be BootROM or SDRAM
                if (is_sdram_addr) begin
`ifdef VERBOSE_MEMCTL
                    $display("begin 32-bit read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
`endif

                    // low halfword first
                    sdram_addr_x16 <= {cpu_dBus_cmd_payload_address[31:2], 1'b0};
                    sdram_rd <= 1;

                    cpu_mem_select <= MEM_SDRAM;
                    mem_state <= STATE_SDRAM_WAIT;
                end else if (is_io_addr && cpu_dBus_cmd_payload_size == CMD_SIZE_32BIT) begin
`ifdef VERBOSE_MEMCTL
                    $display("begin IO read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
`endif

                    cpu_mem_select <= MEM_IO;

                    mem_state <= STATE_FINISHED;
                    cpu_dBus_rsp_valid <= 1;
                end else begin
                    // ROM read (or a futile attempt to write)
                    // ROM read finishes simultaneously and so will the setting of the RDATA mux
`ifdef VERBOSE_MEMCTL
                    $display("begin ROM read [%08Xh] msk=%04b sz=%d", cpu_dBus_cmd_payload_address, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
`endif

                    cpu_mem_select <= MEM_BOOTROM;
                    mem_state <= STATE_BURST_READ_BOOTROM;

                    mem_purpose <= PURPOSE_D;
                end
              end else begin
                $display("begin INVALID OP [%08Xh] is_wr=%d msk=%04b sz=%d", cpu_dBus_cmd_payload_address,
                    cpu_dBus_cmd_payload_wr, cpu_dBus_cmd_payload_mask, cpu_dBus_cmd_payload_size);
              end
            end else if (cpu_iBus_cmd_valid) begin
                // Instruction bus read. Always a series of 32-bit words. ASSUMING BOOTROM.
                // There is no 'last' signal; we have to look at 'size' (which is log2(bytes_to_read)) and loop

`ifdef VERBOSE_MEMCTL
                $display("begin 32-bit burst ROM read via I-bus [%08Xh]", cpu_iBus_cmd_payload_address);
`endif

                words_remaining <= (1 << (cpu_iBus_cmd_payload_size - 2)) - 1;

                mem_addr <= cpu_iBus_cmd_payload_address;
                mem_state <= STATE_BURST_READ_BOOTROM;
                mem_purpose <= PURPOSE_I;
            end
        end

        STATE_SDRAM_WAIT: begin
            // 1 cycle to propagate request to SDRAM
            // 1 cycle to see de-asserted SDRAM rdy
            if (waitstate_counter < 2) begin
                waitstate_counter <= waitstate_counter + 1;
            end else if (sdram_addr_x16[0] == 0 && sdram_ack == 1) begin
                // in process of acknowledging 1st half of 32-bit read/write

                if (mem_is_wr) begin
                    sdram_wr <= 1;
                end else begin
                    sdram_rd <= 1;
                end

                sdram_ack <= 0;

                // high halfword now
                sdram_addr_x16 <= {mem_addr[31:2], 1'b1};
                sdram_wdata <= mem_wdata[31:16];

                waitstate_counter <= 0;
            end else if (sdram_rdy) begin
                // NB: None of this is async-safe

                if (mem_is_wr) begin
                  if (mem_size == CMD_SIZE_32BIT) begin
                    // 32-bit write

                    if (sdram_addr_x16[0] == 0 && sdram_ack == 0) begin
                        sdram_wr <= 0;
                        sdram_ack <= 1;

                        mem_state <= STATE_SDRAM_WAIT;
                    end else if (sdram_addr_x16[0] == 1) begin
                        // addr=1, sdram ready, wait done -> 32-bit write finished
                        sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                        sdram_wr <= 0;
                        mem_state <= STATE_FINISHED;
                    end
                  end else begin
                    // 16-bit write

                    sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                    sdram_wr <= 0;
                    mem_state <= STATE_FINISHED;

                  end
                end else begin
                    // 32-bit read

                    if (sdram_addr_x16[0] == 0 && sdram_ack == 0) begin
                        // Acknowledge low halfword

                        cpu_sdram_rdata[15:0] <= sdram_rdata;
                        sdram_rd <= 0;
                        sdram_ack <= 1;

                        mem_state <= STATE_SDRAM_WAIT;
                    end else if (sdram_addr_x16[0] == 1) begin
                        cpu_sdram_rdata[31:16] <= sdram_rdata;

                        // addr=1, sdram ready, wait done -> 32-bit read finished
                        sdram_rd <= 0;      // probably not OK to de-assert simultaneously with ACK if asynchronous? what if ACK arrives 1 cycle earlier?
                        sdram_wr <= 0;

                        cpu_dBus_rsp_valid <= 1;

`ifdef VERBOSE_MEMCTL
                        $display("  finished 32-bit SDRAM read [%08X] => %08X", mem_addr, {sdram_rdata, cpu_sdram_rdata[15:0]});
`endif

                        if (words_remaining == 0) begin
                            mem_state <= STATE_FINISHED;
                        end else begin
                            mem_state <= STATE_SDRAM_ACK;

                            cpu_mem_select <= MEM_SDRAM;
                            sdram_ack <= 1;   // not async safe etc.
                        end

                        waitstate_counter <= 0;

                        mem_addr <= mem_addr + 4;
                        words_remaining <= words_remaining - 1;
                    end
                end
            end

        end

        STATE_SDRAM_ACK: begin
          // low halfword first
          sdram_addr_x16 <= {mem_addr[31:2], 1'b0};
          sdram_rd <= 1;
          mem_state <= STATE_SDRAM_WAIT;
          sdram_ack <= 0;
        end

        STATE_FINISHED: begin
            mem_state <= STATE_IDLE;
            sdram_ack <= 1;         // OK to only be ACKing when already ready for next request?
        end

        STATE_BURST_READ_BOOTROM: begin
            if (mem_purpose == PURPOSE_I) begin
                cpu_iBus_rsp_valid <= 1'b1;
            end else begin
                cpu_dBus_rsp_valid <= 1;
            end

            reading_bootrom <= 1;

            cpu_mem_select <= MEM_BOOTROM;

            if (words_remaining == 0) begin
                mem_state <= STATE_FINISHED;
            end else begin
                mem_state <= STATE_BURST_READ_BOOTROM;
            end

            mem_addr <= mem_addr + 4;
            words_remaining <= words_remaining - 1;
        end
        endcase
    end

    if (reading_bootrom) begin
`ifdef VERBOSE_MEMCTL
      $display("  ROM read => %08X", bootrom_data_i);
`endif
    end
end

assign addr_o = mem_addr;
assign io_addr_o = cpu_dBus_cmd_payload_address;
assign io_wdata_o = cpu_dBus_cmd_payload_data;

assign cpu_dBus_rsp_payload_data = cpu_mem_select == MEM_IO ? io_rdata_i :
                               cpu_mem_select == MEM_BOOTROM ? bootrom_data_i :
                               cpu_sdram_rdata;

assign cpu_iBus_rsp_payload_data = cpu_mem_select == MEM_BOOTROM ? bootrom_data_i :
                               cpu_sdram_rdata;

endmodule