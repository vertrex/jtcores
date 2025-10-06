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
  output reg  [7:0] MDB_IN,     //pin 24-31 
  //pin 38, 34 1'b0 
  input         irq_ack_n, //pin 54,  PLD23 B3 
  input         IRQ3812,  //pin 63
  input         CLK_3_6,//pin 49
  input         COIN1,  //pin 36 
  input         COIN2, //pin 37
  input         SEI0100_CS_N, //pin 41, PLD23 B0
  input         SWRB, //pin 47 
  input         B1, //pin 48, PLD23 B1 (bit 3 low ?)
  input   [4:0] SA, //pin 42-46 //32 value + sei0100_cs -> z80_cs value!! (max 4001b  0x1b == 27) 

  //output 
  //pin nc 2-18,62 
  output        pin35, //pin 35 //XXX ROM A15 ??? inversed wire ?? 
  output        COUNTER1, //pin 39
  output        COUNTER2, //pin 40
  output        Z80_INT, //pin 23
  output        CS3812, //pin 61
  //SD_OUT !
  input       [7:0] SD_OUT, //read data from CPU ! 
  output  reg    [7:0] SD_IN//19,50,20,51,21,52,22,53  //reg?

);

reg  ym_cs_0, ym_cs_1, ym_wr, 
     m68k_latch0_cs, m68k_latch1_cs, 
     main_data_pending_cs, read_coin_cs;

assign CS3812 = ~ym_wr; //XXX ONLY 8 ??  on in one out ? one wqrite one read ?

