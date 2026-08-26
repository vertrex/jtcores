`ifndef SIS6091B_ATOMIC_V
`define SIS6091B_ATOMIC_V

// FPGA storage implementation used at the four sheet-18 SIS6091B positions
// U181-U184.  The name identifies the schematic device being represented; the
// atomic validity plane and first-write admission below are NOT claimed as
// recovered SIS6091B die internals.
//
// FPGA block RAM cannot clear all 512 FIND states in one physical CLR event.
// Pixel data therefore stays in one registered-read M10K while a register
// validity plane implements the externally required atomic FIND result. The
// caller keeps the sheet-specific pin timing visible: pin-31 write phase and
// pin-34 CLR have already been converted to one-clock write_req/clear_cmd
// commands before entering this module.
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

(* ramstyle = "M10K" *) reg [DATA_W-1:0] mem [0:DEPTH-1];
reg [DEPTH-1:0] used = {DEPTH{1'b0}};

reg                  write_pending = 1'b0;
reg [ADDR_W-1:0]     pending_addr = {ADDR_W{1'b0}};
reg [DATA_W-1:0]     pending_data = {DATA_W{1'b0}};
reg [DATA_W-1:0]     read_word = {DATA_W{1'b0}};
reg                  read_used = 1'b0;

// read_used is aligned with the block-RAM word selected on the preceding
// clock.  It also supplies the already-owned test for the pending write.
wire write_accept = write_pending && !clear_cmd && !read_used;

always @(posedge clk) begin
    read_word <= mem[addr];

    if (clear_cmd) begin
        // Atomic validity clearing leaves stale block-RAM data as don't-care.
        // Clear also cancels a write which was pending on this same edge.
        used          <= {DEPTH{1'b0}};
        read_used     <= 1'b0;
        write_pending <= 1'b0;
    end else begin
        write_pending <= write_req;
        if (write_req) begin
            pending_addr <= addr;
            pending_data <= write_data;
        end

        if (write_accept) begin
            mem[pending_addr]  <= pending_data;
            used[pending_addr] <= 1'b1;
        end

        // Forward a newly accepted mark when the registered read and write
        // identify the same address.  This preserves first-write ownership
        // for back-to-back requests with read-before-write block RAM.
        if (write_accept && (addr == pending_addr))
            read_used <= 1'b1;
        else
            read_used <= used[addr];
    end
end

assign read_valid = read_used;
assign read_data  = read_word;

endmodule

`endif
