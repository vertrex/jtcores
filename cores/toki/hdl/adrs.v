module ADRS(
    input           clk,
    // PLD21 22M
    input   [23:17] A,
    input           MBUSDIR,
    input           OBUSDIR,
    input           MEMDIR,
   
     // 74LS154 10P & 74LS138 16M
    input     [6:1] MAB,
    input           MWRLB,
    input           MRDLB,

    // 74LS273 18M 
    input           RESET_A,
    input    [15:0] MDB,

    // PLD21 22M
    output  ROM0,
    output  ROM1,
    output  RAM,
    output  MUSIC,
    output  MBUFEN,
    output  MBUFDR,

    // 74LS154 10P
    
    // Scrolling sel & rst  
    output  RST_S1H,
    output  SEL_S1H,
    output  RST_S1Y,
    output  SEL_S1Y,
    // Scroll 2 sel & rst
    output  RST_S2H,
    output  SEL_S2H,
    output  RST_S2Y,
    output  SEL_S2Y,

    // Memory DMA Request 
    output  MDMARQ,
    // Object DMA Request
    output  ODMARQ,

    // 74LS138 16M
    output  RD_DISPW,
    output  RD_PLYER,
    output  RD_EXTIF,
    
    // 74LS273 18M 
    output  reg S1MASK,
    output  reg S2MASK,
    output  reg OBJMASK,
    output  reg S4MASK,
    output  reg PRIOR_A,
    output  reg PRIOR_B,

    // 74LS368 17M
    output  reg HREV,
    output  reg YREV

);
//PLD 21, 22M, p3
wire WRADRS, RDADRS;

PLD21 PLD21_u(
  .A(A[23:17]),
  .MBUSDIR(MBUSDIR),
  .OBUSDIR(OBUSDIR),
  .MEMDIR(MEMDIR),

  .ROM0(ROM0),
  .ROM1(ROM1),
  .RAM(RAM),
  .MUSIC(MUSIC),
  .MBUFEN(MBUFEN),
  .MBUFDR(MBUFDR),
  .WRADRS(WRADRS),
  .RDADRS(RDADRS)
);

// 74LS154 10P p3
//
//
wire MASKS;
wire enable;
reg [15:0] select; //wire ? 
wire [4:0] nc; 

// All this signal are active low !  
LS154 LS154_u(
   .A(MAB[6:3]),
   .G1(WRADRS), //10100?0 & MBUSDIR & OBUSDIR  & 00?0110 ? 
   .G2(MWRLB), // G1 & G2 must be 0 to work so WRARDS & MWRLB must be 0 
    // All this signal are active low !  
   .Y({ nc[4:0], MASKS, ODMARQ, MDMARQ, SEL_S2Y, RST_S2Y, SEL_S2H, RST_S2H, SEL_S1Y, RST_S1Y, SEL_S1H, RST_S1H })
);

// 74LS138 16M
wire [4:0] nc2;

LS138 LS138_16M_u(
   .S0(MAB[1]),
   .S1(MAB[2]),
   .S2(MAB[3]),
   .E1(MRDLB),
   .E2(RDADRS),
   .E3(1'b1),

   .Q({ nc2[4:0] , RD_EXTIF, RD_PLYER, RD_DISPW})
);

//74LS273 18M 
//always @(posedge clk) begin 
always @(posedge clk, negedge RESET_A) begin 
    if (~RESET_A) begin  //reset_a is low
       { S4MASK, OBJMASK, S2MASK, S1MASK } <= 4'b0;
       { PRIOR_B, PRIOR_A } <= 2'b0;
       HREV <= 1'b0;
       YREV <= 1'b0;
       end 
     else if (MASKS == 1'b0)  begin 
       { S4MASK, OBJMASK, S2MASK, S1MASK } <= MDB[3:0];
       // if ((cpu_dout[15:0] & 16'h100) == 16'h0) ??? 0b100_000_000
       { PRIOR_B, PRIOR_A } <= MDB[9:8]; //XXX DON'T WORK WELL ON POCKET 
       // 74LS368 17M
       HREV <= ~MDB[14];
       YREV <= ~MDB[15];
      end
end 

endmodule 
