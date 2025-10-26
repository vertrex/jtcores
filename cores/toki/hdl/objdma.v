module OBJDMA(
    input           STARTY,
    input           YCLK,
    input           RDCLK,
    input           RD_VPOS,
    input   [10:3]  FDA,
    input    [3:0]  ND1,
    input    [3:0]  ND2,
    input           HREYD, //_1 ? 
    input           YREYD, //_1 ? 
    input           SPR1, //_1 
    input           SPR2, //_1 
    input           OBJEN, //_1 
    input           ODH, //?
    input           SPR1_2,
    input           SPR2_2, 
    input           DMLD, 
    input           VFIND,
    input           ODMARQ,
    input           OBUSAK,
    input           VORIGIN,
    input     [8:0] H_POS, 
    input           VCLK,
    input           YREV,
    input           NV256,
    input           H_128,
    input           H_256,
    input           Y1, //? 
    //output 
    output          MATCHY,
    output          XOBDIR,
    output          RAM2YLD,
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
assign MATCHY = 1'b0;
assign XOBDIR = 1'b0;
assign RAM2YLD = 1'b0;
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

////////// 

endmodule
