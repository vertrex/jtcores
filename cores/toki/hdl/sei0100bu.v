// 2151/5205 controller
// SEI0100BU - Custom chip marked 'SEI0100BU YM3931' (SDIP64)
//
// PCB provenance: opaque U129 on sheet 12.  This module models the externally
// observable Seibu command latches, pending flags, IM0 interrupt vectors, bank
// select and coin outputs.  The custom IC's internal gates are unavailable;
// the explicit state below is protocol behavior inferred from the program and
// verified FPGA operation, not extra board-visible functionality.  B1 and
// CLK_3_6 are genuine PCB pins but their internal functions are not recovered;
// bus strobes are sampled in the 48 MHz domain so a complete 68000 access is
// not missed between clock-enable pulses.
// REVIEW: Toki connects a YM3812 and MSM6295; "2151/5205 controller" above is
// the original schematic description rather than the populated sound devices.
// REVIEW: PLD23's B1 equation strongly identifies it as the active-low U129
// shared Z80-data-bus output enable (schematic SD0-SD7). This is
// schematic-derived, but not trace-proven.

module sei0100bu
(
  input         clk,
  // REVIEW: clk is the FPGA implementation clock and is not a physical U129 pin.
  input         rst, //pin 33
  // REVIEW: PCB pin 33 is /SYS RESET; rst is its active-high RTL equivalent.
  input         MUSIC,   //pin 56   
  input         MWRLB,   //pin 59 
  input         MRDLB,   //pin 60 ?
  input   [3:1] MAB,     //pin 56-58
  // REVIEW: exact MAB pins are MAB1=58, MAB2=57 and MAB3=55; pin 56 is MUSIC.
  input   [7:0] MDB_OUT,     //pin 24-31 
  output  [7:0] MDB_IN,     //pin 24-31 
  // REVIEW: MDB is one bidirectional PCB bus, split into IN/OUT for FPGA logic.
  //pin 38, 34 1'b0 
  input         irq_ack_n, //pin 54,  PLD23 B3 
  input         IRQ3812,  //pin 63
  input         CLK_3_6,//pin 49
  input         COIN1,  //pin 36 
  input         COIN2, //pin 37
  input         SEI0100_CS_N, //pin 41, PLD23 B0
  input         SWRB, //pin 47 
  input         SEI0100_Z80_DATA_OE_N, //pin 48, PLD23 B1 (bit 3 low ?) >9 == for for CS? (FOR SD IN) addr > 9
  // REVIEW: renamed from B1; inferred active-low enable for U129 to drive the
  // Z80 data bus.
  input   [4:0] SA, //pin 42-46 //32 value + sei0100_cs -> z80_cs value!! (max 4001b  0x1b == 27) 

  //output 
  //pin nc 2-18,62 
  output reg    COUNTER1, //pin 39
  output reg    COUNTER2, //pin 40
  output        Z80_INT, //pin 23
  output reg    CS3812, //pin 61
 
  input   [7:0] SD_OUT, //read data from CPU ! 
  output  [7:0] SD_IN,//19,50,20,51,21,52,22,53  //reg?
  // REVIEW: SD is the PCB label for the Z80 sound-data bus, split into IN/OUT
  // for FPGA logic.

  output reg    BANK_SELECTED //pin 35 (sa15 on or off for bank ! )
  //bank_rom_addr <= {bank_selected, SA[14:0]}
);

wire main_write = ~MUSIC && ~MWRLB;
wire main_read  = ~MUSIC && ~MRDLB;
wire sub_write  = ~SEI0100_CS_N && ~SWRB;
wire sub_read   = ~SEI0100_CS_N && ~SEI0100_Z80_DATA_OE_N;

