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

//wire [11:0] ram_data_in = {MATCHV, SPR2_2, SPR1_2, ND2[8:0]};
wire [15:0] q_even;
wire [15:0] q_odd;
// XXX IT'S a 6091 B pin are different than 6091 
// 64 obj EVEN 
sis6091B u_151(
  .clk(clk),
  .wr_cen(~EVNWR2), //DIV_2 /1 //EVNWR@ active write  to check
  .we(~EVNWR2), //30 // &RDCLK
  .clr_n(1'b1),
  .data({SPR2_2, SPR1_2, ODH, MATCHV , VMT[3:0], FDA[10:3]}), //6,7,8,10,12-19,22-25
  .addr({4'b0, DMA2_EA[5:0]}),                                // 62-71
  .rd_cen(~XOBDIR), //73
  //.q({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .q(q_even)//42-56
);
//XXX where goes XOBDIR ? DIY_2 ? check on other sis6901 if it's sometime used
//?

//64 obj ODD 
// store at oa/ea ? 
// addr + vmt ? match y ? + odh + sprite 
// output addr to next chips 

// XXX IT'S A SIS6091B !!! pin are different than SIS6091 ! 
//XXX create a bus arbitrer for output ! 
 
sis6091B u152(
  .clk(clk),
  .wr_cen(~ODDWR2), //~XOBDIR ?
  .we(~ODDWR2),
  .clr_n(1'b1),
  .data({SPR2_2, SPR1_2, ODH, MATCHV , VMT[3:0] ,FDA[10:3]}), 
  .addr({4'b0, DMA2_OA[5:0]}),
  .rd_cen(~XOBDIR),
//  .q1({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .q(q_odd)
);

assign {SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]} =  D1V_2 ? q_even : q_odd; //D1V_2 == V1B == VPOS[0]!

// 256addr for obj ? 
// store at FDA => nd2, obj (graphical data?)
// retrieve at CTA, H[1]
sis6091 u153(
  .clk(clk),

  .wr_cen(~RDCLK), //RAM2VLD ???? 
  .wr_en(~RAM2VLD), //RDCLK ????   //~OIBIDR ? write tor ram ?
  .wr_data({OBJ_DB[15:9] , ND2[8:0]}), 
  .wr_addr({1'b0, FDA[10:2]}),

  .rd_cen(~OIBDIR), //~OIBDIR 
  .rd_addr({1'b0, CTA[8:1], H1}), //8:0 or 9:1 ????? XXX
  .rd_data({OVD[15:0]})
);
//OIBIDR ?

endmodule