// old z80_cs.v 
always @(*) begin
    // IO
    ym_cs_0 =  (~SEI0100_CS_N &&  SA[4:0] == 5'h08);
    ym_cs_1 =  (~SEI0100_CS_N &&  SA[4:0] == 5'h09); //SA
    ym_wr = (~SEI0100_CS_N && (SA[4:0] == 5'h08 || SA[4:0] == 5'h09));
    m68k_latch0_cs =  (~SEI0100_CS_N && (SA[4:0] == 5'h10));
    m68k_latch1_cs =  (~SEI0100_CS_N && (SA[4:0] == 5'h11));
    main_data_pending_cs =   (~SEI0100_CS_N && (SA[4:0] == 5'h12));
    read_coin_cs =   (~SEI0100_CS_N && (SA[4:0] == 5'h13));
end 

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
// XXX ??? BUS SHARED ? + CONTROLLER ?

reg irq_rst10;
reg irq_rst18;
reg stop_irq_10; 
reg stop_irq_18; 

//wire z80_int_n;
//assign z80_int_n = ~(irq_rst10|irq_rst18);
assign Z80_INT = ~(irq_rst10|irq_rst18);

always @(posedge clk) begin
  if (rst) begin
    irq_rst10 <= 1'b0;
    irq_rst18 <= 1'b0;
    stop_irq_10 <= 1'b0;
    stop_irq_18 <= 1'b0;
    end
  else begin
    if (CLK_3_6) begin
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
end


reg [7:0] m68k_sound_latch_0;
reg [7:0] m68k_sound_latch_1;
//input   [3:1] MAB,     //pin 56-58
//input   [7:0] MDB,  
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
  else if (CLK_3_6) begin //@clk we read from cpu ? what could be the clock on the original there is no cpu clk
    //MUSIC ? ?MWRLB MRDB ? 
    //0b1000_0000_0000_0000_0000'
    //8000
    // MWRLDB ? MRDB ? to check ?
    if (~MUSIC & MAB[3:1] == 3'h0)
      m68k_sound_latch_0[7:0] <= MDB_OUT[7:0];
    //0b1000_0000_0000_0000_0010'
    //80001 
    if (~MUSIC & MAB[3:1] == 3'h1) //was 2 but it's << 1 
      m68k_sound_latch_1[7:0] <= MDB_OUT[7:0];
  end
end

   
//REG ?
//
always @(*) begin
  //@ Clock ?
// XXX FROM MDB/ MAB 
         SD_IN = ~irq_ack_n & irq_rst10                  ? 8'hd7 : 
                 ~irq_ack_n & irq_rst18                   ? 8'hdf :
                 main_data_pending_cs &  sub2main_pending ? 8'b1  :  //MWRLB  + DATA BUS ?
                 main_data_pending_cs & ~sub2main_pending ? 8'b0 :   //MRLB + DATA BUS ? 
                 //ym_cs_0 & ~SRDB                          ? ym3812_dout :  //0 onlyt ???it's rarrely used aslone CS3812 ? 
                 //read directly or from a latch ?? 
                 //
                 m68k_latch0_cs                           ? m68k_sound_latch_0[7:0] : //MDB //MAB 
                 m68k_latch1_cs                           ? m68k_sound_latch_1[7:0] ://MDB MAB 
                 read_coin_cs                             ? {6'b0, ~COIN2, ~COIN1} : //COIN 
                                                            8'hff;
end 

////// SOUND ////////////////////
//
// sound latch
//
//

// XXX done by the controlelr ?
reg oki6295_irq_n;
reg sub2main_pending;

// XXX WRITE TO MAIN CPU DATA BUS DIRECTLY! MDB ! 
//reg [15:0] z80_sound_latch_0; 
//reg [15:0] z80_sound_latch_1; 
//reg [15:0] z80_sound_latch_2;

//sound_cs_2 ? z80_sound_latch_0 : 
//sound_cs_3 ? z80_sound_latch_1 :
//sound_cs_5 ? z80_sound_latch_2 :

// XXX
// WRITE DIRECTLY TO MDB AS SHARE DATABUS OR WRITE TO A FAKE DATABUS ? 
// HOW CPU NOW WE CAN WRITE ? WE NEED TO CHECK MWRLB ?
//wire  m68k_sound_cs_2;
//wire  m68k_sound_cs_4;
//wire  m68k_sound_cs_6;
      //sound_cs_2 <= (cpu_a[23:0] == 24'h80004);
      //sound_cs_3 <= (cpu_a[23:0] == 24'h80006);
      //sound_cs_4 <= (cpu_a[23:0] == 24'h80008);
      //sound_cs_5 <= (cpu_a[23:0] == 24'h8000a);
      //sound_cs_6 <= (cpu_a[23:0] == 24'h8000c);


always @(posedge clk) begin //XXX speed must be same than 68k din ?
  if (rst) begin
    //z80_sound_latch_0 <= 16'b0;
    //z80_sound_latch_1 <= 16'b0;
    sub2main_pending  <= 1'b0;
    oki6295_irq_n     <= 1'b1;
    end
  else if (CLK_3_6) begin // ?
    // send z80 data to 68k cpu
    if (~SEI0100_CS_N && (SA[4:0] == 5'h18)) 
      //z80_sound_latch_0 <= {8'b0, SD_OUT[7:0]};
      MDB_IN[7:0] <= SD_OUT[7:0]; //xxx put back or use latch + cs ?

    if (~SEI0100_CS_N && (SA[4:0] == 5'h19))
      //z80_sound_latch_1 <= {8'b0, SD_OUT[7:0]};
      MDB_IN[7:0] <= SD_OUT[7:0]; //XXX put back

    // data from z80 is pending read from 68k
    if (~SEI0100_CS_N && (SA[4:0] == 5'h00)) begin
      //z80_sound_latch_2 <= 16'b0;
      MDB_IN[7:0] <= 8'b0; //XXX put back ?
      sub2main_pending <= 1'b1;
      end

    //else if (m68k_sound_cs_6 == 1'b1 || m68k_sound_cs_2 == 1'b1) begin //? it's used as cpu din too
    else if (~MUSIC & (MAB[3:1] == 3'd6 || MAB[3:1] == 3'd2)) begin //? it's used as cpu din too
      //z80_sound_latch_2 <= 16'b1;
      MDB_IN[7:0] <= 8'b1; // XXX put back 
      sub2main_pending <= 1'b0;
      end

    // main cpu assert irq for oki6295
    //if (m68k_sound_cs_4 == 1'b1) 
    if (~MUSIC & (MAB[3:1] == 3'd4)) 
      oki6295_irq_n <= 1'b0; 
    else
      oki6295_irq_n <= 1'b1;

    end
end

endmodule
