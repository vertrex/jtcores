`ifndef OBJ_ROM_ROW_BRIDGE_V
`define OBJ_ROM_ROW_BRIDGE_V

// FPGA transport bridge for one four-word object-ROM row.
//
// The Toki PCB connects local asynchronous mask ROMs directly to the object
// serializers.  JTFRAME presents the same data through an acknowledged SDRAM
// port whose OK signal may remain high with the previous word for one master
// clock after an address change.  This module contains only that non-PCB
// transport behavior: it holds a request, suppresses the stale OK interval,
// and atomically returns four 16-bit words plus an opaque caller context.
//
// Raster/list scheduling, ROM-chip selection, palette/X attributes, replay
// ownership, line-buffer priority and cache policy deliberately remain in the
// caller.  Keeping those concerns out makes this bridge reusable and prevents
// SDRAM adaptation from becoming the definition of the original custom ICs.
module obj_rom_row_bridge #(
    parameter AW = 18,
    parameter DW = 16,
    parameter CTX_W = 1,
    parameter [AW-1:0] WORD1_MASK = {{(AW-1){1'b0}}, 1'b1},
    parameter [AW-1:0] WORD2_MASK = {{(AW-6){1'b0}}, 6'b100000},
    parameter [AW-1:0] WORD3_MASK = {{(AW-6){1'b0}}, 6'b100001}
)(
    input                     clk,
    input                     rst,

    input                     req_valid,
    output                    req_ready,
    input      [AW-1:0]        req_base,
    input      [CTX_W-1:0]     req_ctx,

    output                    rom_cs,
    output     [AW-1:0]        rom_addr,
    input      [DW-1:0]        rom_data,
    input                     rom_ok,

    // row_done is a combinational acceptance enable during the final valid
    // word cycle. The caller captures row_data/row_ctx on its closing edge;
    // responses are never backpressured.
    output                    row_done,
    output     [(4*DW)-1:0]    row_data,
    output     [CTX_W-1:0]     row_ctx,
    output                    busy
);

reg                  busy_r;
reg [AW-1:0]         base_r;
reg [CTX_W-1:0]      ctx_r;
reg [1:0]            word_r;
reg                  stale_guard;
reg [DW-1:0]         word_0;
reg [DW-1:0]         word_1;
reg [DW-1:0]         word_2;

wire req_fire = req_valid && req_ready;
wire accept_word = busy_r && !stale_guard && rom_ok;

// Waveform-compatible observation alias. JTFrame's acknowledged ROM can
// expose the preceding word for exactly the first master clock after each
// address change, so the implemented state is one bit rather than a generic
// eight-bit delay counter.
`ifdef SIMULATION
wire [7:0] settle_r = {7'b0, stale_guard};
`endif

assign req_ready = !busy_r;
assign busy      = busy_r;
assign rom_cs    = busy_r;
assign row_ctx   = ctx_r;
assign row_done  = accept_word && (word_r == 2'd3);
assign row_data  = {rom_data, word_2, word_1, word_0};

assign rom_addr = base_r |
                  (word_r == 2'd1 ? WORD1_MASK :
                   word_r == 2'd2 ? WORD2_MASK :
                   word_r == 2'd3 ? WORD3_MASK : {AW{1'b0}});

always @(posedge clk) begin
    if (rst) begin
        busy_r   <= 1'b0;
        base_r   <= {AW{1'b0}};
        ctx_r    <= {CTX_W{1'b0}};
        word_r   <= 2'd0;
        stale_guard <= 1'b0;
        word_0   <= {DW{1'b1}};
        word_1   <= {DW{1'b1}};
        word_2   <= {DW{1'b1}};
    end else if (req_fire) begin
`ifdef SIMULATION
        // The word addresses are formed by ORing masks onto an aligned row
        // base. Catch misuse at the reusable boundary rather than silently
        // addressing the wrong word; the Toki caller clears bits 5 and 0.
        if (req_base[5] || req_base[0])
            $error("obj_rom_row_bridge: req_base is not row aligned");
`endif
        busy_r   <= 1'b1;
        base_r   <= req_base;
        ctx_r    <= req_ctx;
        word_r   <= 2'd0;
        stale_guard <= 1'b1;
    end else if (busy_r) begin
        if (stale_guard) begin
            stale_guard <= 1'b0;
        end else if (rom_ok) begin
            case (word_r)
                2'd0: word_0 <= rom_data;
                2'd1: word_1 <= rom_data;
                2'd2: word_2 <= rom_data;
                default: busy_r <= 1'b0;
            endcase

            if (word_r != 2'd3) begin
                word_r      <= word_r + 2'd1;
                stale_guard <= 1'b1;
            end
        end
    end
end

endmodule

`endif
