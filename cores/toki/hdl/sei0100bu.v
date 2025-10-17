// 2151/5205 controller 
//SEI0100BU - Custom chip marked 'SEI0100BU YM3931' (SDIP64)

module sei0100bu
(
  input         clk,
  input         rst, //pin 33
  input         MUSIC,   //pin 56   
  input         MWRLB,   //pin 59 
  input         MRDLB,   //pin 60 ?
  input   [3:1] MAB,     //pin 56-58
  input   [7:0] MDB_OUT,     //pin 24-31 
  output  [7:0] MDB_IN,     //pin 24-31 
  //pin 38, 34 1'b0 
  input         irq_ack_n, //pin 54,  PLD23 B3 
  input         IRQ3812,  //pin 63
  input         CLK_3_6,//pin 49
  input         COIN1,  //pin 36 
  input         COIN2, //pin 37
  input         SEI0100_CS_N, //pin 41, PLD23 B0
  input         SWRB, //pin 47 
  input         B1, //pin 48, PLD23 B1 (bit 3 low ?) >9 == for for CS? (FOR SD IN) addr > 9
  input   [4:0] SA, //pin 42-46 //32 value + sei0100_cs -> z80_cs value!! (max 4001b  0x1b == 27) 

  //output 
  //pin nc 2-18,62 
  output        COUNTER1, //pin 39
  output        COUNTER2, //pin 40
  output        Z80_INT, //pin 23
  output reg    CS3812, //pin 61
 
  input   [7:0] SD_OUT, //read data from CPU ! 
  output  [7:0] SD_IN,//19,50,20,51,21,52,22,53  //reg?

  output reg    BANK_SELECTED //pin 35 (sa15 on or off for bank ! )
  //bank_rom_addr <= {bank_selected, SA[14:0]}
);

//reg bank_selected = 1'b0; // switch to data bank

