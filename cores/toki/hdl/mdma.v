///////////// Memory DMA //////////////////
// Toki board is using DMA to copy CPU memory to VRAM, BG1, BG2, PALETTE  memory (SIS6091 1024KB RAM) 
//
//
module MDMA(
    input clk,
    // 6MHZ clock
    input P6M,
    input N6M,
    // System reset 
    input SYS_RESET,

    // Memory DMA Request 
    input MDMARQ,
    // Bus Acknowledge 
    input BUSAK,
    // X pos 4 
    input EXH_4,

    // ~X pos 4 
    output EXH_4_n,
    // ~ P6M 
    output WRN6M,
    // Memory Bus Request, active low ?
    output MBUSRQ,

    // Memory Bus Direction (R/W) , DMA Arbitration
    output MBUSDIR,
    // DMA select palette 
    output DMSL_GL,
    // DMA select  background 2
    output DMSL_S1, 
    // DMA select background 2
    output DMSL_S2,
    // DMA select char
    output DMSL_S4,

    // DMA counter (0, 2048) 
    output [12:1] KDA,
    // Memory Address Bus  
    //output MAB[15:1],
    // DMA Ready (DMA copy is finished)
    //output [15:1] MAB,
    output DMARD
);

// 74LS74 5k page 6 
//
wire q_6k1; 
wire qn_6k1; //start dma counter 

// output RCO of 74LS161 9K
wire  copy_end; // XXX we need to add the COUNTER SO WE can copy and finish the counter 

//74LS368 17M
wire dma_end_n; 
//this mean we can replace most of the CS and we got the MDMARQ !!!
assign MBUSDIR = ~qn_6k1;
assign EXH_4_n = ~EXH_4;
assign WRN6M = N6M;
assign dma_end_n = ~copy_end; // XXX OUTPUT OF RCO COUNTER HIGH 4*3 bits  1 when dma is finished 

//MBUSRQ should be 1 by default et 0 when up 

//5K 
//M_DMA_RQ : start DMA request 
LS74 _5K1_u(
   .CLK(MDMARQ),
   .CEN(MDMARQ), // GET Memory DMA Request 
   .D(1'b0),
   .PRE(q_6k1), // stop counter  
   .CLR(1'b1),
   .Q(MBUSRQ),  // START DMA BUS REQUEST 
   .QN()
);

// 5K 2 
//
wire qn_6k2;
wire q_5k2;

LS74 _5K2_u(
   .CLK(WRN6M),
   .CEN(WRN6M),
   .D(qn_6k2),
   .PRE(dma_end_n), 
   .CLR(1'b1),
   .Q(q_5k2),
   .QN()
);

// 6K 
LS74 _6k1_u(
   .CLK(WRN6M),
   .CEN(WRN6M),
   .D(q_5k2),
   .PRE(1'b1),
   .CLR(1'b1),
   .Q(q_6k1),
   .QN(qn_6k1) //start_dma_counter_n
);

wire busak_rq;
assign busak_rq = (MBUSRQ | BUSAK);

// 6K 2 
LS74 _6K2_u(
   .CLK(1'b0),
   .CEN(1'b0),
   .D(1'b0),
   .PRE(busak_rq), 
   .CLR(dma_end_n),
   .Q(),
   .QN(qn_6k2)
);


// Memory DMA COUNTER / Address bus
// This is used to copy from CPU memory to devices memory 
//
// 7K 
wire rco_1;

LS161 LS161_7K_u(
  .clk(clk),
  .CEN(WRN6M),
  .CLR_n(~SYS_RESET),
  .LOAD_n(qn_6k1), //load /reset to 4'b0
  .ENP(dma_end_n),  // 1 ? 0 if end ? 
  .ENT(~SYS_RESET),  //~rst ? XXX 
  .D(4'b0),
  .Q(KDA[4:1]),
  .RCO(rco_1)
);

// 8K
wire rco_2;

LS161 LS161_8K_u(
  .clk(clk),
  .CEN(WRN6M),
  .CLR_n(~SYS_RESET),
  .LOAD_n(qn_6k1),
  .ENP(dma_end_n),
  .ENT(rco_1),
  .D(4'b0),
  .Q(KDA[8:5]),
  .RCO(rco_2)
);

LS161 LS161_9K_u(
  .clk(clk),
  .CEN(WRN6M),
  .CLR_n(~SYS_RESET),
  .LOAD_n(qn_6k1),
  .ENP(dma_end_n),
  .ENT(rco_2),
  .D(4'b0),
  .Q(KDA[12:9]),
  .RCO(copy_end)
);

LS139 LS139_7L_u(
    .E1(q_6k1), //counter start 
    .A1(KDA[11]),
    .B1(KDA[12]),
    .Y1({DMSL_S4, DMSL_S2, DMSL_S1, DMSL_GL}),

    .E2(),
    .A2(),
    .B2(),
    .Y2()
);

// 74LS244P 8L & 9L 
//assign {DMARD , MAB[15:1]} = (MBUSDIR == 1'b0) ? { 1'b0 ,3'b111,  KDA[12:1]} : 16'bz;
assign {DMARD } = MBUSDIR == 1'b0 ?  1'b0 : 1'b1; //z ???? 

endmodule
