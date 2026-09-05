// Toki-PLD22V.B9.jed (sheet 5).
module PLD22(
    input  N6M,
    input  H1,
    input  H2,
    input  H4,
    input  H8,
    input  V1B,
    //input  SEI50_P29,
    input  OBJT1,
    input  V256,

    output FIRST_LD, // active-low 
    output SECND_LD, // active-low
    output CTLT1, // active-low
    output CTLT2, // active-low
    output EVN_LD, // active-low
    output ODD_LD, // active-low
    output NV256 // active-high
    //output VCLK  // active-high
);

    assign FIRST_LD = ~((~N6M) &  H1  & (~H2) &  H4  & (~H8));
    assign SECND_LD = ~((~N6M) &  H1  &  H2  &  H4  & (~H8));
    assign CTLT1 = ~((~N6M) & (~H1));
    assign CTLT2 = ~((~N6M) &  H1);
    assign EVN_LD = ~((~N6M) &  H1  &  H2  &  H4  & (~H8) & (~V1B) & (~OBJT1));
    assign ODD_LD = ~((~N6M) &  H1  &  H2  &  H4  & (~H8) &  V1B  & (~OBJT1));
    assign NV256 = ~V256;
endmodule
