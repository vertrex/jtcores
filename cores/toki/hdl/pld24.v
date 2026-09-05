// Toki-PLD24V.H13.jed (schematic sheet 14)
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

    // JED-derived polarity: object is valid only when not in-screen-clip and OBJEN_2 is low.
    assign OBJEN_3 = ~INSCRN & ~OBJEN_2;

    assign LSBLD = (~FDA[1] &  FDA[2] &  SDTS & ~OIBDIR) |
                   (~FDA[1] &  FDA[2] & ~SDTS &  DLHD) |
                   (~FDA[2] &  SDTS   & ~OIBDIR) |
                   (~FDA[2] & ~SDTS   &  DLHD);

    assign XOBDIR = ~OIBDIR;

    assign RAM2VLD = ~(( FDA[1] & ~FDA[2] &  SDTS) |
                       (~FDA[1] &  FDA[2] &  SDTS));

    assign MSBLD  = ( SDTS & ~OIBDIR) |
                    (~SDTS &  DLHD);

    assign MSBET = SDTS &  (~FDA[1] &  FDA[2] & SDTS) |
                           (~FDA[2] &  SDTS);

    assign ILD2 = ~SDTS & DLHD;
endmodule
