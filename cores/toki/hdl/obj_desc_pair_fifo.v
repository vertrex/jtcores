`ifndef OBJ_DESC_PAIR_FIFO_V
`define OBJ_DESC_PAIR_FIFO_V

`timescale 1ns/1ps

// FPGA-side capture FIFO for the two object descriptors in one 16-pixel raster
// bucket. The active compact compatibility protocol maps lane 0/direct OBJ2 to
// entry 2n and lane 1/delayed OBJ1 to entry 2n+1. That is the hardware-good
// FPGA schedule, not a claim about the unrecovered physical SORT48 pin
// permutation. This is not a model of a PCB custom IC: it isolates one-cycle
// registered U153 read latency from later acknowledged-ROM work without
// applying backpressure to the raster scan.
//
// cap_char/cap_hpos are request pulses. The corresponding OVD word is sampled
// one clk later, after the synchronous RAM output has settled. cap_lane is the
// caller's normalized compatibility classifier for the current compact H2
// role, not necessarily the literal SG0140 pin:
//   lane 0 = direct U168 / OBJ2 / U1712
//   lane 1 = delayed U162 / OBJ1 / U1711
// HPOS row/flip/priority/bank sidebands are saved on the request edge because
// the physical list-RAM address may advance before OVD settles. Presence is the
// exception: the production caller derives cap_present from the selected
// U151/U152 NOOBJ validity and the settled-HPOS visibility rule, so it is
// sampled on the response edge. U153 supplies OVD, not NOOBJ.
//
// Only one descriptor pair may be assembled at a time. The caller must issue
// one CHAR and one HPOS request for each lane before repeating a lane/type;
// duplicate or simultaneous shared-OVD requests latch protocol_error.
//
// A pair is considered complete only after both CHAR and HPOS responses have
// arrived for both lanes. One absent descriptor still completes its lane and
// is replayed as a transparent row. A pair with both descriptors absent is
// discarded as an FPGA bandwidth optimization: the PCB still scans the fixed
// slot, but it cannot emit a visible sprite pixel and needs no acknowledged
// SDRAM/replay work.
//
// Packed output context, 81 bits total:
//   [80]    pair line-bank/parity tag
//   [79:40] lane 1 descriptor (H2=1, delayed OBJ1/FH path)
//   [39:0]  lane 0 descriptor (H2=0, direct OBJ2/OH path)
// Descriptor payload, relative to each 40-bit lane:
//   [39]    present
//   [38]    horizontal flip
//   [37]    SPR2 priority
//   [36]    SPR1 priority
//   [35:32] row / VA
//   [31:16] HPOS word
//   [15:0]  CHAR word
//
// There is intentionally no capture-side ready signal. If 32 queued pairs
// containing at least one present lane accumulate while output is stalled, the
// next such pair is dropped and overflow latches high. A simultaneous output
// pop permits a full FIFO to accept one new pair without loss.

module obj_desc_pair_fifo(
    input             clk,
    input             rst,
    // Explicit caller abort, deliberately separate from reset so sticky
    // diagnostics survive. Production does not connect this to raw V1B: the
    // compact 48-slot compatibility stream crosses that edge, so the adapter
    // uses per-pair bank tags and selectively retires only work which reaches
    // the following HBLB-rise deadline.
    input             flush,

    input             cap_char,
    input             cap_hpos,
    input             cap_lane,
    input             cap_present,
    input       [3:0] cap_row,
    input             cap_flip,
    input             cap_spr1,
    input             cap_spr2,
    input             cap_bank,
    input      [15:0] ovd,

    output            out_valid,
    input             out_ready,
    output     [80:0] out_context,
    output      [5:0] occupancy,
    output reg        overflow,
    output reg        protocol_error
);

localparam integer DEPTH = 32;
localparam integer PTR_W = 5;

reg [80:0] fifo_mem [0:DEPTH-1];
reg [PTR_W-1:0] wr_ptr;
reg [PTR_W-1:0] rd_ptr;
reg [5:0] fifo_count;

reg [15:0] char_word [0:1];
reg [15:0] hpos_word [0:1];
reg  [3:0] row_hold  [0:1];
reg        present_hold [0:1];
reg        flip_hold [0:1];
reg        spr1_hold [0:1];
reg        spr2_hold [0:1];
reg        bank_hold [0:1];
reg  [1:0] char_seen;
reg  [1:0] hpos_seen;

reg        char_pending;
reg        char_pending_lane;
reg        hpos_pending;
reg        hpos_pending_lane;
reg  [3:0] hpos_pending_row;
reg        hpos_pending_flip;
reg        hpos_pending_spr1;
reg        hpos_pending_spr2;
reg        hpos_pending_bank;

wire [1:0] char_response_mask = char_pending ?
                                (char_pending_lane ? 2'b10 : 2'b01) : 2'b00;
wire [1:0] hpos_response_mask = hpos_pending ?
                                (hpos_pending_lane ? 2'b10 : 2'b01) : 2'b00;
wire [1:0] char_seen_next = char_seen | char_response_mask;
wire [1:0] hpos_seen_next = hpos_seen | hpos_response_mask;
wire       pair_complete = (&char_seen_next) && (&hpos_seen_next);

// Include a response arriving on this edge directly in the packed FIFO word;
// the staging registers receive the same value through nonblocking updates.
wire [15:0] lane0_char = (char_pending && !char_pending_lane) ?
                         ovd : char_word[0];
wire [15:0] lane1_char = (char_pending &&  char_pending_lane) ?
                         ovd : char_word[1];
wire [15:0] lane0_hpos = (hpos_pending && !hpos_pending_lane) ?
                         ovd : hpos_word[0];
wire [15:0] lane1_hpos = (hpos_pending &&  hpos_pending_lane) ?
                         ovd : hpos_word[1];
wire  [3:0] lane0_row = (hpos_pending && !hpos_pending_lane) ?
                        hpos_pending_row : row_hold[0];
wire  [3:0] lane1_row = (hpos_pending &&  hpos_pending_lane) ?
                        hpos_pending_row : row_hold[1];
wire lane0_present = (hpos_pending && !hpos_pending_lane) ?
                     cap_present : present_hold[0];
wire lane1_present = (hpos_pending &&  hpos_pending_lane) ?
                     cap_present : present_hold[1];
wire lane0_flip = (hpos_pending && !hpos_pending_lane) ?
                  hpos_pending_flip : flip_hold[0];
wire lane1_flip = (hpos_pending &&  hpos_pending_lane) ?
                  hpos_pending_flip : flip_hold[1];
wire lane0_spr1 = (hpos_pending && !hpos_pending_lane) ?
                  hpos_pending_spr1 : spr1_hold[0];
wire lane1_spr1 = (hpos_pending &&  hpos_pending_lane) ?
                  hpos_pending_spr1 : spr1_hold[1];
wire lane0_spr2 = (hpos_pending && !hpos_pending_lane) ?
                  hpos_pending_spr2 : spr2_hold[0];
wire lane1_spr2 = (hpos_pending &&  hpos_pending_lane) ?
                  hpos_pending_spr2 : spr2_hold[1];
wire lane0_bank = (hpos_pending && !hpos_pending_lane) ?
                  hpos_pending_bank : bank_hold[0];
wire lane1_bank = (hpos_pending &&  hpos_pending_lane) ?
                  hpos_pending_bank : bank_hold[1];

wire [39:0] lane0_desc = {
    lane0_present, lane0_flip, lane0_spr2, lane0_spr1,
    lane0_row, lane0_hpos, lane0_char
};
wire [39:0] lane1_desc = {
    lane1_present, lane1_flip, lane1_spr2, lane1_spr1,
    lane1_row, lane1_hpos, lane1_char
};
wire [80:0] completed_context = {lane0_bank, lane1_desc, lane0_desc};
wire        pair_any_present = lane0_present || lane1_present;

assign out_valid   = fifo_count != 6'd0;
assign out_context = fifo_mem[rd_ptr];
assign occupancy   = fifo_count;

wire pop = out_valid && out_ready;
wire fifo_full = fifo_count == 6'd32;
wire can_push = !fifo_full || pop;
wire push = pair_complete && pair_any_present && can_push;

integer init_index;
always @(posedge clk) begin
    if (rst) begin
        wr_ptr <= {PTR_W{1'b0}};
        rd_ptr <= {PTR_W{1'b0}};
        fifo_count <= 6'd0;
        char_seen <= 2'b00;
        hpos_seen <= 2'b00;
        char_pending <= 1'b0;
        char_pending_lane <= 1'b0;
        hpos_pending <= 1'b0;
        hpos_pending_lane <= 1'b0;
        hpos_pending_row <= 4'h0;
        hpos_pending_flip <= 1'b0;
        hpos_pending_spr1 <= 1'b0;
        hpos_pending_spr2 <= 1'b0;
        hpos_pending_bank <= 1'b0;
        overflow <= 1'b0;
        protocol_error <= 1'b0;
        for (init_index = 0; init_index < 2; init_index = init_index + 1) begin
            char_word[init_index] <= 16'h0000;
            hpos_word[init_index] <= 16'h0000;
            row_hold[init_index] <= 4'h0;
            present_hold[init_index] <= 1'b0;
            flip_hold[init_index] <= 1'b0;
            spr1_hold[init_index] <= 1'b0;
            spr2_hold[init_index] <= 1'b0;
            bank_hold[init_index] <= 1'b0;
        end
    end else if (flush) begin
        // Optional whole-queue abort for reset/debug users of this reusable
        // adapter. Memory contents need no clear because the count and
        // partial-response masks own validity.
        wr_ptr <= {PTR_W{1'b0}};
        rd_ptr <= {PTR_W{1'b0}};
        fifo_count <= 6'd0;
        char_seen <= 2'b00;
        hpos_seen <= 2'b00;
        char_pending <= 1'b0;
        hpos_pending <= 1'b0;
    end else begin
        // Requests are registered independently from responses. Nonblocking
        // ordering permits a response and the next request of the same type on
        // one edge without mixing their lane or sideband context.
        char_pending <= cap_char;
        if (cap_char)
            char_pending_lane <= cap_lane;

        hpos_pending <= cap_hpos;
        if (cap_hpos) begin
            hpos_pending_lane <= cap_lane;
            hpos_pending_row <= cap_row;
            hpos_pending_flip <= cap_flip;
            hpos_pending_spr1 <= cap_spr1;
            hpos_pending_spr2 <= cap_spr2;
            hpos_pending_bank <= cap_bank;
        end

        if (cap_char && cap_hpos)
            protocol_error <= 1'b1;

        if (char_pending) begin
            if (char_seen[char_pending_lane])
                protocol_error <= 1'b1;
            char_word[char_pending_lane] <= ovd;
        end

        if (hpos_pending) begin
            if (hpos_seen[hpos_pending_lane])
                protocol_error <= 1'b1;
            hpos_word[hpos_pending_lane] <= ovd;
            present_hold[hpos_pending_lane] <= cap_present;
            row_hold[hpos_pending_lane] <= hpos_pending_row;
            flip_hold[hpos_pending_lane] <= hpos_pending_flip;
            spr1_hold[hpos_pending_lane] <= hpos_pending_spr1;
            spr2_hold[hpos_pending_lane] <= hpos_pending_spr2;
            bank_hold[hpos_pending_lane] <= hpos_pending_bank;
        end

        if (pair_complete) begin
            // A line-bank mismatch means the caller crossed a V1B/list-bank
            // boundary while assembling one pair. Keep lane 0's tag for
            // deterministic diagnostics, but report the malformed sequence.
            if (lane0_bank != lane1_bank)
                protocol_error <= 1'b1;
            char_seen <= 2'b00;
            hpos_seen <= 2'b00;
            if (pair_any_present && !can_push)
                overflow <= 1'b1;
        end else begin
            char_seen <= char_seen_next;
            hpos_seen <= hpos_seen_next;
        end

        if (push) begin
            fifo_mem[wr_ptr] <= completed_context;
            wr_ptr <= wr_ptr + {{(PTR_W-1){1'b0}}, 1'b1};
        end

        if (pop)
            rd_ptr <= rd_ptr + {{(PTR_W-1){1'b0}}, 1'b1};

        case ({push, pop})
            2'b10: fifo_count <= fifo_count + 6'd1;
            2'b01: fifo_count <= fifo_count - 6'd1;
            default: fifo_count <= fifo_count;
        endcase
    end
end

endmodule

`endif