always @(posedge clk) begin
    // bank size is 0x10000 
    // z80 address from 0x8000  to 0x10000 is read directly from the rom 
    // z80 address from 0x10000 to 0x18000 is read after switching bank
    //if (SA[15:0] == 16'h4007) // switch bank usage  //bank_rom_cs? PLD232 
    // XXX B1 ? 
    if (~SEI0100_CS_N && SA[4:0] == 5'd7) //~B1  ??
      BANK_SELECTED <= SD_OUT[0];
    //if (SA[15:0] >= 16'h8000 && bank_selected == 1'b0) //bit 15 up or down from SEI 0100bu or JP121 ?
      //bank_rom_addr[15:0] <= (SA[15:0] - 16'h8000); //0x2000 first bytes
    //else if (SA[15:0] >= 16'h8000 && bank_selected == 1'b1)
      //bank_rom_addr[15:0] <= SA[15:0];
end



//assign CS3812 = ~ym_wr; //XXX ONLY 8 ??  on in one out ? one wqrite one read ?
//up if read or write -> cs 
//if cs + SWRB it's write 
//addr is 1 if ym_cs_1
reg sub2main_pending;

always @(*) begin
    // IO
    // 0b1000  / 0b1001 (SA[0])
    CS3812 = ~(~SEI0100_CS_N && (SA[4:0] == 5'h08 || SA[4:0] == 5'h09));
end 

reg [7:0] m68k_sound_latch_0;
reg [7:0] m68k_sound_latch_1;

assign SD_IN[7:0] =
                    //XXX & ~SRDB  ?
                    //IRQ3812 ack 
                    ~irq_ack_n & ~IRQ3812 ? 8'hd7 : 
                    //irq6295_n  ack
                    ~irq_ack_n & ~((~MUSIC & (MAB[3:1] == 3'd4)))  ? 8'hdf :
                    // m68k_latch0_cs 
                    (~SEI0100_CS_N && (SA[4:0] == 5'h10))    ? m68k_sound_latch_0[7:0] :
                    // m68k_latch1_cs
                    (~SEI0100_CS_N && (SA[4:0] == 5'h11))    ? m68k_sound_latch_1[7:0] :
                    // main_data_pending_cs 
                    (~SEI0100_CS_N && (SA[4:0] == 5'h12))    ? {7'b0, sub2main_pending}:
                    // read coin cs 
                    (~SEI0100_CS_N && (SA[4:0] == 5'h13))    ? {6'b0, ~COIN2, ~COIN1}  :
                    8'hff;

////// Z80 databus input   /////////////////////// 
//
//  IRQ use z80 interrupt mode 0 :
//  After interrupt is asserted, the cpu signal it's 
//  ready by putting iorq and m1 high 
//  it then read on the databus 
//  this data is directly executed by the cpu as an opcode 
//
//  - ym3821 assert irq and put 0xd7 (rst10) on the bus 
//  - 68k main cpu assert irq and put 0xdf (rst18) on the bus 
// 
//  both interrupt are needed to handle sound and coin input
//
assign Z80_INT = ~(irq_rst10|irq_rst18);

reg irq_rst10;
reg irq_rst18;

reg stop_irq_10; 
reg stop_irq_18; 

//like an address bus just a assign ? 

always @(posedge clk) begin
  if (rst) begin
    irq_rst10 <= 1'b0;
    irq_rst18 <= 1'b0;
    stop_irq_10 <= 1'b0;
    stop_irq_18 <= 1'b0;
    end
  else if (CLK_3_6) begin
      if (irq_ack_n & stop_irq_10) begin
        irq_rst10 <= 1'b0;
        stop_irq_10 <= 1'b0;
        end
      else if (irq_ack_n & stop_irq_18) begin
        stop_irq_18 <= 1'b0;
        irq_rst18 <= 1'b0;
        end
      else if (IRQ3812 == 1'b0)
        irq_rst10 <= 1'b1;
      else if (oki6295_irq_n == 1'b0) //~m68k_sound_cs_4
        irq_rst18 <= 1'b1;
          
      if (~irq_ack_n & irq_rst10)
        stop_irq_10 <= 1'b1;
      else if (~irq_ack_n & irq_rst18)
        stop_irq_18 <= 1'b1;
    end 
end

///////// Sound ///////////////
//
// Sound register latch
//
//A[23:17]
//
//   
// ~(~A[17] & ~A[18] & A[19] & ~A[20] & ~A[21] & ~A[23] & MBUSDIR & OBUSDIR); // /o15i
//000 100? ???? ???? ???? ????               
//   _9876_5432_1098_7654_3210
//  0b1000_0000_0000_0000_0000' //is 80000 ! 
//  is that lateched ??
always @(posedge clk) begin
  if (rst) begin
    m68k_sound_latch_0 <= 8'b0;
    m68k_sound_latch_1 <= 8'b0;
    end
  //else if (CLK_3_6) begin //@clk we read from cpu ? what could be the clock on the original there is no cpu clk
  else if (CLK_3_6) begin //@clk we read from cpu ? what could be the clock on the original there is no cpu clk
    //MUSIC ? ?MWRLB MRDB ? 
    //0b1000_0000_0000_0000_0000'
    //8000
    // MWRLDB ? MRDB ? to check ?
    if (~MUSIC & (MAB[3:1] == 3'd0))
      m68k_sound_latch_0[7:0] <= MDB_OUT[7:0];
    //0b1000_0000_0000_0000_0010'
    //80001 
    if (~MUSIC & (MAB[3:1] == 3'd1)) //was 2 but it's << 1 
      m68k_sound_latch_1[7:0] <= MDB_OUT[7:0];
  end
end

////// SOUND ////////////////////
//
// sound latch
//
//
reg oki6295_irq_n;

// indicate is z80 sent data to main to be read 
always @(posedge clk) begin
    // data is waiting to be read
    if (CLK_3_6) begin 
      if (~SEI0100_CS_N && (SA[4:0] == 5'h00)) 
          sub2main_pending <= 1'b1;
      // data is has been processed by 68k 
      else if (~MUSIC & (MAB[3:1] == 3'd6 || MAB[3:1] == 3'd2)) //? it's used as cpu din too
          sub2main_pending <= 1'b0;
    end 
end 

// main cpu assert irq for oki6295
always @(posedge clk) begin
  //if (PRCLK1) begin XXX 
  if (CLK_3_6) begin 
    if (~MUSIC & (MAB[3:1] == 3'd4)) 
      oki6295_irq_n <= 1'b0; 
    else //clear or wait to be read ? by irq6285 how do we acknowledge ? 
         //6285 is lot slower does it have time to read ? 
      oki6295_irq_n <= 1'b1;
  end
end 

reg [7:0] z80_sound_latch_0; 
reg [7:0] z80_sound_latch_1; 

// 
always @(posedge clk) begin //XXX speed must be same than 68k din ?
  if (rst) begin
    z80_sound_latch_0 <= 8'b0;
    z80_sound_latch_1 <= 8'b0;
    end
  else if (CLK_3_6) begin // ?
    // send z80 data to 68k cpu
    if (~SEI0100_CS_N && (SA[4:0] == 5'h18)) 
      z80_sound_latch_0 <= SD_OUT[7:0]; //xxx put back or use latch + cs ?

    if (~SEI0100_CS_N && (SA[4:0] == 5'h19))
      z80_sound_latch_1 <= SD_OUT[7:0]; //XXX put back
    end 
end

// XXX COIN RAJOTUE 2 COIN A CHAQUE FOIS 
// TROP RAPIDE DOIT ETRE CLOCK SUR 3_6 ?? 
// IL EST PAS CLEAR ASSEZ VITE 
// coin latch ?
reg coin_latch;

always @(posedge clk) begin //XXX speed must be same than 68k din ?
  if (rst) begin
    coin_latch <= 1'b1; //1b1 or 1b0 ? at default as it seems to be cleared 
    end
  else if (CLK_3_6) begin // ?
    // TOO LONG ?
    //data has been process by main we clear the coin latch
    //and the other latch too ?
    if (~MUSIC & (MAB[3:1] == 3'd6 || MAB[3:1] == 3'd2)) begin //? it's used as cpu din too
      //clear other latch too ? 
      coin_latch <= 1'b1;
      end
    else if (~SEI0100_CS_N && (SA[4:0] == 5'h00)) begin
      coin_latch <= 1'b0; //XXX put back ?
      end
      //else 0 ? 

    // data from z80 is pending read from 68k
    end
end

assign MDB_IN[7:0] = // low word 
                     (~MUSIC & (MAB[3:1] == 3'd2)) ? z80_sound_latch_0[7:0] :
                     // high word
                     (~MUSIC & (MAB[3:1] == 3'd3)) ? z80_sound_latch_1[7:0] :
                     //read coin status 
                     (~MUSIC & (MAB[3:1] == 3'd5)) ? {7'b0, coin_latch} :
                     8'd0;
endmodule
