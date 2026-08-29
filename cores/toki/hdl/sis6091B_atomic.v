`ifndef SIS6091B_ATOMIC_V
`define SIS6091B_ATOMIC_V

// FPGA storage implementation used at the four sheet-18 SIS6091B positions
// U181-U184.  The name identifies the schematic device being represented; the
// atomic validity plane and first-write admission below are NOT claimed as
// recovered SIS6091B die internals.
//
// FPGA block RAM cannot clear all 512 FIND states in one physical CLR event.
// Pixel data therefore stays in one registered-read M10K while a second M10K
// holds two 512-bit FIND epochs. CLR swaps to the already-clean epoch in one
// clock and the retired epoch is scrubbed sequentially in the background.
// The caller keeps the sheet-specific pin timing visible: pin-31 write phase
// and pin-34 CLR have already been converted to one-clock write_req/clear_cmd
// commands before entering this module.
//
// This FPGA mechanism depends on a measured Toki line-buffer timing contract,
// not on a claimed SIS6091B die implementation. In the dense 81-frame stock
// trace, the shortest CLR-to-first-write interval is 1167 master clocks and
// the shortest same-bank CLR interval is 6144 clocks. A complete 512-entry
// scrub therefore finishes before either a write or reuse of the retired
// epoch. Simulation diagnoses a new CLR which violates that contract.
//
// One shared address is intentional. The validity lookup which admits a
// pending write is captured with the same physical address as the registered
// data read. A newly accepted same-address write forwards FIND immediately;
// its new data word becomes readable on the following master clock, matching
// the registered M10K contract used by Toki's non-displayed write bank.
module sis6091B_atomic #(
    parameter integer ADDR_W = 9,  // Sheet 18 uses pins A1-A9 (512 entries).
    parameter integer DATA_W = 10  // Physical OBJ data/attribute word width.
)(
    // FPGA 48 MHz master clock; this is not a SIS6091B package pin.
    input  wire                   clk,

    // One-clock FPGA command derived from the falling edge of active-low
    // SIS6091B pin 34 (EVNCLR or ODDCLR). It atomically releases all FINDs.
    input  wire                   clear_cmd,

    // One-clock FPGA command derived from bubbled pin 31 (OBJ_N6M), qualified
    // by active-low pin 30 WREN, OBJPS drive-valid and transparent-pen checks.
    input  wire                   write_req,

    // Physical pins 6,7,8,10,12-17 carry OBJ[9:0].
    input  wire [DATA_W-1:0]      write_data,

    // Physical address pins 62-70. Package pin 71 is grounded on sheet 18.
    input  wire [ADDR_W-1:0]      addr,

    // FPGA representation of physical pin 60 FIND (active-high contract).
    output wire                   read_valid,

    // Stored word corresponding to physical OOD pins 42-49, PRIOR_C pin 51
    // and PRIOR_D pin 53.
    output wire [DATA_W-1:0]      read_data
);

