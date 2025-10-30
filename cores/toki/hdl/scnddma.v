module SCNDDMA(
    input          clk,
    input   [10:2] FDA,
    input    [3:0] VMT,
    input          ODH,
    input          EVNMR2,
    input    [5:0] DMA2_EA,
    input          XOBDIR,
    input          DIY_2,
    input    [5:0] DMA2_OA,
    input          ODDWR2,
    input          RAM2VLD,
    input          RDCLK,
    input          H_1,
    input    [9:1] CTA,
    input          OIBDIR,
    input    [8:0] ND2,
    input   [15:9] OBJ_DB,
    //output 
    output  [15:0] OVD,
    output   [3:0] VA,
    output         NOOBJ,
    output         ODHREY, //ODHREV ??
    output         SPR1_3,
    output         SPR2_3
);

// 64 obj EVEN 
sis6091 u_151(
  .clk0(clk),
  .cen0(EVNMR2), //31
  .data0({SPR2_2, SPR1_2, ODH, MATCHV , VMT[3:0] ,FDA[10:3]}), //6,7,8,10,12-19,22-25
  .addr0({4'b0, DMA2_EA[5:0]}),//62-71
  .we0({1'b0, 1'b0}), //30
  .q0(),

  .clk1(clk),
  .cen1(), //73
  .data1({SPR2_3,SPR1_3, ODHREY, NOOBJ,VA[3:0], CTA[8:1]}), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
  .q1() //42-56
);
//XXX where goes XOBDIR ? DIY_2 ? check on other sis6901 if it's sometime used
//?

//64 obj ODD 
// store at oa/ea ? 
// addr + vmt ? match y ? + odh + sprite 
// output addr to next chips 
sis6091 u152(
  .clk0(clk),
  .cen0(ODDWR2),
  .data0({SPR2_2, SPR1_2, ODH, MATCHV , VMT[3:0] ,FDA[10:3]}), 
  .addr0({4'b0, DMA2_OA[5:0]}),
  .we0({1'b0, 1'b0}),
  .q0(),

  .clk1(clk),
  .cen1(),
  .data1({SPR2_3,SPR1_3, ODHREY, NOOBJ,VA[3:0], CTA[8:1]}),
  .addr1(),
  .we1({1'b0, 1'b0}), //xobdir diy i2 ?  //read /write xobdir ?
  .q1()
);


// 512 addr for obj ? 
// store at FDA => nd2, obj (graphical data?)
// retrieve at CTA, H[1]
sis6091 u153(
  .clk0(clk),
  .cen0(RDCLK),
  .data0({OBJ_DB[15:9] , ND2[8:0]}), 
  .addr0({1'b0, FDA[10:2]}),
  .we0({RAM2VLD, RAM2VLD}),
  .q0(),

  .clk1(clk),
  .cen1(OIBDIR), //OIBIDR ????
  .data1({OVD[15:0]}),
  .addr1({CTA[8:0], H_1}),
  .we1({1'b0, 1'b0}),
  .q1()
);
//OIBIDR ?

///////// NOT DRIVEN,  TO DRIVE //////////
assign OVD[15:0] = 16'b0;
assign VA[3:0] = 4'b0;
assign NOOBJ = 1'b0;
assign ODHREY = 1'b0;
assign SPR1_3 = 1'b0;
assign SPR2_3 = 1'b0;

endmodule
