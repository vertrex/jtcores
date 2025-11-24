// Verilog translation of second JED PLD
// Active-high/low outputs implemented exactly as per JED listing
//
// RDCLKR IS NOT USED OR IT"S CLOCKED ??? XXX check it's really a gal168 
// or if it's clocked
module PLD24(
    //counter start at XOBDIR  (clr)
    //@RDCLKR  
    //load => LSBLD
    input  [2:1] FDA,  //p1 et p2 
    //SDTS latch STARTV @VCLK
    input  SDTS,  //p3 
    //input   RDCLK, p4 unused ? 
    input  DLHD,  //p5 
    input  OIBDIR,  //p6 
    input  OVER256,  //p7 
    input  INSCRN,  //p8
    input  OBJEN_2,  //p9 
    input  VFIND, //p11
    
    output MATCHV, //p12 
    output OBJEN_3, //p13 
    output LSBLD, //p14 
    output XOBDIR, //p15 
    output RAM2VLD, //p16
    output MSBLD, //p17 
    output MSBET, //p18
    output ILD2  //p19
);

    assign MATCHV =  ~(OVER256 & ~VFIND);

    assign OBJEN_3 = ~INSCRN & ~OBJEN_2;

    assign LSBLD = (~FDA[1] &  FDA[2] &  SDTS & ~OIBDIR) |
                   (~FDA[1] &  FDA[2] & ~SDTS &  DLHD) |
                   (~FDA[2] &  SDTS   & ~OIBDIR) |
                   (~FDA[2] & ~SDTS   &  DLHD);

    //assign LSBLD = (~FDA[1] | ~FDA[2]) & MSBLD;

    assign XOBDIR = ~OIBDIR;

    assign RAM2VLD = ~(( FDA[1] & ~FDA[2] &  SDTS) |
                       (~FDA[1] &  FDA[2] &  SDTS));
    //assign RAM2VLD = ~SDTS | ~(FDA[1] ^  FDA[2]);

    // start dma counter ?
    assign MSBLD  = ( SDTS & ~OIBDIR) |
                    (~SDTS &  DLHD);

    assign MSBET = SDTS &  (~FDA[1] &  FDA[2] & SDTS) |
                           (~FDA[2] &  SDTS);
    //assign MSBET = SDTS & (~FDA[1] | ~FDA[2]); 

    assign ILD2 = ~SDTS & DLHD;

endmodule

