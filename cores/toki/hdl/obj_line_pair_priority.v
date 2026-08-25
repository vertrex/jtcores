`ifndef OBJ_LINE_PAIR_PRIORITY_V
`define OBJ_LINE_PAIR_PRIORITY_V

// FPGA facade for resolving the two physical Toki object line-RAM lanes.
//
// Sheet 18 ties the two SIS6091B outputs in each line bank to one shared
// OOD/PRIOR bus.  The opaque devices' simultaneous-FIND behavior is not
// recovered. Software/reference rendering and the board's ascending scan
// require the visible result to give compact-list slot 0 priority over slot 1,
// slot 1 over slot 2, and so on. The working compact scheduler consumes two
// adjacent slots in parallel:
//
//   earlier serializer lane (OBJ2) = slot 2n
//   later   serializer lane (OBJ1) = slot 2n+1
//
// Store that six-bit chronological tag in the otherwise unused upper bits of
// each FPGA line-RAM word.  When both physical lanes report FIND at one X,
// selecting the lower tag reproduces global list order across pair boundaries.
// This helper adds no sprite scheduling or storage; it only tags the existing
// 16 write beats and resolves two already-read words.
module obj_line_pair_priority #(
    parameter integer DATA_W = 10,
    parameter integer TAG_W  = 6
)(
    input  wire                    clk,
    input  wire                    clear_n,
    input  wire                    write_clock,
    input  wire                    write_enable_n,

    input  wire                    earlier_find,
    input  wire                    later_find,
    input  wire [TAG_W+DATA_W-1:0] earlier_word,
    input  wire [TAG_W+DATA_W-1:0] later_word,

    output wire [TAG_W-1:0]        earlier_write_tag,
    output wire [TAG_W-1:0]        later_write_tag,
    output reg                     selected_find,
    output reg  [DATA_W-1:0]       selected_data
);

localparam integer PAIR_W = TAG_W - 1;

reg clear_n_d = 1'b1;
reg write_clock_d = 1'b0;
reg [3:0] pixel_index = 4'd0;
reg [PAIR_W-1:0] pair_order = {PAIR_W{1'b0}};

wire clear_cmd = clear_n_d && !clear_n;
wire write_stb = !write_clock_d && write_clock;
wire pair_write_stb = write_stb && !write_enable_n;

assign earlier_write_tag = {pair_order, 1'b0};
assign later_write_tag   = {pair_order, 1'b1};

always @(posedge clk) begin
    clear_n_d     <= clear_n;
    write_clock_d <= write_clock;

    if (clear_cmd) begin
        pair_order <= {PAIR_W{1'b0}};
        pixel_index <= 4'd0;
    end else if (pair_write_stb) begin
        // Count the physical write beats rather than WREN edges. Dense pair
        // handoffs may leave only a very short inactive gap, while every
        // admitted descriptor pair still owns exactly sixteen N6M beats.
        if (pixel_index == 4'd15) begin
            pixel_index <= 4'd0;
            pair_order <= pair_order + {{(PAIR_W-1){1'b0}}, 1'b1};
        end else begin
            pixel_index <= pixel_index + 4'd1;
        end
    end
end

always @(*) begin
    selected_find = earlier_find || later_find;
    selected_data = {DATA_W{1'b1}};

    if (earlier_find && later_find) begin
        if (earlier_word[TAG_W+DATA_W-1:DATA_W] <=
            later_word[TAG_W+DATA_W-1:DATA_W])
            selected_data = earlier_word[DATA_W-1:0];
        else
            selected_data = later_word[DATA_W-1:0];
    end else if (earlier_find) begin
        selected_data = earlier_word[DATA_W-1:0];
    end else if (later_find) begin
        selected_data = later_word[DATA_W-1:0];
    end
end

// synthesis translate_off
always @(posedge clk) begin
    // SORT48 admits at most 48 descriptors (24 pairs) per line. Reaching a
    // 25th pair means the tag cadence has diverged from the list contract.
    if (pair_write_stb && (pair_order >= 5'd24))
        $display("WARNING: obj_line_pair_priority exceeded 24 pairs");
end
// synthesis translate_on

endmodule

`endif
