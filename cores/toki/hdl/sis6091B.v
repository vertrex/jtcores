/*
* SIS 6091B PIN
*
* See schematic for pin layout.
*
* BRAM-friendly model. The `used` flag is packed as bit 16 of a 17-bit mem
* word (was a separate reg array with combinational read, which forced flop
* inference and ate ~5600 LEs per instance on Pocket — over the 1848-LAB budget).
*
* Both the line-buffer (LINEBUF) and sprite-list (SCNDDMA) instances use a
* single synchronous read model — no combinational pass-through. The line
* buffer's pixel-select happens in the next clock anyway (see linebuf.v's
* `if (D1V_7P)` block), so one cycle of extra read latency is harmless.
*
* Bulk-clear sweep: when clr_n falls low, a dedicated counter walks
* 256 addresses (covering the visible LINEBUF X range) and clears each
* slot. Sweep stops at CLR_END or when clr_n rises (HBL ends). Normal
* wr_stb writes take priority over sweep so sprite writes landing
* during any HBL-overhang still commit. User-tested: visible vertical
* trail reduced while sprite still renders.
*
* SCNDDMA instances tie clr_n to 1'b1 so the sweep never triggers there —
* their behavior is unchanged.
*/

module sis6091B #(
    parameter CLEAR_VALUE       = 4'h0,
    parameter ADDR_W            = 10,
    parameter GLOBAL_USED_CLEAR = 1'b0,   // kept for API compat; ignored
    parameter WR_CEN_ACTIVE_LOW = 1'b0,
    parameter WRITE_CAPTURED    = 1'b0,   // kept for API compat; ignored
    parameter READ_CAPTURED     = 1'b1    // kept for API compat; ignored
)
(
    input          clk,
    input          wr_cen,
    input          we,
    input   [15:0] data,
    input   [10:1] addr,
    input          rd_cen,
    input          clr_n,
    output         find,
    output  [15:0] q
);

(* ramstyle = "M10K" *) reg [16:0] mem[0:(2**ADDR_W)-1];
reg [16:0] rd_word = 17'h0;

wire [ADDR_W-1:0] addr_eff = addr[ADDR_W:1];
wire wr_active = WR_CEN_ACTIVE_LOW ? ~wr_cen : wr_cen;

// Edge detector on wr_active — original sis6091B was edge-triggered on the
// write strobe. Single-flop implementation.
reg wr_active_d = 1'b0;
wire wr_stb = (wr_active_d == 1'b0) && (wr_active == 1'b1);

// Bulk-clear sweep state. Starts on clr_n falling edge, walks 256 slots
// (visible LINEBUF range), self-stops at CLR_END or when clr_n rises.
reg clr_n_d = 1'b1;
wire clr_n_fall = (clr_n_d == 1'b1) && (clr_n == 1'b0);

reg [ADDR_W-1:0] clr_cnt = {(ADDR_W){1'b0}};
reg clr_active = 1'b0;
// Cover the full 9-bit visible LINEBUF range (512 slots). Sprite writes
// during wr_cnt free-run can land anywhere in 0..511, so leaving the
// upper half un-swept lets stale `find=1` bits persist there — user
// reported trail pixels at columns 5 and 13 which are aliases of such
// stale slots when displayed via bit-0 of a larger address.
localparam [ADDR_W-1:0] CLR_END = {1'b0, {(ADDR_W-1){1'b1}}};  // 512 slots for ADDR_W=10

always @(posedge clk) begin
    wr_active_d <= wr_active;
    clr_n_d     <= clr_n;

    // Start sweep on clr_n falling edge, when currently idle
    if (clr_n_fall && !clr_active) begin
        clr_cnt    <= {(ADDR_W){1'b0}};
        clr_active <= 1'b1;
    end else if (clr_active) begin
        if (clr_n || (clr_cnt == CLR_END)) begin
            clr_active <= 1'b0;
        end else begin
            clr_cnt <= clr_cnt + 1'b1;
        end
    end

    // Write priority: normal wr_stb write > sweep clear.
    if (wr_stb) begin
        if (!clr_n)
            mem[addr_eff] <= 17'h00000;
        else if (we)
            mem[addr_eff] <= {1'b1, data};
    end else if (clr_active) begin
        mem[clr_cnt] <= 17'h00000;
    end

    if (rd_cen)
        rd_word <= mem[addr_eff];
end

assign find = rd_word[16];
assign q    = rd_word[15:0];

endmodule
