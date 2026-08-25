// Sheet-16 object serializers, attribute latches and PLD29 priority logic.
// This is the live serializer backend feeding the sheet-18 LINEBUF path.
// Get pixel data, palette and object priority and serialize OBJ1/OBJ2.

module OBJPS #(
    // The physical PCB path uses the U163/U169 direction Q outputs directly.
    // Set this only when an acknowledged external-ROM replay facade must put
    // a complete row on PD before those attribute registers can capture it.
    parameter FPGA_ROM_REPLAY = 0
)(
    input        clk,
    input        rst,
    input        OBJ_P6M,     // positive 6 MHz object clock enable
    input        T3F,         // SEI0050 timing phase
    input        D1V_7,       // raw U518 line-bank phase
    input [15:0] PD,          // object ROM pixel data
    input        OBJ_N6M,     // negative 6 MHz object clock enable
    input        FIRST_LD,    // active-low PLD22 U163 load clock
    input        SECND_LD,    // active-low PLD22 U165/U169 load clock
    input        OPSREV,      // effective object serializer direction
    // FPGA-only cached-row direction tag. It is not a sheet-16 signal and is
    // ignored unless FPGA_ROM_REPLAY is set.
    input        FPGA_REPLAY_REV,
    input  [3:0] OBJCOL,      // OBJ palette color (obj1/2 [7:4])
    input        OSP1,        // object priority bit 0
    input        OSP2,        // object priority bit 1
    input        NOOBJ_CT2,   // CT2-qualified descriptor presence (1=valid)
    input        HREV,        // reverse horizontal from dipswitch
    input        HD,          // SEI0050 pin 27 active-low horizontal drive
    input        E1FIND,      //even obj 1 find 
    input        E2FIND,      //even obj 2 find 
    input        O1FIND,      //odd  obj 1 find 
    input        O2FIND,      //odd obj 2 find 
    input        OBJMASK,     //obj mask
    // outputs
    output       D1V_7P,
    output       ND1V_7P,
    output [9:0] OBJ1,        // {priority[1:0], palette[3:0], pixel[3:0]}
    output       OBJON,       //obj on
    output [9:0] OBJ2,        // {priority[1:0], palette[3:0], pixel[3:0]}
    output       DLHD,        // U168 serialized marker feeding PLD24/ILD2

    // FPGA active-high "not driven" sidebands replacing U164A/U164B Z buses.
    output       OBJ1_Z,
    output       OBJ2_Z
);

wire        LS175_Q1;
wire        NC0; 
wire [1:0]  NC1;
wire        NC2;
wire        T3F_2;

// The sheet-16 LS273/LS174 parts are clocked by active-low decoded pulses,
// not enabled for the whole low level.  In the FPGA all TTL parts share the
// 48 MHz master clock, so this implementation converts the low-to-high end
// of each decoded clock into one master-clock enable.  Sampling at the end of
// the low phase also gives the synchronous U153 RAM output time to settle.
// Keeping every transfer on the same edge preserves real TTL old-Q ordering:
// U165/U169 see the value which U163/LINECUNT held before that edge.
reg first_ld_d;
reg secnd_ld_d;

always @(posedge clk) begin
    if (rst) begin
        first_ld_d <= 1'b1;
        secnd_ld_d <= 1'b1;
    end else begin
        first_ld_d <= FIRST_LD;
        secnd_ld_d <= SECND_LD;
    end
end

wire first_ld_cen = FIRST_LD && !first_ld_d;
wire secnd_ld_cen = SECND_LD && !secnd_ld_d;

