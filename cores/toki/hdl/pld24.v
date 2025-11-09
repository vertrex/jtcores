// Verilog translation of second JED PLD
// Active-high/low outputs implemented exactly as per JED listing
//
// RDCLKR IS NOT USED OR IT"S CLOCKED ??? XXX check it's really a gal168 
// or if it's clocked
module PLD24(
    //counter start at XOBDIR  (clr)
    //@RDCLKR  
    //load => LSBLD
    input  FDA_1,  //p1
    input  FDA_2,  //p2 
    //SDTS latch STARTV @VCLK
    input  SDTS,  //p3 
    //input  wire RDCLK,
    input  DLHD,  //p4 
    input  OIBDIR,  //p5 
    input  OVER256,  //p6 
    input  INSCRN,  //p7 
    input  OBJEN_2,  //p8 
    input  VFIND, //p9
    
    output MATCHV, // active-low
    output OBJEN_3, // active-high
    output LSBLD, // active-high
    output XOBDIR, // active-high
    output RAM2VLD, // active-low
    output MSBLD, // active-high
    output MSBET, // active-high
    output ILD2  // active-high
);

    wire t_o12 =  OVER256 & (~VFIND);
    assign MATCHV  = ~t_o12;  // active-low output

    assign OBJEN_3 = (~INSCRN) & (~OBJEN_2);

    assign LSBLD = ((~FDA_1) &  FDA_2 &  SDTS & (~OIBDIR)) |
                 ((~FDA_1) &  FDA_2 & (~SDTS) &  DLHD) |
                 ((~FDA_2) &  SDTS & (~OIBDIR)) |
                 ((~FDA_2) & (~SDTS) &  DLHD);

    assign XOBDIR = ~OIBDIR;

    wire t_o16 = ( FDA_1 & (~FDA_2) &  SDTS) |
                 ((~FDA_1) &  FDA_2 &  SDTS);
    assign RAM2VLD = ~t_o16;  // active-low output

    assign MSBLD  = ( SDTS & (~OIBDIR)) |
                 ((~SDTS) &  DLHD);

    assign MSBET = ((~FDA_1) &  FDA_2 &  SDTS) |
                 ((~FDA_2) &  SDTS);

    assign ILD2 = (~SDTS) & DLHD;

endmodule

/*

o13 = /i8 & /i9
o13.oe = vcc

o14 = /i1 & i2 & i3 & /i6 +
      /i1 & i2 & /i3 & i5 +
      /i2 & i3 & /i6 +
      /i2 & /i3 & i5
o14.oe = vcc

o15 = /i6
o15.oe = vcc

/o16 = i1 & /i2 & i3 +
       /i1 & i2 & i3
o16.oe = vcc

o17 = i3 & /i6 +
      /i3 & i5
o17.oe = vcc

o18 = /i1 & i2 & i3 +
      /i2 & i3
o18.oe = vcc

o19 = /i3 & i5
o19.oe = vcc
*/
