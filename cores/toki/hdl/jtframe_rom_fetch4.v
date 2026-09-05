`ifndef JTFRAME_ROM_FETCH4_V
`define JTFRAME_ROM_FETCH4_V

`timescale 1ns/1ps

// Generic four-word requester for an acknowledged JTFrame ROM port.
//
// A PCB mask ROM changes data asynchronously with its address.  A JTFrame ROM
// port can instead keep OK high with the preceding word for one master clock
// after an address change.  This FPGA-only transport primitive holds each
// address until acknowledgement, rejects that one stale interval, and then
// streams four accepted words to its caller.  It contains no cache, raster
// deadline, row storage, ROM-selection policy or game-specific address map.
//
// The four addresses are req_base ORed with zero and WORD1/2/3_MASK.  Callers
// must therefore clear every potentially set mask bit in req_base.
module jtframe_rom_fetch4 #(
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
    input      [AW-1:0]       req_base,
    input      [CTX_W-1:0]    req_ctx,

    output                    rom_cs,
    output     [AW-1:0]       rom_addr,
    input      [DW-1:0]       rom_data,
    input                     rom_ok,

    output                    word_valid,
    output     [1:0]          word_index,
    output     [DW-1:0]       word_data,
    output     [CTX_W-1:0]    word_ctx,
    output                    done,
    output                    busy
);

reg                 busy_r;
reg [AW-1:0]        base_r;
reg [CTX_W-1:0]     ctx_r;
reg [1:0]           word_r;
reg                 stale_guard;

wire req_fire = req_valid && req_ready;

assign req_ready  = !busy_r;
assign rom_cs     = busy_r;
assign busy       = busy_r;
assign word_valid = busy_r && !stale_guard && rom_ok;
assign word_index = word_r;
assign word_data  = rom_data;
assign word_ctx   = ctx_r;
assign done       = word_valid && (word_r == 2'd3);

assign rom_addr = base_r |
                  (word_r == 2'd1 ? WORD1_MASK :
                   word_r == 2'd2 ? WORD2_MASK :
                   word_r == 2'd3 ? WORD3_MASK : {AW{1'b0}});

always @(posedge clk) begin
    if (rst) begin
        busy_r      <= 1'b0;
        base_r      <= {AW{1'b0}};
        ctx_r       <= {CTX_W{1'b0}};
        word_r      <= 2'd0;
        stale_guard <= 1'b0;
    end else if (req_fire) begin
`ifdef SIMULATION
        if ((req_base & (WORD1_MASK | WORD2_MASK | WORD3_MASK)) !=
            {AW{1'b0}})
            $error("jtframe_rom_fetch4: req_base is not mask aligned");
`endif
        busy_r      <= 1'b1;
        base_r      <= req_base;
        ctx_r       <= req_ctx;
        word_r      <= 2'd0;
        stale_guard <= 1'b1;
    end else if (busy_r) begin
        if (stale_guard) begin
            stale_guard <= 1'b0;
        end else if (rom_ok) begin
            if (word_r == 2'd3) begin
                busy_r <= 1'b0;
            end else begin
                word_r      <= word_r + 2'd1;
                stale_guard <= 1'b1;
            end
        end
    end
end

endmodule

`endif
