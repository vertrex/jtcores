// 2151/5205 controller 
//SEI0100BU - Custom chip marked 'SEI0100BU YM3931' (SDIP64)

module sei0100bu
(
  input         SYS_RST, //pin 33
  input         MUSIC,   //pin 56   
  input         MWRLB,   //pin 59 
  input         MRDLB,   //pin 60 ?
  input   [3:1] MAB,     //pin 56-58
  input   [7:0] MDB,     //pin 24-31 
  //pin 38, 34 1'b0 
  input         irq_ack_n, //pin 54,  PLD23 B3 
  input         IQR3812,  //pin 63
  input         CLK_3_6,//pin 49
  input         COIN1,  //pin 36 
  input         COIN2, //pin 37
  input         SEI0100_CS, //pin 41, PLD23 B0
  input         SWRB, //pin 47 
  input         B1, //pin 48, PLD23 B1 (bit 3 low ?)
  input   [4:0] SA, //pin 42-46 

  //output 
  //pin nc 2-18,62 
  output        pin35, //pin 35 //XXX ROM A15 ??? inversed wire ?? 
  output        COUNTER1, //pin 39
  output        COUNTER2, //pin 40
  output        Z80_INT, //pin 23
  output        CS3812, //pin 61
  output  [7:0] SD //19,50,20,51,21,52,22,53

);


endmodule
