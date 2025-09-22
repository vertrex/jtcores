module pld23(
    input  wire SA_3,
    input  wire SA_13,
    input  wire SA_14,
    input  wire SA_15,
    input  wire MEMRQ_n,
    input  wire IORQ_n,
    input  wire RD_n,
    input  wire RFSH_n,
    input  wire M1_n,

    output wire B0, // active-low
    output wire B1, // active-low
    output wire SEL6295, // active-low
    output wire irq_ack_n, // active-low
    output wire B4, // active-low
    output wire B5, // active-low
    output wire B6, // active-low
    output wire B7  // active-low
);

    wire t_B0  = (~SA_13) &  SA_14  & (~SA_15) & (~MEMRQ_n) & RFSH_n;
    wire t_B1  = (~SA_3) & (~RD_n);
    wire t_SEL6295  =  SA_13  &  SA_14  & (~SA_15) & (~MEMRQ_n) & RFSH_n;
    wire t_irq_ack_n  = (~IORQ_n) &  (~M1_n);
    wire t_B4  =  SA_15  & (~MEMRQ_n) & (~RD_n) & RFSH_n;
    wire t_B5  =  SA_13  & (~SA_14) & (~SA_15) & (~MEMRQ_n) & RFSH_n;

    wire t_B6  = (~SA_13) & (~SA_14) & (~SA_15) & (~MEMRQ_n) & (~RD_n) & RFSH_n;
    wire t_B7  = (~SA_13) & (~SA_14) & (~SA_15) & (~MEMRQ_n) & (~RD_n) & RFSH_n; // same as B6 per JED

    assign B0 = ~t_B0;
    assign B1 = ~t_B1;
    assign SEL6295 = ~t_SEL6295;
    assign irq_ack_n = ~t_irq_ack_n;
    assign B4 = ~t_B4;
    assign B5 = ~t_B5;
    assign B6 = ~t_B6;
    assign B7 = ~t_B7;

endmodule
