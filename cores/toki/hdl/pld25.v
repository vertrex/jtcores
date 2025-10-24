module PLD25 (
    input  wire FDA_1,
    input  wire FDA_2,
    input  wire RDCLK,
    input  wire ORIGIN,
    input  wire OIBDIR,
    input  wire POS_8,
    input  wire CARY_M,
    input  wire XC4,
    input  wire BUSAK,
    input  wire OBUSRQ,

    output wire CTRL_LT,  // active low
    output wire RD_VPOS,  // active low
    output wire RD_HPOS,  // active low
    output wire LT_VPOS,  // active high
    output wire LT_HPOS,  // active high
    output wire ND2_8,  // active high
    output wire OBUSAK,  // active low
    output wire RD_CHAR   // active low
);

    //============================
    // Equations from original PLD
    //============================

    // /CTRL_LT = /FDA_1 & /FDA_2 & /RDCLK & /OIBDIR
    assign CTRL_LT = ~((~FDA_1) & (~FDA_2) & (~RDCLK) & (~OIBDIR));

    // /RD_VPOS = FDA_1 & FDA_2 & /OIBDIR
    assign RD_VPOS = ~((FDA_1) & (FDA_2) & (~OIBDIR));

    // /RD_HPOS = /FDA_1 & FDA_2 & /OIBDIR
    assign RD_HPOS = ~((~FDA_1) & (FDA_2) & (~OIBDIR));

    // LT_VPOS = FDA_1 & FDA_2 & /ORIGIN & /OIBDIR
    assign LT_VPOS = (FDA_1) & (FDA_2) & (~ORIGIN) & (~OIBDIR);

    // LT_HPOS = /FDA_1 & FDA_2 & /ORIGIN & /OIBDIR
    assign LT_HPOS = (~FDA_1) & (FDA_2) & (~ORIGIN) & (~OIBDIR);

    // ND2_8 = POS_8 & /CARY_M & /XC4 +
    //       /POS_8 & CARY_M & /XC4 +
    //       /POS_8 & /CARY_M & XC4 +
    //       POS_8 & CARY_M & XC4
    assign ND2_8 = ( POS_8  & ~CARY_M & ~XC4 ) |
                 ( ~POS_8 &  CARY_M & ~XC4 ) |
                 ( ~POS_8 & ~CARY_M &  XC4 ) |
                 (  POS_8 &  CARY_M &  XC4 );

    // /OBUSAK = /BUSAK & /OBUSRQ
    assign OBUSAK = ~((~BUSAK) & (~OBUSRQ));

    // /RD_CHAR = FDA_1 & /FDA_2 & /OIBDIR
    assign RD_CHAR = ~((FDA_1) & (~FDA_2) & (~OIBDIR));
endmodule
