// Sheet-15 secondary object-list RAMs (U151/U152) and attribute RAM U153.
// FPGA FDA/tuple/write-phase compensation and retentive-list validity live in
// obj_secondary_list_bridge; they are not claimed SIS6091 internals. The three
// schematic RAM instances and their direct pin-level topology remain here.
// Secondary DMA triggered by objdma when sprite match

//Write sprite info to one line
//or the other ,
//when one is read alternatively via sg0140 / objdma
//

module SCNDDMA(
    input          clk,
    input   [10:2] FDA,     //F data addr
    input    [3:0] VMT,     //?
    input          ODH,     // ?
    input          EVNWR2,  //Even Wren 2
    input    [5:0] DMA2_EA, //2DMA even addr
    input          XOBDIR,  //x object dir
    input          D1V_2,
    input    [5:0] DMA2_OA, //2DMA object addr
    input          ODDWR2,  //Odd Wren 2
    input          RAM2VLD, // Ram 2
    input          RDCLK,   //R data clock
    input          H1,     // normalized JTFrame hpos[0] compatibility phase
    input          OIBDIR, // Object IB direction
    input    [8:0] ND2,
    input   [15:9] OBJ_DB,//Object Data bus
    input          SPR2_2, //Spr2 2
    input          SPR1_2, //spr1 2
    input          MATCHV,
    //output
    output  [15:0] OVD,   //Object Valida? data
    output   [3:0] VA,    //V? addr
    output         NOOBJ,  //No Object
    output         ODHREV, //Object Data H reverse
    output         SPR1_3, //Sprite 1 _3
    output         SPR2_3  //Sprite 2 _3 ?
);

wire [8:1] CTA;
wire [15:0] q_even;
wire [15:0] q_odd;
wire        find_even;
wire        find_odd;
wire [15:0] list_data;
wire        slot_valid;
wire        u153_wr_edge;
// The reduced SIS6091B FPGA facade accepts a normalized rising write phase.
// Sheet 15 connects the active-low WR2 nets directly to bubbled package pin
// 31; invert them here solely to preserve the tested falling-edge write event.
// This is not a claim about the unrecovered physical pin-31 truth table.
wire        u151_wr_phase = ~EVNWR2;
wire        u152_wr_phase = ~ODDWR2;

// Registered/retentive FPGA memories need tuple, epoch and write-phase
// compensation which has no sheet-15 counterpart. Keep all of that policy in
// one explicit helper; the physical U151/U152/U153 topology stays below.
obj_secondary_list_bridge u_list_bridge (
    .clk(clk),
    .FDA(FDA[10:3]),
    .VMT(VMT),
    .ODH(ODH),
    .EVNWR2(EVNWR2),
    .DMA2_EA(DMA2_EA),
    .D1V_2(D1V_2),
    .DMA2_OA(DMA2_OA),
    .ODDWR2(ODDWR2),
    .RAM2VLD(RAM2VLD),
    .RDCLK(RDCLK),
    .SPR2_2(SPR2_2),
    .SPR1_2(SPR1_2),
    .MATCHV(MATCHV),
    .list_data(list_data),
    .slot_valid(slot_valid),
    .u153_wr_edge(u153_wr_edge)
);

// Sheet 15 is a direct net contract: U151 receives EVNWR2 and 2DMA_EA,
// while U152 receives ODDWR2 and 2DMA_OA. SORT48 places its physical 16..63
// write pointer on the corresponding bus and the physical display slot on
// the opposite bus. Do not reroute addresses based on raster parity.

// XXX IT'S a 6091 B pin are different than 6091
// 64 obj EVEN
sis6091B #(
  .ADDR_W(6)
) u_151(
  .clk(clk),
  // PCB connection before FPGA write-phase normalization:
  // .wr_cen(EVNWR2), // active-low WR2 on sheet-15 package pin 31
  .wr_cen(u151_wr_phase),
  .we(1'b1), //30 // &RDCLK
  .clr_n(1'b1),
  // PCB tuple before registered-U141/FDA timing compensation:
  // .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}),
  .data(list_data), //6,7,8,10,12-19,22-25
  .addr({4'b0, DMA2_EA[5:0]}),                           // 62-71
  .rd_cen(~XOBDIR), //73
  //.q({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_even),
  .q(q_even)//42-56
);

//64 obj ODD
sis6091B #(
  .ADDR_W(6)
) u_152(
  .clk(clk),
  // PCB connection before FPGA write-phase normalization:
  // .wr_cen(ODDWR2), // active-low WR2 on sheet-15 package pin 31
  .wr_cen(u152_wr_phase),
  .we(1'b1),
  .clr_n(1'b1),
  // PCB tuple before registered-U141/FDA timing compensation:
  // .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}),
  .data(list_data),
  .addr({4'b0, DMA2_OA[5:0]}),
  .rd_cen(~XOBDIR),
//  .q1({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_odd),
  .q(q_odd)
);

// D1V_2 is the U5A-compatible bank phase. video.v currently samples V1B with
// a normalized hpos compatibility event, not with the literal raw-H2 edge.
wire [15:0] q_sel = D1V_2 ? q_even : q_odd;

// Keep the sheet-15 output-word packing visible. The physical stored MATCHV
// bit would drive NOOBJ, but its sparse-list behavior has not been recovered;
// the FPGA validity epoch therefore overrides that bit for now. Valid slots
// force NOOBJ low; invalid slots assert only NOOBJ and clear every other field.
assign {SPR2_3, SPR1_3, ODHREV, NOOBJ, VA[3:0], CTA[8:1]} =
    slot_valid ? {q_sel[15:13], 1'b0, q_sel[11:0]} :
                 {3'b000,       1'b1, 12'b0};

// U153 uses 512x16 of its address space: write by FDA[10:2], then retrieve the
// selected descriptor as {CTA[8:1], H1}. The unused upper address pin is low.
sis6091 u_153(
  .clk(clk),

  // PCB connection before conversion to one inferred-RAM write event:
  // .wr_cen(~RDCLK),
  .wr_cen(u153_wr_edge), // FPGA phase adapter for physical ~RDCLK
  .wr_en(~RAM2VLD), //RDCLK ????   //~OIBIDR ? write tor ram ?
  .wr_data({OBJ_DB[15:9] , ND2[8:0]}),
  .wr_addr({1'b0, FDA[10:2]}),

  .rd_cen(OIBDIR), //OIBDIR always up except 1 time per frame during dma
  .rd_addr({1'b0, CTA[8:1], H1}),
  .rd_data({OVD[15:0]}) //XXX THIS WHERE DATA to create address is send is it blocked or have wrong data ?
);
//OIBIDR ?

endmodule