always @(posedge clk) begin
    if (rst)
      BANK_SELECTED <= 1'b0;
    // REVIEW: the 64 KiB EPROM is exposed as two 32 KiB banks in the Z80
    // 0x8000-0xffff window; the three original exploratory comments follow.
    // bank size is 0x10000 
    // z80 address from 0x8000  to 0x10000 is read directly from the rom 
    // z80 address from 0x10000 to 0x18000 is read after switching bank
    //if (SA[15:0] == 16'h4007) // switch bank usage  //bank_rom_cs? PLD232 
    // XXX B1 ? 
    else if (sub_write && SA[4:0] == 5'd7)
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
always @(*) begin
    // IO
    // 0b1000  / 0b1001 (SA[0])
    CS3812 = ~(~SEI0100_CS_N && (SA[4:0] == 5'h08 || SA[4:0] == 5'h09));
end 

reg [7:0] m68k_sound_latch_0;
reg [7:0] m68k_sound_latch_1;
reg       main2sub_pending;
reg       sub2main_pending;

////// Z80 databus input   /////////////////////// 
//
//  IRQ use z80 interrupt mode 0 :
//  After interrupt is asserted, the cpu signal it's 
//  ready by putting iorq and m1 high 
//  REVIEW: on a Z80 interrupt-acknowledge cycle /IORQ and /M1 are both low.
//  it then read on the databus 
//  this data is directly executed by the cpu as an opcode 
//
//  - ym3821 assert irq and put 0xd7 (rst10) on the bus 
//  REVIEW: ym3821 above is the YM3812.
//  - 68k main cpu assert irq and put 0xdf (rst18) on the bus 
// 
//  both interrupt are needed to handle sound and coin input
//
reg irq_rst10;
reg irq_rst18;
reg irq_service_10;
reg irq_service_18;
reg irq_ack_active;
reg irq_ack_rst10;
reg irq_ack_rst18;

wire rst10_waiting = irq_rst10 && !irq_service_10;
wire rst18_waiting = irq_rst18 && !irq_service_18;
wire vector_rst18 = irq_ack_active ? irq_ack_rst18 : rst18_waiting;
wire vector_rst10 = irq_ack_active ? irq_ack_rst10 :
                    (!rst18_waiting && rst10_waiting);

// The two interrupt sources are independent.  RST18 has vector priority, but
// it must never cancel an FM RST10: dropping one YM3812 timer interrupt is
// enough to stop the music stream.  Keep the selected vector stable for the
// complete Z80 acknowledge cycle and mask each source only until its explicit
// end-of-interrupt write at 0x4001/2/3.
assign Z80_INT = ~(rst10_waiting || rst18_waiting);

assign SD_IN[7:0] =
                    !irq_ack_n && vector_rst18 ? 8'hdf :
                    !irq_ack_n && vector_rst10 ? 8'hd7 :
                    !irq_ack_n                  ? 8'h00 :
                    (sub_read && (SA[4:0] == 5'h10)) ? m68k_sound_latch_0 :
                    (sub_read && (SA[4:0] == 5'h11)) ? m68k_sound_latch_1 :
                    (sub_read && (SA[4:0] == 5'h12)) ? {7'b0, sub2main_pending} :
                    (sub_read && (SA[4:0] == 5'h13)) ? {6'b0, ~COIN2, ~COIN1} :
                    8'hff;

always @(posedge clk) begin
  if (rst) begin
    irq_rst10     <= 1'b0;
    irq_rst18     <= 1'b0;
    irq_service_10 <= 1'b0;
    irq_service_18 <= 1'b0;
    irq_ack_active <= 1'b0;
    irq_ack_rst10 <= 1'b0;
    irq_ack_rst18 <= 1'b0;
  end else begin
    // RST10 follows the active-low YM3812 IRQ pin.  Its service mask is kept
    // separately so a still-asserted timer request can reappear after EOI.
    irq_rst10 <= ~IRQ3812;

    if (!irq_ack_n && !irq_ack_active) begin
      irq_ack_active <= 1'b1;
      irq_ack_rst18 <= rst18_waiting;
      irq_ack_rst10 <= !rst18_waiting && rst10_waiting;
    end else if (irq_ack_n && irq_ack_active) begin
      irq_ack_active <= 1'b0;
      if (irq_ack_rst18) begin
        irq_rst18 <= 1'b0;
        irq_service_18 <= 1'b1;
      end else if (irq_ack_rst10) begin
        irq_service_10 <= 1'b1;
      end
      irq_ack_rst10 <= 1'b0;
      irq_ack_rst18 <= 1'b0;
    end

    if (sub_write && SA[4:0] == 5'h01)
      irq_service_18 <= 1'b0;
    if (sub_write && SA[4:0] == 5'h02)
      irq_service_10 <= 1'b0;
    if (sub_write && SA[4:0] == 5'h03)
      irq_service_18 <= 1'b0;

    if (main_write && MAB[3:1] == 3'd4)
      irq_rst18 <= 1'b1;
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
  end else begin
    // The custom controller sees the asynchronous 68K write strobe directly.
    // Sampling MUSIC only on CLK_3_6 can miss a complete main-CPU bus cycle.
    if (main_write && MAB[3:1] == 3'd0)
      m68k_sound_latch_0[7:0] <= MDB_OUT[7:0];
    if (main_write && MAB[3:1] == 3'd1)
      m68k_sound_latch_1[7:0] <= MDB_OUT[7:0];
  end
end

////// SOUND ////////////////////
//
// sound latch
//
// Main/sub pending flags follow the documented Seibu handshake. A Z80 write
// REVIEW: "documented" here means software/MAME-derived protocol behavior;
// U129's internal implementation is not visible in the PCB schematic.
// to 0x4000 announces its response; main writes to offset 2 or 6 acknowledge
// that response and mark the next command pair pending.
always @(posedge clk) begin
  if (rst) begin
    main2sub_pending <= 1'b0;
    sub2main_pending <= 1'b0;
  end else begin
    if (sub_write && SA[4:0] == 5'h00) begin
      main2sub_pending <= 1'b0;
      sub2main_pending <= 1'b1;
    end
    if (main_write &&
        (MAB[3:1] == 3'd6 || MAB[3:1] == 3'd2)) begin
      sub2main_pending <= 1'b0;
      main2sub_pending <= 1'b1;
    end
  end
end

reg [7:0] z80_sound_latch_0; 
reg [7:0] z80_sound_latch_1; 

// 
always @(posedge clk) begin //XXX speed must be same than 68k din ?
  if (rst) begin
    z80_sound_latch_0 <= 8'b0;
    z80_sound_latch_1 <= 8'b0;
  end else begin
    // send z80 data to 68k cpu
    if (sub_write && SA[4:0] == 5'h18)
      z80_sound_latch_0 <= SD_OUT[7:0]; //xxx put back or use latch + cs ?

    if (sub_write && SA[4:0] == 5'h19)
      z80_sound_latch_1 <= SD_OUT[7:0]; //XXX put back
  end
end

always @(posedge clk) begin
  if (rst) begin
    COUNTER1 <= 1'b0;
    COUNTER2 <= 1'b0;
  end else if (sub_write && SA[4:0] == 5'h1b) begin
    // REVIEW: 0x401b controls the two physical coin-meter outputs.
    COUNTER1 <= SD_OUT[0];
    COUNTER2 <= SD_OUT[1];
  end
end

assign MDB_IN[7:0] = // low word 
                     (main_read && (MAB[3:1] == 3'd2)) ? z80_sound_latch_0[7:0] :
                     // high word
                     (main_read && (MAB[3:1] == 3'd3)) ? z80_sound_latch_1[7:0] :
                     // main-to-sub command pair pending
                     (main_read && (MAB[3:1] == 3'd5)) ? {7'b0, main2sub_pending} :
                     8'hff;
endmodule
