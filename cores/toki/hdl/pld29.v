module PLD29 (
    input  HREV,
    input  HD,
    input  D1V_7P,
    input  E1FIND,
    input  E2FIND,
    input  O1FIND,
    input  O2FIND,
    input  OBJMASK,
    input  NOOBJ_CT2_LATCH1,
    input  NOOBJ_CT2_LATCH2,
    //output 
    output HREV_HD,
    output NHREV_HD,
    output OBJON,
    output o16_n,
    output MASK_NOOBJ_2,
    output MASK_NOOBJ_1 
);

    assign HREV_HD = ~(~HREV & ~HD);
    assign NHREV_HD = ~( HREV & ~HD );
    
    wire term15_1 = (~D1V_7P & ~E1FIND &  E2FIND & ~O1FIND & ~O2FIND);
    wire term15_2 = (~D1V_7P &  E1FIND & ~O1FIND & ~O2FIND);
    wire term15_3 = ( D1V_7P & ~E1FIND & ~E2FIND &  O1FIND);
    wire term15_4 = ( D1V_7P & ~E1FIND & ~E2FIND & ~O1FIND);
    wire term15_5 = (~E1FIND & ~E2FIND & ~O1FIND & ~O2FIND);
    assign OBJON = ~( term15_1 | term15_2 | term15_3 | term15_4 | term15_5 );
    
    wire term16_1 = ( D1V_7P & ~E1FIND &  E2FIND & ~O1FIND & ~O2FIND);
    wire term16_2 = ( D1V_7P &  E1FIND & ~O1FIND & ~O2FIND);
    wire term16_3 = (~D1V_7P & ~E1FIND & ~E2FIND &  O1FIND);
    wire term16_4 = (~D1V_7P & ~E1FIND & ~E2FIND & ~O1FIND);
    wire term16_5 = (~E1FIND & ~E2FIND & ~O1FIND & ~O2FIND);
    assign o16_n = ~( term16_1 | term16_2 | term16_3 | term16_4 | term16_5 );

    assign MASK_NOOBJ_2 = ~( ~OBJMASK & NOOBJ_CT2_LATCH2 );
    assign MASK_NOOBJ_1 = ~( ~OBJMASK & NOOBJ_CT2_LATCH1 );

endmodule
