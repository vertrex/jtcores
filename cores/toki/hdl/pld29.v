// Toki-PLD29V.C18.jed
module PLD29 (
    input  HREV,               // pin 1
    input  HD,                 // pin 2
    input  D1V_7P,             // pin 3; physical sheet-16 net name
    input  E1FIND,             // pin 4, U181 FIND
    input  E2FIND,             // pin 5, U182 FIND
    input  O1FIND,             // pin 6, U183 FIND
    input  O2FIND,             // pin 7, U184 FIND
    input  OBJMASK,            // pin 8
    input  NOOBJ_CT2_LATCH1,   // pin 9, U163 Q7
    input  NOOBJ_CT2_LATCH2,   // pin 11, U169 Q7
    output HREV_HD,            // pin 12, /o12 physical pin level
    output NHREV_HD,           // pin 13, /o13 physical pin level
    output OBJON,              // pin 15, /o15
    output o16_n,              // pin 16, /o16; unused on sheet 16
    output MASK_NOOBJ_2,       // pin 18, /o18; U164B enable term
    output MASK_NOOBJ_1        // pin 19, /o19; U164A enable term
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