// U161 10C, 74LS175.
LS175 u161(
    .CLK(clk),
    .CLR_n(1'b1),
    .CEN(OBJ_P6M),
    .D({1'b0, D1V_7 ,LS175_Q1, T3F}),
    .Q({NC0, D1V_7P, T3F_2, LS175_Q1}),
    .Qn({NC2, ND1V_7P, NC1[1:0]})
);

// U163 14C, 74LS273.
wire [7:0] u163_q;

LS273 u163(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(first_ld_cen),
    .D({NOOBJ_CT2, OSP2, OSP1, OBJCOL[3:0], OPSREV}),
    .Q(u163_q[7:0])
);

// U165 13C, 74LS174.
wire [5:0] obj1_attr_raw;
wire       PLD_O19;

LS174 u165(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(secnd_ld_cen),
    .D(u163_q[6:1]),
    .Q(obj1_attr_raw)
);

// U165 drives the delayed physical lane directly, as wired on sheet 16.
reg       obj1_drive_l;
reg       obj1_drive_2l;

always @(posedge clk) begin
    if (rst) begin
        obj1_drive_l  <= 1'b0;
        obj1_drive_2l <= 1'b0;
    end else if (OBJ_N6M) begin
        // U164/PLD29 qualifies the nibble before U166's two LS273 halves.
        // Carry an explicit valid bit through the same two N6M stages; a
        // direct OBJ1_Z gate at the line RAM suppresses the final two pixels
        // when the following delayed-lane descriptor is absent.
        obj1_drive_l  <= ~PLD_O19;
        obj1_drive_2l <= obj1_drive_l;
    end
end

assign OBJ1[9:4] = obj1_attr_raw;

// U169 14A, 74LS273.
wire pld_i9;
wire sei100_2_38;

LS273 u169(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(secnd_ld_cen),
    .D({NOOBJ_CT2, OSP2, OSP1, OBJCOL[3:0], OPSREV}),
    .Q({pld_i9, OBJ2[9:4], sei100_2_38 })
);

// Sheet 16 routes the FIRST-captured U163 direction to delayed U162 and the
// SECND-captured U169 direction to direct U168. Keep that literal path as the
// default reusable model.
//
// Toki's FPGA object ROM is acknowledged SDRAM behind a complete-row cache.
// An isolated row must be visible before FIRST/SECND, just as an asynchronous
// PCB ROM already is, so its physical direction Q is not yet available. A
// direction change on the behavioral serializer after two shifts also selects
// its zero-filled opposite end. With FPGA_ROM_REPLAY set, the two small
// holders bind the cached row's own direction tag to its corresponding load.
// This is an FPGA transport/propagation adapter, not a recovered extra latch
// in SEI0010BU; U163 and U169 remain implemented and capture physical OPSREV.
wire obj1_replay_reverse;
wire obj2_replay_reverse;

generate
if (FPGA_ROM_REPLAY) begin : gen_fpga_rom_replay_direction
    obj_load_aligned_reverse obj1_reverse_phase_u(
        .clk(clk),
        .rst(rst),
        .cen(OBJ_N6M),
        .load(T3F_2),
        .reverse_in(FPGA_REPLAY_REV),
        .reverse_out(obj1_replay_reverse)
    );

    obj_load_aligned_reverse obj2_reverse_phase_u(
        .clk(clk),
        .rst(rst),
        .cen(OBJ_N6M),
        .load(T3F),
        .reverse_in(FPGA_REPLAY_REV),
        .reverse_out(obj2_replay_reverse)
    );
end else begin : gen_physical_rom_direction
    assign obj1_replay_reverse = u163_q[0];
    assign obj2_replay_reverse = sei100_2_38;
end
endgenerate

wire obj1_serializer_reverse = obj1_replay_reverse;
wire obj2_serializer_reverse = obj2_replay_reverse;

// U162 20A, SEI0010BU.
wire [3:0] OBJ1_COLOR;
wire [1:0] NC3;

sei0010bu u162_sei10(
    .clk(clk),
    .rst(rst),
    .cen(OBJ_N6M),
    .load(T3F_2),
    .rev(obj1_serializer_reverse),
    .rom_data({8'b0, PD[15:0]}),
    .color({NC3[1:0], OBJ1_COLOR[3:0]})
);

// Sheet/PLD22 old-Q ordering assigns the H2=1 descriptor to this delayed
// serializer. FIRST_LD and CTLT2 coincide at H low nibble 5, so U163 samples
// the preceding H2=1 U175 value; SECND_LD transfers it through U165 at H=7.

// U164 74LS244. Verilog cannot carry the physical high-impedance nibble
// through U166, so disabled data is represented as zero here and a separate
// OBJ1_Z sideband tells the FPGA line-RAM facade whether it was driven.
wire [3:0] OBJ1_COLOR_EN;
assign OBJ1_COLOR_EN[3:0] = ~PLD_O19 ? OBJ1_COLOR[3:0] : 4'b0;

// U164 qualification precedes both U166 halves on the PCB. Align the explicit
// FPGA drive-valid sideband with the U166 output instead of gating LINEBUF
// directly from the earlier PLD29 value.
assign OBJ1_Z = ~obj1_drive_2l;

wire [3:0] OBJ1_COLOR_SHIFT;
// U166 13A, 74LS273.
LS273 u166(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(OBJ_N6M),
    .D({OBJ1_COLOR_SHIFT[3:0] , OBJ1_COLOR_EN[3:0]}),
    .Q({OBJ1[3:0], OBJ1_COLOR_SHIFT[3:0]})
);

wire NC;

wire PLD_O18;
wire HREV_HD;
wire NHREV_HD;
wire OBJON_RAW;

// U167 18C, PLD29.
PLD29 u_pld29(
    .HREV(HREV),
    .HD(HD),
    // Sheet 16 labels U167 pin 3 as physical D1V_7P. The current validated
    // FPGA line-store contract instead displays EVEN for D1V_7P=0, while the
    // exact PLD29 equation selects ODD FINDs when its pin 3 is low. Feed the
    // complement so PLD29 and LINEBUF select the same bank. This is an explicit
    // coordinated FPGA exception, not literal recovered PCB wiring. Restoring
    // direct D1V_7P requires migrating SEI0060 EA/OA roles, LINEBUF parity,
    // WREN and clear routing together after their physical roles are captured.
    .D1V_7P(ND1V_7P),
    .E1FIND(E1FIND),
    .E2FIND(E2FIND),
    .O1FIND(O1FIND),
    .O2FIND(O2FIND),
    .OBJMASK(OBJMASK),
    .NOOBJ_CT2_LATCH1(u163_q[7]),
    .NOOBJ_CT2_LATCH2(pld_i9),

    .HREV_HD(HREV_HD), 
    .NHREV_HD(NHREV_HD), 
    .OBJON(OBJON_RAW),
    .o16_n(NC),     // PLD29 pin 16 is unused on sheet 16
    // OBJMASK => cpu/addrs.v  if (MASKS~ ) OBJMASK <=MDB[2] 
    // NOOBJCT_2 => sg0140_ohmax
    .MASK_NOOBJ_2(PLD_O18),  //~( ~OBJMASK & NOOBJ_CT2_LATCH2 );
    .MASK_NOOBJ_1(PLD_O19)   //~( ~OBJMASK & NOOBJ_CT2_LATCH1 );
);

// PLD29 already returns the physical pin voltage. Although jedutil prints
// the macrocell equation as /o15, the complemented sum-of-products in
// pld29.v evaluates high for a FIND in the selected bank. Do not invert it a
// second time here; PROM27 consumes this active-high pin directly.
assign OBJON = OBJON_RAW;


wire       NC4;
wire [3:0] OBJ2_COLOR;

// U168 22A, SEI0010BU.
sei0010bu u168_sei10(
    .clk(clk),
    .rst(rst),
    .cen(OBJ_N6M),
    .load(T3F),
    .rev(obj2_serializer_reverse),
    // Sheet 16 routes PLD29 outputs 12/13 into U168's two extra input planes.
    // Their exact mapping onto this behavioral model's rom_data[23:20] bits
    // is not recovered. Keep this trace-validated order: serialized DLHD
    // reproduces the captured ILD2-low interval for either HREV polarity.
    .rom_data({1'b1, HREV_HD, NHREV_HD, 1'b1, 4'b1, PD[15:0]}),
    .color({DLHD, NC4, OBJ2_COLOR[3:0]})
);

// U169 samples the preceding H2=0 U175 value when SECND_LD and CTLT2 coincide
// at H low nibble 7, making direct U168 the H2=0 lane. Its pixels lead U162 by
// two OBJ_N6M beats; the shared line-RAM write window relies on matching X and
// tri-state phases, not on duplicating one replay row into both serializers.

// U164B 18A, 74LS244, represented by data plus explicit drive-valid as above.
assign OBJ2[3:0] = ~PLD_O18 ? OBJ2_COLOR[3:0] : 4'h0;
assign OBJ2_Z = ~PLD_O18 ? 1'b0 : 1'b1;

endmodule 