localparam integer DEPTH = 1 << ADDR_W;
localparam integer VALID_DEPTH = 2 << ADDR_W;
localparam [ADDR_W-1:0] LAST_ADDR = {ADDR_W{1'b1}};

(* ramstyle = "M10K" *) reg [DATA_W-1:0] mem [0:DEPTH-1];

// The epoch bit is the extra address bit, so one 1024x1 simple dual-port M10K
// provides two independent 512-entry FIND planes. Its read port follows the
// physical line address. The write port either admits the first opaque pixel
// in the active epoch or clears one entry of the retired epoch.
(* ramstyle = "M10K, no_rw_check" *) reg valid_mem [0:VALID_DEPTH-1];

reg                  write_pending = 1'b0;
reg [ADDR_W-1:0]     pending_addr = {ADDR_W{1'b0}};
reg [DATA_W-1:0]     pending_data = {DATA_W{1'b0}};
reg [DATA_W-1:0]     read_word = {DATA_W{1'b0}};
reg                  valid_read = 1'b0;
reg                  valid_forward = 1'b0;
reg                  accepted_l = 1'b0;
reg [ADDR_W-1:0]     accepted_addr_l = {ADDR_W{1'b0}};

reg                  active_epoch = 1'b0;
reg                  scrub_active = 1'b0;
reg                  scrub_epoch = 1'b0;
reg [ADDR_W-1:0]     scrub_addr = {ADDR_W{1'b0}};
reg                  clear_mask = 1'b0;

integer init_addr;
initial begin
    // Intel FPGA block RAM supports initialized contents. Initializing only
    // the validity M10K gives both epochs the same empty state as the former
    // register plane, while stale pixel data remains safely don't-care.
    for (init_addr = 0; init_addr < VALID_DEPTH; init_addr = init_addr + 1)
        valid_mem[init_addr] = 1'b0;
end

// valid_read is aligned with the write captured on the preceding clock. A
// one-cycle bypass prevents a back-to-back same-address request from seeing
// old-data behavior on the validity M10K and replacing the first pixel.
wire pending_owned = valid_read ||
                     (accepted_l && (pending_addr == accepted_addr_l));
wire write_accept = write_pending && !clear_cmd && !pending_owned;

// The validity RAM has one write port. Accepted pixels take priority; a scrub
// simply pauses if a future caller ever overlaps the two operations. Toki's
// measured 1167-clock quiet interval currently completes every scrub before
// the first write, so this arbitration adds no raster-visible delay.
wire scrub_step = scrub_active && !write_accept && !clear_cmd;
wire valid_write = write_accept || scrub_step;
wire [ADDR_W:0] valid_write_addr = write_accept ?
                                     {active_epoch, pending_addr} :
                                     {scrub_epoch, scrub_addr};
wire valid_write_data = write_accept;

always @(posedge clk) begin
    read_word <= mem[addr];
    if (write_accept)
        mem[pending_addr] <= pending_data;
end

always @(posedge clk) begin
    valid_read <= valid_mem[{active_epoch, addr}];
    if (valid_write)
        valid_mem[valid_write_addr] <= valid_write_data;
end

always @(posedge clk) begin
    clear_mask <= clear_cmd;

    if (clear_cmd) begin
        // The inactive epoch was scrubbed after its preceding retirement, so
        // selecting it atomically releases every FIND. Retire and scrub the
        // old epoch while canceling a write pending on this same edge.
        active_epoch  <= ~active_epoch;
        scrub_active  <= 1'b1;
        scrub_epoch   <= active_epoch;
        scrub_addr    <= {ADDR_W{1'b0}};
        write_pending <= 1'b0;
        valid_forward <= 1'b0;
        accepted_l    <= 1'b0;
    end else begin
        write_pending <= write_req;
        if (write_req) begin
            pending_addr <= addr;
            pending_data <= write_data;
        end

        accepted_l <= write_accept;
        if (write_accept) begin
            accepted_addr_l <= pending_addr;
        end

        // FIND is forwarded on the commit edge; data remains the registered
        // M10K word and follows one clock later, preserving the old contract.
        valid_forward <= write_accept && (addr == pending_addr);

        if (scrub_step) begin
            if (scrub_addr == LAST_ADDR) begin
                scrub_active <= 1'b0;
            end else begin
                scrub_addr <= scrub_addr + 1'b1;
            end
        end
    end
end

// clear_mask hides the old epoch's registered read on the swap edge. On the
// following edge valid_read is already sourced from the new active epoch.
assign read_valid = !clear_mask && (valid_read || valid_forward);
assign read_data  = read_word;

// synthesis translate_off
always @(posedge clk) begin
    if (clear_cmd && scrub_active) begin
        $display("ERROR: %m CLR reused a FIND epoch before its 512-entry scrub completed");
        $fatal(1);
    end
end
// synthesis translate_on

endmodule

`endif
