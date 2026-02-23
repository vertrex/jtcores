module cabal_main(
  // Clock
  input             clk,
  input             rst,
  input             P6M,
  input             N6M,

  // Video
  input             LVBL, //cpu IPL0n triggered by 82s135 pin 11 
  input             HBLB, 
  input             INT_T, 

  // Input
  input      [1:0]  start_button,
  input      [6:0]  joystick1,
  input      [6:0]  joystick2,

  input      [31:0] dipsw,
  input     dip_pause,     
  input             service,

  input      [15:0] cpu_rom_data,
  input             cpu_rom_ok,
  output     [17:1] cpu_rom_addr,
  output reg        cpu_rom_cs,

  //Shared video RAM 
  input      [10:1] palette_ram_addr,
  output     [15:0] palette_ram_out,

  input      [10:1] char_ram_addr,
  output     [15:0] char_ram_out,

  input       [9:1] bk_ram_addr,
  output     [15:0] bk_ram_out,

  input      [10:1] sprite_ram_addr,
  output     [15:0] sprite_ram_out

  //XXX scroll & sound latch 
);

wire p1_right    = joystick1[0];
wire p1_left     = joystick1[1];
wire p1_down     = joystick1[2];
wire p1_up       = joystick1[3];
wire p1_button1  = joystick1[4];
wire p1_button2  = joystick1[5];
wire p1_start    = start_button[0];

wire p2_right    = joystick2[0];
wire p2_left     = joystick2[1];
wire p2_down     = joystick2[2];
wire p2_up       = joystick2[3];
wire p2_button1  = joystick2[4];
wire p2_button2  = joystick2[5];
wire p2_start    = start_button[1];

///////// Motorola 68K CPU ///////////////////////////
//
// 
//
wire cpu_wr_n;              // Read = 1, Write = 0
wire cpu_as_n;              // Address strobe
wire cpu_lds_n;             // Lower byte strobe
wire cpu_uds_n;             // Upper byte strobe
(*keep*) wire [2:0]cpu_fc;  // Processor state

// CPU buses
wire [15:0] cpu_din;
wire [15:0] cpu_dout;

wire [23:0] cpu_a;    
assign cpu_a[0] = 0;   // odd memory address should cause cpu exception

wire bg_n;             // Bus grant
wire cen10;
wire cen10b;
wire dtack_n;
wire int1;
wire ipl0_n;
wire br_n; 
wire berr_n;
wire vpa_n; 
wire bgack_n; 

