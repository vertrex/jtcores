

module OBJDMA(
    input           clk,
    input           STARTV,
    input           VCLK,
    input           RDCLK,
    input           RD_VPOS,
    input   [10:3]  FDA,
    input    [3:0]  ND1,
    input    [8:4]  ND2,
    input           HREVD_1, //_1 ? 
    input           VREVD_1, //_1 ? 
    input           SPR1_1, //_1 
    input           SPR2_1, //_1 
    input           OBJEN_1, //_1 
    //input           ODH, //?
    //input           SPR1_1, out or bidir ? 
    //input           SPR2_1,  out  or bidir ?
    input           DMLD, 
    input           VFIND,
    input           ODMARQ,
    input           OBUSAK,
    input           VORIGIN,
    input     [8:0] H_POS, 
    input           VREV,
    input           NV256,
    input           H_128,
    input           H_256,
    input           V1, //? 
    //output 
    output          MATCHV,
    output          XOBDIR,
    output          RAM2VLD,
    output   [10:1] FDA_OUT,
    output   [15:1] MAB_OUT, 
    output          DMARD,
    output    [3:0] VMT,
    output          EVNWR2, 
    output          ODDWR2,
    output          OIBDIR,
    output          OBUSRQ,
    output          OBUSDIR,
    output    [5:0] DMA2_EA,
    output    [5:0] DMA2_OA
);

/// NOT DRIVEN TO DRIVE 
assign MATCHV = 1'b0;
assign XOBDIR = 1'b0;
assign RAM2VLD = 1'b0;
assign FDA_OUT[10:1] = 10'b0;
assign MAB_OUT[15:1] = 15'b0;
assign DMARD = 1'b0;
assign VMT[3:0] = 4'b0;
assign EVNWR2 = 1'b0;
assign ODDWR2 = 1'b0;
assign OIBDIR = 1'b0;
assign OBUSRQ = 1'b0;  
assign OBUSDIR = 1'b1; //active low ? 
assign DMA2_EA[5:0] = 6'b0;
assign DMA2_OA[5:0] = 6'b0;

wire [7:0] VPD;
wire INSCRN; 
wire ODH; 
wire VREVD_2; 
wire SPR1_2, SPR2_2, OBJEN_2;
//////////// 

wire [1:0] NC;

sis6091 u_141(
  .clk0(clk),
  .cen0(RDCLK),
  .data0({2'b0, OBJEN_1,SPR2_1, SPR1_1,VREVD_1, HREVD_1,ND2[8:4] , ND1[3:0]}),
  .addr0({2'b0, FDA[10:3]}),
  .we0({RD_VPOS, RD_VPOS}),
  .q0(),

  .clk1(clk),
  .cen1(),
  .data1(),
  .addr1(), 
  .we1({1'b0, 1'b0}),
  .q1({NC[1:0], OBJEN_2, SPR2_2, SPR1_2, VREVD_2, ODH, INSCRN ,VPD[7:0]}) //xxx check that
);

endmodule
