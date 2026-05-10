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
    input          H1,     //hpos[0]
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
// XXX IT'S a 6091 B pin are different than 6091
// 64 obj EVEN
sis6091B #(
  .ADDR_W(6),
  .GLOBAL_USED_CLEAR(1'b1),
  .WR_CEN_ACTIVE_LOW(1'b1)
) u_151(
  .clk(clk),
  .wr_cen(EVNWR2), // EVNWR2 active-low; sis6091B writes when wr_cen==0
  .we(1'b1), //30 // &RDCLK
  .clr_n(1'b1),
  .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}), //6,7,8,10,12-19,22-25
  .addr({4'b0, DMA2_EA[5:0]}),                                // 62-71
  .rd_cen(~XOBDIR), //73
  //.q({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_even),
  .q(q_even)//42-56
);

//64 obj ODD
sis6091B #(
  .ADDR_W(6),
  .GLOBAL_USED_CLEAR(1'b1),
  .WR_CEN_ACTIVE_LOW(1'b1)
) u_152(
  .clk(clk),
  .wr_cen(ODDWR2), // ODDWR2 active-low; sis6091B writes when wr_cen==0
  .we(1'b1),
  .clr_n(1'b1),
  .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}),
  .addr({4'b0, DMA2_OA[5:0]}),
  .rd_cen(~XOBDIR),
//  .q1({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_odd),
  .q(q_odd)
);

// D1V_2 == V1B == VPOS[0]
wire [15:0] q_sel = D1V_2 ? q_even : q_odd;
wire q_noobj_unused;
assign {SPR2_3,SPR1_3, ODHREV, q_noobj_unused, VA[3:0], CTA[8:1]} = q_sel;

// Keep per-line valid slot bitmaps for each ping-pong bank.
// This avoids stale "object present" on unwritten slots while preserving
// the hardware address mapping used on DMA2_EA/DMA2_OA.
reg d1v2_d   = 1'b0;
reg evnwr2_d = 1'b1;
reg oddwr2_d = 1'b1;
reg [63:0] even_valid = 64'b0;
reg [63:0] odd_valid  = 64'b0;

wire d1v2_rise  = (d1v2_d == 1'b0) && (D1V_2  == 1'b1);
wire d1v2_fall  = (d1v2_d == 1'b1) && (D1V_2  == 1'b0);
wire evnwr2_fall = (evnwr2_d == 1'b1) && (EVNWR2 == 1'b0);
wire oddwr2_fall = (oddwr2_d == 1'b1) && (ODDWR2 == 1'b0);

always @(posedge clk) begin
    d1v2_d   <= D1V_2;
    evnwr2_d <= EVNWR2;
    oddwr2_d <= ODDWR2;

    // sort48 phase:
    // - V1B=1 writes ODD slots (DMA2_OA=wr_ptr), reads EVEN slots
    // - V1B=0 writes EVEN slots (DMA2_EA=wr_ptr), reads ODD slots
    if (d1v2_rise)
        odd_valid <= 64'b0;
    else if (oddwr2_fall)
        odd_valid[DMA2_OA] <= 1'b1;

    if (d1v2_fall)
        even_valid <= 64'b0;
    else if (evnwr2_fall)
        even_valid[DMA2_EA] <= 1'b1;
end

wire slot_valid = D1V_2 ? even_valid[DMA2_EA] : odd_valid[DMA2_OA];
assign NOOBJ = ~slot_valid;

// 256addr for obj ?
// store at FDA => nd2, obj (graphical data?)
// retrieve at CTA, H[1]
sis6091 u_153(
  .clk(clk),

  .wr_cen(~RDCLK), //RAM2VLD ????
  .wr_en(~RAM2VLD), //RDCLK ????   //~OIBIDR ? write tor ram ?
  .wr_data({OBJ_DB[15:9] , ND2[8:0]}),
  .wr_addr({1'b0, FDA[10:2]}),

  .rd_cen(OIBDIR), //OIBDIR always up except 1 time per frame during dma
  .rd_addr({1'b0, CTA[8:1], H1}),
  .rd_data({OVD[15:0]}) //XXX THIS WHERE DATA to create address is send is it blocked or have wrong data ?
);
//OIBIDR ?

endmodule