fx68k fx68k (
    .clk(clk),    // Input clock
    .enPhi1(cen10), // cpu clock 
    .enPhi2(cen10b), 

    .extReset(rst),
    .pwrUp(rst),
    .HALTn(dip_pause), //rst

    //SYSTEM CONTROL 
    .BERRn(1'b1),
    .oRESETn(), 
    .oHALTEDn(), 

    //ADDRESS BUS 
    .eab(cpu_a[23:1]), //output A23-A0 : 24bits address bus

    //DATA BUS (originally one INOUT bus) 
    .iEdb(cpu_din),    // input D15-D0 : 16 bits cpu bus data in
    .oEdb(cpu_dout),   // input D15-D0 : 16 bits cpu bus data out 
    
    //ASYNCHRONOUS BUS CONTROL 
    .ASn(cpu_as_n),    // output : address strobe, tell the memory device that the address inputs are valid. Upon receiving this signal the selected memory device starts the memory access (read/write) indicated by its other inputs.
    .eRWn(cpu_wr_n),     // ouput  : write=0, read =1 
    .UDSn(cpu_uds_n),  // ouput  : upper byte strobe
    .LDSn(cpu_lds_n),  // output : lower byte strobe
    .DTACKn(dtack_n),  // input  : data transfer ack
    //.DTACKn(1'b0),  // input  : data transfer ack // DTACK GROUNDED XXX

    //BUS ARBITRATION CONTROL
    //.BRn(1'b1),           // When a DMA transfer is initiated, the DMA controller sends a Bus Request (BR) signal to the CPU.
    .BRn(br_n),        // input  : bus request
    .BGn(bg_n),        // output : bus grant   An output signal from the CPU indicating that it has granted control of the bus to another device. 
    .BGACKn(bgack_n),  // input  : Bus grant ack //didn't work 
    //.BGACKn(1'b1),  // input  : Bus grant ack  An input signal to the CPU indicating that the requesting device has taken control of the bus. 

    // PERIPHERAL CONTROL
    .E(),              // output : cpu enable 
    .VMAn(),           // output : valid pheripheral memory address
    .VPAn(vpa_n),     // valid peripheral address detected   XXX get periiph input

    /// PROCESSOR STATUS 
    .FC0(cpu_fc[0]),   // output 
    .FC1(cpu_fc[1]),   // output 
    .FC2(cpu_fc[2]),   // output 

    //INTERUPT CONTROL 
    .IPL0n(ipl0_n),      //int @vblank
    .IPL1n(1'b1),
    .IPL2n(1'b1)  
);

///////// 68K interrupt ///////////////////////////
//
// interrupt at each vblank 
// 59.61hz,59.60hz verified on board
// interrupt routine fill char, bk1, bk1, palette ram
// during dip-switch char ram is zero filled @vblank
// ram drawing and filling is longer than vblank period 
//
wire int_clk;
wire int_a, int_n; 

LS74 u_21R_1(
  .CLK(clk),
  .CEN(HBLB), //HBLB ? 
  .D(INT_T),  //INT_T VBLANK BEFORE IS THAT EQUAL ?
  .PRE(1'b1),
  .CLR(1'b1),
  .Q(int_clk),
  .QN(int_n)
);

LS74 u_21R_2(
  .CLK(clk),
  .CEN(int_clk),
  .D(1'b0),
  .PRE(vpa_n),
  .CLR(1'b1),
  .Q(int_a),
  .QN()
);

assign vpa_n= ~((~cpu_as_n) & (~cpu_lds_n) & cpu_wr_n & cpu_fc[0] & cpu_fc[1] & cpu_fc[2]);  // from o19_n
//assign bgack_n = (MBUSDIR & OBUSDIR); 
assign bgack_n = 1'b1;
//assign br_n = (MBUSRQ & OBUSRQ); 
assign br_n = 1'b1;

//74LS32
assign ipl0_n = (int_a | int_n);

///////// 68K dtack //////////////////////////////
//
// handle 68k clock and data trasnfer acknowledge
// bus is busy if cpu rom is not available 
//
localparam [3:0] cen_num =  4'd5;
localparam [4:0] cen_den = 5'd24;

wire bus_cs  = cpu_rom_cs;
wire bus_busy = (cpu_rom_cs & ~cpu_rom_ok);//  | ~br_n; //| BUSOPN;

jtframe_68kdtack_cen  u_dtack(
    .rst        (rst),     //INPUT 
    .clk        (clk),     //INPUT 
    .cpu_cen    (cen10),   //INPUT 
    .cpu_cenb   (cen10b),  //INPUT 
    .bus_cs     (bus_cs),  //INPUT 
    .bus_busy   (bus_busy), //INPUT 
    .bus_legit  (1'b0),    //INPUT 
    .bus_ack    (1'b0), //XXX new ?
    .ASn        (cpu_as_n),//INPUT 
    .DSn        ({cpu_uds_n, cpu_lds_n}), //INPUT 
    .num        (cen_num),  //INPUT 
    .den        (cen_den),  //INPUT 
    .DTACKn     (dtack_n),  //OUTPUT 
    //otherwise it stop working 
    //the file with old version temporarly 
    .wait2      (1'b0),
    .wait3      (1'b0),
    // unused
    .fave       (),
    .fworst     ()
    //.frst(1'b0) //XXX added in jtcores at some point, sound doesn't work 
);

assign cpu_rom_addr[17:1] = cpu_a[17:1];
// XXX todo 
//assign cpu_rom_cs = 1'b1;
reg dsw_cs, in2_cs, inputs_cs, ram_cs;
reg char_cs, bg_cs, palette_cs, sprite_cs;
//reg 

//mame based 
always @(*) begin
      cpu_rom_cs = ~cpu_as_n & (cpu_a[23:1] < 23'h20000); //<= h40000 /2
      ram_cs = ~cpu_as_n & (cpu_a[23:1] >= 23'h20000 && cpu_a[23:1] < 23'h28000);
      //IO
      dsw_cs     = ~cpu_as_n & (cpu_a[23:1] == 23'h50000); // && cpu_a[23:1] < 24'ha0001); //2 
      in2_cs  = ~cpu_as_n & (cpu_a[23:1] == 23'h50004); // && cpu_a[23:1] < 24'hc0005); //2 
      inputs_cs  = ~cpu_as_n & (cpu_a[23:1] == 23'h50008); // && cpu_a[23:1] < 24'hc0003); //2 
      // gfx bus according to MAME 
      //0x60000 - 0x607ff   VRAM (Tiles) aka colorram //XXX certainly DMA not shared ! 
      sprite_cs = ~cpu_as_n & (cpu_a[23:1] >= 23'h21c00 && cpu_a[23:1] < 23'h22000);
      char_cs = ~cpu_as_n & (cpu_a[23:1] >= 23'h30000 && cpu_a[23:1] < 23'h30400);
      //0x80000 - 0x803ff   VRAM (Background) aka videoram
      bg_cs = ~cpu_as_n & (cpu_a[23:1] >= 23'h40000 && cpu_a[23:1] < 23'h40200);
      //0xe0000 - 0xe07ff   COLORRAM (----BBBBGGGGRRRR)
      palette_cs = ~cpu_as_n & (cpu_a[23:1] >= 23'h70000 && cpu_a[23:1] < 23'h70400);
      //0xe8000 - 0xe800f   Communication with sound CPU (also coins)
      //XXX 
      //sprite_cs mame sometimes say 0x43bff or 0x43fff for the end ?? 
end

// XXX TODO BUS CS 
assign cpu_din = cpu_rom_cs ? cpu_rom_data[15:0] :
                 ram_cs ? ram_do[15:0] : 
                 dsw_cs ? dipsw[15:0] : //XXX if not set we go to a 99 lies screen directly 
                 inputs_cs  ? {1'b1,1'b1,p2_button2,p2_button1,p2_right,p2_left,p2_down,p2_up,
                               1'b1,1'b1,p1_button2,p1_button1,p1_right,p1_left,p1_down,p1_up} :

                 //needed ?
                 palette_cs ? palette_do[15:0] : 
                 //sprite_cs ? sprite_do[15:0] : 
                 char_cs ? char_do[15:0] :
                 bg_cs ? bg_do[15:0] : 
                 16'd0;

wire [15:0] ram_do;

wire MWRMB   = ~((~cpu_as_n) & (~cpu_uds_n) & (~cpu_wr_n));
wire MWRLB   = ~((~cpu_as_n) & (~cpu_lds_n) & (~cpu_wr_n));

jtframe_ram16 #(.AW(15)) u_cpu_ram(
    .clk(clk),
    //.addr(MAB[15:1]),  //ENABLE VIA DMARD ? 
    .addr(cpu_a[15:1]),  //ENABLE VIA DMARD ? 
    .data(cpu_dout[15:0]), //MDB_OUT  // 
    //.we({~RAM & ~MWRMB, ~RAM & ~ MWRLB}),
    .we({ram_cs && !cpu_wr_n && !cpu_uds_n, ram_cs && !cpu_wr_n && !cpu_lds_n}),
    //.we({ram_cs & ~MWRMB, ram_cs & ~ MWRLB}),
    .q(ram_do[15:0])  //MDB_in ? //remove from data bus input if set here 
);

// XXX PLUG GFX RAM ACCORDING TO MAME 
// video ram (2048) 
wire [15:0] char_do; 

jtframe_dual_ram16 #(.AW(10)) u_char_ram(
  .clk0(clk),
  .data0(cpu_dout[15:0]),
  .addr0(cpu_a[10:1]),
  .we0({char_cs && !cpu_wr_n && !cpu_uds_n, char_cs && !cpu_wr_n && !cpu_lds_n}),
  .q0(char_do), 

  .clk1(clk),
  .data1(),
  .addr1(char_ram_addr),
  .we1(2'b0),
  .q1(char_ram_out)
);

wire [15:0] bg_do;

// xxx background ram 
// 1024 (strange that's the only 1024)  
jtframe_dual_ram16 #(.AW(9)) u_bk_ram(
  .clk0(clk), 
  .data0(cpu_dout[15:0]),
  .addr0(cpu_a[9:1]),
  .we0({bg_cs && !cpu_wr_n && !cpu_uds_n, bg_cs && !cpu_wr_n && !cpu_lds_n}),
  .q0(bg_do), 

  .clk1(clk),
  .data1(),
  .addr1(bk_ram_addr),
  .we1(2'b0),
  .q1(bk_ram_out)

);

// palette ram 
// 2048 
wire [15:0] palette_do; 

jtframe_dual_ram16 #(.AW(10)) u_palette_ram(
  .clk0(clk), 
  .data0(cpu_dout[15:0]),
  .addr0(cpu_a[10:1]),
  .we0({palette_cs && !cpu_wr_n && !cpu_uds_n, palette_cs && !cpu_wr_n && !cpu_lds_n}),
  //.we0(palette_cs && !cpu_wr_n),
  .q0(palette_do), 

  .clk1(clk),
  .data1(),
  .addr1(palette_ram_addr),
  .we1(2'b0),
  .q1(palette_ram_out)
);



// XXX sprite ram 
// 2048 (sometimes mame say less ?)
// 
wire [15:0] sprite_do;

jtframe_dual_ram16 #(.AW(10)) u_sprite_ram(
  .clk0(clk), 
  .data0(cpu_dout[15:0]),
  .addr0(cpu_a[10:1]),
  .we0({sprite_cs && !cpu_wr_n && !cpu_uds_n, sprite_cs && !cpu_wr_n && !cpu_lds_n}),
  //.we0(sprite_cs && !cpu_wr_n),
  .q0(sprite_do), 

  .clk1(clk),
  .data1(),
  .addr1(sprite_ram_addr),
  .we1(2'b0),
  .q1(sprite_ram_out)
);

/* 
[of which: 0x43800 - 0x43fff   VRAM (Sprites)]
0x60000 - 0x607ff   VRAM (Tiles)
0x80000 - 0x803ff   VRAM (Background)
0xa0000 - 0xa000f   Input Ports
0xc0040 - 0xc0040   Watchdog??
0xc0080 - 0xc0080   Screen Flip (+ others?)
0xe0000 - 0xe07ff   COLORRAM (----BBBBGGGGRRRR)
0xe8000 - 0xe800f   Communication with sound CPU (also coins)

VRAM (Background)
0x80000 - 0x801ff  (16x16 of 16x16 tiles, 2 bytes per tile)
0x80200 - 0x803ff  unused foreground layer??

VRAM (Text)
0x60000 - 0x607ff  (32x32 of 8x8 tiles, 2 bytes per tile)

VRAM (Sprites)
0x43800 - 0x43bff  (128 sprites, 8 bytes every sprite)
*/


endmodule
