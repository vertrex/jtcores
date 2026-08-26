/*
* SIS 6091B PIN
*
* See schematic for pin layout.
*
* Provisional fixed behavior for the reduced pin facade formerly used by the
* sheet-15 object lists and retained for custom-IC review/other Seibu boards.
* Toki production U151/U152 now use obj_secondary_list_ram_fpga because their
* synchronous BRAM latency must be explicit outside this IC facade. Sheet-18
* registered line storage, atomic FIND clearing and first-write admission are
* FPGA implementation requirements in the separate sis6091B_atomic backend.
*
* A hidden used/FIND bit is packed with each word here for the external
* contract.  It is not a claim that the die contains a seventeenth SRAM plane.
* The package's physical clear and output-enable truth tables remain
* unrecovered, so this reduced facade deliberately does not invent a
* sequential array-clear mechanism.
*/

module sis6091B #(
    parameter integer ADDR_W = 10
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

localparam integer DEPTH = 1 << ADDR_W;

(* ramstyle = "M10K" *) reg [16:0] mem[0:DEPTH-1];

wire [ADDR_W-1:0] addr_eff = addr[ADDR_W:1];

// The reduced facade receives a normalized, active-high FPGA write phase.
// Exact package-pin-31 polarity/edge behavior has not been captured; any
// Toki-specific phase conversion therefore remains explicit at the caller.
reg wr_cen_d = 1'b0;
wire wr_stb = (wr_cen_d == 1'b0) && (wr_cen == 1'b1);

always @(posedge clk) begin
    wr_cen_d <= wr_cen;
end

always @(posedge clk) begin
    if (wr_stb && we && clr_n)
        mem[addr_eff] <= {1'b1, data};
end

assign find = mem[addr_eff][16];
assign q    = mem[addr_eff][15:0];

endmodule
