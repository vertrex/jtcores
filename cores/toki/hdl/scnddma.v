// Sheet-15 secondary object-list RAMs (U151/U152) and attribute RAM U153.
// FPGA FDA/tuple/write-phase compensation lives in
// obj_secondary_list_bridge; it is not claimed SIS6091 behavior. The three
// sheet positions and their direct pin-level topology remain visible here;
// U151/U152 storage is isolated behind an explicit synchronous FPGA backend.
// OBJDMA/VCHECK writes matching descriptors first, then MATCHV padding until
// SORT48 has completed the physical 48-transfer list.

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
    input          H1,     // literal SEI0050 H1 (equal to normalized hpos[0])
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
wire [15:0] list_data;
wire        u153_wr_edge;
wire        even_write_req;
wire        odd_write_req;

// Registered FPGA memories need tuple and write-phase compensation which has
// no sheet-15 counterpart. Keep that timing adaptation in one explicit
// helper; the physical U151/U152/U153 topology stays below.
obj_secondary_list_bridge u_list_bridge (
    .clk(clk),
    .FDA(FDA[10:3]),
    .VMT(VMT),
    .ODH(ODH),
    .EVNWR2(EVNWR2),
    .DMA2_EA(DMA2_EA),
    .DMA2_OA(DMA2_OA),
    .ODDWR2(ODDWR2),
    .RAM2VLD(RAM2VLD),
    .RDCLK(RDCLK),
    .SPR2_2(SPR2_2),
    .SPR1_2(SPR1_2),
    .MATCHV(MATCHV),
    .list_data(list_data),
    .even_write_req(even_write_req),
    .odd_write_req(odd_write_req),
    .u153_wr_edge(u153_wr_edge)
);

// Sheet 15 is a direct net contract: U151 receives EVNWR2 and 2DMA_EA, while
// U152 receives ODDWR2 and 2DMA_OA. SORT48 supplies the literal physical
// 16..63 write/read addresses. Do not reroute these buses based on raster
// parity: V1B already exchanges their build and display roles inside SORT48.
//
// Physical U151/U152 are SIS6091B packages with a common address bus; the
// schematic exposes no separate FPGA-style output-register stage, while the
// package's internal read timing remains opaque. Our inferred block RAM adds
// a known registered q boundary, so use a policy-free storage backend and
// keep tuple/write timing in the explicit bridge above. Each physical
// location remains named U151/U152 here; jtframe_ram is the policy-free
// registered-storage backend,
// so a Toki-specific wrapper adds no separate behavior. XOBDIR is the
// physical output-enable path; the internal FPGA consumer remains driven and
// MATCHV in each stored word is the physical NOOBJ source.
jtframe_ram #(
  .DW(16),
  .AW(6),
  .CEN_RD(0)
) u_151 (
  .clk (clk),
  .cen (1'b1),
  .data(list_data),
  .addr(DMA2_EA),
  .we  (even_write_req),
  .q   (q_even)
);

jtframe_ram #(
  .DW(16),
  .AW(6),
  .CEN_RD(0)
) u_152 (
  .clk (clk),
  .cen (1'b1),
  .data(list_data),
  .addr(DMA2_OA),
  .we  (odd_write_req),
  .q   (q_odd)
);

// D1V_2 is sheet-5 U5A Q: V1B sampled on the literal raw-H2 rising edge.
// q_even/q_odd are registered from the live address buses one clock earlier.
wire [15:0] q_sel = D1V_2 ? q_even : q_odd;

// Keep the sheet-15 output-word packing visible. The physical stored MATCHV
// bit drives NOOBJ directly. VCHECK writes a valid MATCHV=0 prefix, then
// MATCHV=1 padding until SORT48 has overwritten all 48 physical locations.
assign {SPR2_3, SPR1_3, ODHREV, NOOBJ, VA[3:0], CTA[8:1]} = q_sel;

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
