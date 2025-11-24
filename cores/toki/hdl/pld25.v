module PLD25 (
    input  [2:1] FDA, //i2, i1 
    input        RDCLK,  //i3 
    input        ORIGIN, //i4 
    input        OIBDIR,//i5 
    input        POS_8, //i6 
    input        CARY_M, //i7 
    input        XC4, //i8 
    input        BUSAK,//i9 
    input        OBUSRQ, //i11

    output       CTRL_LT,  // i12 Control latch  ACTIVE LOW 
    output       RD_VPOS,  // i13 Read sprite veritcal position ACTIVE LOW 
    output       RD_HPOS,  // i14 Read sprite horizontal position ACTIVE LOW 
    output       LT_VPOS,  // i15 latch sprite vertical position  ACTIVE HIGH  
    output       LT_HPOS,  // i16 latch sprite horizontal position ACTIVE HIGH 
    output       ND2_8,    // i17 ACTIVE HIGH  
    output       OBUSAK,   // i18 ACTIVE LOW 
    output       RD_CHAR   // i19 Read char tile index ACTIVE LOW 
);
        // FDA : ram words [] 
        // 00 : CTRL LT  
        // 01 : RD_CHAR  
        // 10 : RD_HPOS , LT_HPOS + ORIGIN (IF BIT HIGH IN CTR_LT)  
        // 11 : RD_VPOS , LT_VPOS + ORIGIN (IF BIT HIGH IN CTRL_LT)

    //  /o12 = /i1 & /i2 & /i3 & /i5
    assign CTRL_LT = ~(~FDA[2] & ~FDA[1] & ~RDCLK & ~OIBDIR);
    //  /o13 = i1 & i2 & /i5
    assign RD_VPOS = ~(FDA[2] & FDA[1] & ~OIBDIR);
    //  /o14 = /i1 & i2 & /i5
    assign RD_HPOS = ~(FDA[2] & ~FDA[1] & ~OIBDIR); // XXX add rdclk ? 
    //  o15 = i1 & i2 & /i4 & /i5
    assign LT_VPOS = FDA[2] & FDA[1] & ~ORIGIN & ~OIBDIR; //XXX add rd clk ? 
    //  o16 = /i1 & i2 & /i4 & /i5
    assign LT_HPOS = FDA[2] & ~FDA[1] & ~ORIGIN & ~OIBDIR; //xxx add rd clk ? 

    //  o17 = i6 & /i7 & /i8 +
      ///i6 & i7 & /i8 +
      ///i6 & /i7 & i8 +
      //i6 & i7 & i8

    // ND2_8 = POS_8 & /CARY_M & /XC4 +
    //       /POS_8 & CARY_M & /XC4 +
    //       /POS_8 & /CARY_M & XC4 +
    //       POS_8 & CARY_M & XC4
    assign ND2_8 = (POS_8  & ~CARY_M & ~XC4 ) |
                   (~POS_8 &  CARY_M & ~XC4 ) |
                   (~POS_8 & ~CARY_M &  XC4 ) |
                   ( POS_8 &  CARY_M &  XC4 );

    // /OBUSAK = /BUSAK & /OBUSRQ
    // /o18 = /i9 & /i11
    assign OBUSAK = ~(~BUSAK & ~OBUSRQ);
    // /o19 = i1 & /i2 & /i5
    assign RD_CHAR = ~(~FDA[2] & FDA[1] & ~OIBDIR);

endmodule
