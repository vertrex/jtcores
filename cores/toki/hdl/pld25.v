module PLD25 (
    input  [2:1] FDA,
    input        RDCLK,  
    input        ORIGIN,
    input        OIBDIR,
    input        POS_8,
    input        CARY_M,
    input        XC4,      // X clock 4, read 4 bytes of sprite ? 
    input        BUSAK,
    input        OBUSRQ,

    output       CTRL_LT,  // Control latch 
    output       RD_VPOS,  // Read sprite veritcal position 
    output       RD_HPOS,  // Read sprite horizontal position
    output       LT_VPOS,  // latch sprite vertical position 
    output       LT_HPOS,  // latch sprite horizontal position
    output       ND2_8,    
    output       OBUSAK,
    output       RD_CHAR   // Read char tile index
);
    // /CTRL_LT = /FDA[1] & /FDA[2] & /RDCLK & /OIBDIR
    assign CTRL_LT = ~((~FDA[1]) & (~FDA[2]) & (~RDCLK) & (~OIBDIR));

    // /RD_VPOS = FDA[1] & FDA[2] & /OIBDIR
    assign RD_VPOS = ~((FDA[1]) & (FDA[2]) & (~OIBDIR));

    // /RD_HPOS = /FDA[1] & FDA[2] & /OIBDIR
    assign RD_HPOS = ~((~FDA[1]) & (FDA[2]) & (~OIBDIR));

    // LT_VPOS = FDA[1] & FDA[2] & /ORIGIN & /OIBDIR
    assign LT_VPOS = (FDA[1]) & (FDA[2]) & (~ORIGIN) & (~OIBDIR);

    // LT_HPOS = /FDA[1] & FDA[2] & /ORIGIN & /OIBDIR
    assign LT_HPOS = (~FDA[1]) & (FDA[2]) & (~ORIGIN) & (~OIBDIR);

    // ND2_8 = POS_8 & /CARY_M & /XC4 +
    //       /POS_8 & CARY_M & /XC4 +
    //       /POS_8 & /CARY_M & XC4 +
    //       POS_8 & CARY_M & XC4
    assign ND2_8 = (POS_8  & ~CARY_M & ~XC4 ) |
                   (~POS_8 &  CARY_M & ~XC4 ) |
                   (~POS_8 & ~CARY_M &  XC4 ) |
                   ( POS_8 &  CARY_M &  XC4 );

    // /OBUSAK = /BUSAK & /OBUSRQ
    assign OBUSAK = ~((~BUSAK) & (~OBUSRQ));

    // /RD_CHAR = FDA[1] & /FDA[2] & /OIBDIR
    assign RD_CHAR = ~((FDA[1]) & (~FDA[2]) & (~OIBDIR));
endmodule
