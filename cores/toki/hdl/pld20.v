module PLD20 (
    input  AS_n,
    input  UDS_n,
    input  LDS_n,
    input  RW,
    input  BG_n,
    input  MBUSDIR,
    input  OBUSDIR,
    input  FC0,
    input  FC1,
    input  FC2,

    output BUSOPN,   // Active low in original logic
    output MWRLB,    // Active low
    output MWRMB,    // Active low
    output MRDLB,    // Active low
    output MRDMB,    // Active low
    output BUSAK,    // Active low
    output BGACK_n,  // Active high
    output VPA_n     // Active low
);

    // Combinational logic
    assign BUSOPN  = ~(MBUSDIR & OBUSDIR);                          // from o12_n
    assign MWRLB   = ~((~AS_n) & (~LDS_n) & (~RW));                 // from o13_n
    assign MWRMB   = ~((~AS_n) & (~UDS_n) & (~RW));                 // from o14_n
    assign MRDLB   = ~((~AS_n) & (~LDS_n) &  RW);                   // from o15_n
    assign MRDMB   = ~((~AS_n) & (~UDS_n) &  RW);                   // from o16_n
    //assign BUSAK   = ~(AS_n & (~BG_n));                             // from o17_n
    // THAT MAKE IT WORK BUT IT'S NOT THE ORIGINAL EQUATION ! XXX ? 
    assign BUSAK   = ~(~AS_n & (~BG_n));                             // from o17_n  
    assign BGACK_n =  (MBUSDIR & OBUSDIR);                          // from o18 (active high)
    assign VPA_n   = ~((~AS_n) & (~LDS_n) & RW & FC0 & FC1 & FC2);  // from o19_n

endmodule
