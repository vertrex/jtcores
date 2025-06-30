////////// main module  //////////////////////
//
//  - Motorola 68k main cpu @10mhz 
//  - cpu address bus 
//  - cpu 2*32kx8 ram
//  - palette / video / bk1 / bk2 / obj ram
//  - scrolling & sound latch
// 
module toki_main(
  input             rst,

  // Clock
  input             clk,
  input             P6M,
  input             N6M,

  // Video
  input             LVBL, //cpu IPL0n triggered by 82s135 pin 11 
  input             HBLB, 
  input             INT_T, 
  input       [8:0] hpos,
  input       [8:0] vpos,

  // Input
  input      [1:0]  start_button,
  input      [5:0]  joystick1,
  input      [5:0]  joystick2,

  input      [31:0] dipsw,
  input             dip_pause,     
  input             service,

  input      [15:0] cpu_rom_data,
  input             cpu_rom_ok,
  output     [18:1] cpu_rom_addr,
  output reg        cpu_rom_cs,

  input      [10:1] obj_addr,
  output     [15:0] obj_out,

  output  reg signed [8:0] bk1_scroll_x,
  output  reg signed [8:0] bk1_scroll_y,
  output  reg signed [8:0] bk2_scroll_x,
  output  reg signed [8:0] bk2_scroll_y,

  output  reg       bg_order,

  output reg        sound_cs_2, 
  output reg        sound_cs_4,
  output reg        sound_cs_6,

  output reg [15:0] m68k_sound_latch_0,
  output reg [15:0] m68k_sound_latch_1,

  input      [15:0] z80_sound_latch_0,
  input      [15:0] z80_sound_latch_1,
  input      [15:0] z80_sound_latch_2,

  output            S1MASK,
  output            S2MASK,
  output            OBJMASK,
  output            S4MASK,
  output            PRIOR_A,
  output            PRIOR_B,
  output            HREV,
  output            YREV,

  output     [12:1] KDA,
  output     [15:0] MDB,
  output            DMSL_S1,
  output            DMSL_S2,
  output            DMSL_S4,
  output            DMSL_GL,
  output            WRN6M
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
reg  [15:0] cpu_din;
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

fx68k fx68k (
    .clk(clk),    // Input clock
    .enPhi1(cen10), // cpu clock 
    .enPhi2(cen10b), 

    .extReset(rst),
    .pwrUp(rst),
    .HALTn(dip_pause),

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
    //.DTACKn(dtack_n),  // input  : data transfer ack
    .DTACKn(dtack_n),  // input  : data transfer ack // DTACK GROUNDED

    //BUS ARBITRATION CONTROL
    //.BRn(1'b1),           // When a DMA transfer is initiated, the DMA controller sends a Bus Request (BR) signal to the CPU.
    .BRn(br_n),        // input  : bus request
    .BGn(bg_n),        // output : bus grant   An output signal from the CPU indicating that it has granted control of the bus to another device. 
    //.BGACKn(bgack_n),  // input  : Bus grant ack //didn't work 
    .BGACKn(1'b1),  // input  : Bus grant ack  An input signal to the CPU indicating that the requesting device has taken control of the bus. 

    // PERIPHERAL CONTROL 
    .E(),              // output : cpu enable 
    .VMAn(),           // output : valid pheripheral memory address
    .VPAn(vpa_n),     // output :valid peripheral address detected  

    /// PROCESSOR STATUS 
    .FC0(cpu_fc[0]),   // output 
    .FC1(cpu_fc[1]),   // output 
    .FC2(cpu_fc[2]),   // output 

    //INTERUPT CONTROL 
    .IPL0n(ipl0_n),      //int @vblank
    .IPL1n(1'b1),
    .IPL2n(1'b1)  
);

// 74LS244P 17K,17P, 22K
wire [17:1] MAB;

assign MAB[17:1] = { cpu_a[17], (BUSOPN == 1'b0) ? cpu_a[16:1] : 16'bz };

// 74LS246
// bidrectional bus
wire [15:0] MDB_out; 
wire [15:0] MDB_in; 

assign MDB_in[7:0]  = (!cpu_lds_n && !MEMDIR) ? cpu_din[7:0] : 8'bz; //memory -> cpu 
assign MDB_in[15:8] = (!cpu_uds_n && !MEMDIR) ? cpu_din[15:8] : 8'bz; // // B → A



assign MDB_out[7:0]  = (!cpu_lds_n && MEMDIR) ? cpu_dout[7:0] : 8'bz;  //cpu  -> memory 
assign MDB_out[15:8] = (!cpu_uds_n && MEMDIR) ? cpu_dout[15:8] : 8'bz; // ;  // A → B
//assign MDB_out[7:0]  = (!cpu_lds_n && MEMDIR) ? ram_do[7:0] : 8'bz;  //cpu  -> memory 
//assign MDB_out[15:8] = (!cpu_uds_n && MEMDIR) ? ram_do[15:8] : 8'bz; // ;  // A → B

// XXX ! 
//assign MDB[15:0] = MDB_out[15:0];
//assign MDB[15:0] = ram_do[15:0];

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
  .CLK(HBLB), //HBLB ? 
  .D(INT_T),  //INT_T VBLANK BEFORE IS THAT EQUAL ?
  .PRE(1'b1),
  .CLR(1'b1),
  .Q(int_clk),
  .QN(int_n)
);

LS74 u_21R_2(
  .CLK(int_clk),
  .D(1'b0),
  .PRE(vpa_n),
  .CLR(1'b1),
  .Q(int_a),
  .QN()
);

//74LS32
assign ipl0_n = (int_a | int_n);

///////// 68K dtack //////////////////////////////
//
// handle 68k clock and data trasnfer acknowledge
// bus is busy if cpu rom is not available 
//

// cpu clock 48*5/24 => 10mhz 
localparam [3:0] cen_num =  4'd5;
localparam [4:0] cen_den = 5'd24;
/*
cnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( rst ) cencnt <= 0;
    if( over || rst || halt ) begin
        cpu_cen  <= risefall;
        cpu_cenb <= ~risefall;
        risefall <= ~risefall;n_den = 5'd24;*/

// XXX USE PLD  INSTEAD
wire bus_cs  = cpu_rom_cs;
//  XXX in the board DTACK is grounded and rom is not checked 
//  but it seems rom in sdram is too slow so we need to check for it 
//  to avoid cpu having problem reading the rom 
//  we also need to stop the CPU for dma 
wire bus_busy = (cpu_rom_cs & ~cpu_rom_ok)  | ~br_n | BUSOPN;

jtframe_68kdtack_cen  u_dtack(
    .rst        (rst),     //INPUT 
    .clk        (clk),     //INPUT 
    .cpu_cen    (cen10),   //INPUT 
    .cpu_cenb   (cen10b),  //INPUT 
    .bus_cs     (bus_cs),  //INPUT 
    .bus_busy   (bus_busy), //INPUT 
    .bus_legit  (1'b0),    //INPUT 
    .ASn        (cpu_as_n),//INPUT 
    .DSn        ({cpu_uds_n, cpu_lds_n}), //INPUT 
    .num        (cen_num),  //INPUT 
    .den        (cen_den),  //INPUT 
    .DTACKn     (dtack_n),  //OUTPUT 
    .wait2      (1'b0),
    .wait3      (1'b0),
    // unused
    .fave       (),
    .fworst     ()
);

///////// 68k bus mapping  ////////////////////
//
// 0x000000, 0x05ffff : rom        (393216)(ro)
// 0x060000, 0x06d7ff : cpu ram     (55296)(rw)
// 0x06d800, 0x06dfff : objram    (2048)(rw) 
// 0x06e000, 0x06e7ff : palette      (2048)(rw)
// 0x06e800, 0x06efff : bk1 vram     (2048)(wo) 
// 0x06f000, 0x06f7ff : bk2 vram     (2048)(wo)
// 0x06f800, 0x06ffff : videoram     (2048)(wo)
// gap 
// 0x080000, 0x08000d : sound latch        (rw) 
// gap  
// 0x0a0000, 0x0a005f : scroll latch       (wo)
// gap 
// 0x0c0000, 0x0c0001 : dip-switch port    (ro) 
// 0x0c0002, 0x0c0003 : input port         (ro)
// 0x0c0004, 0x0c0005 : system port        (ro) 
//
//reg ram_cs, obj_cs, palette_cs, bk1_cs, bk2_cs, vram_cs, 
reg obj_cs, scroll_cs;
reg dsw_cs, inputs_cs, system_cs;
reg sound_cs_3, sound_cs_5;

assign cpu_rom_addr[18:1] = cpu_a[18:1];
//assign cpu_rom_cs = ~ROM0 | ~ROM1; //1'b1 ? doesnt work

// XXX page3 rev_y & rev_x etc 
always @(*) begin
      cpu_rom_cs = ~cpu_as_n & (cpu_a[23:1] < 23'h30000);
      //video 
      obj_cs  = ~cpu_as_n & (cpu_a[23:1] >= 23'h36c00 && cpu_a[23:1] < 23'h37000); //2048
      //sound latch
      sound_cs_2 = ~cpu_as_n & (cpu_a[23:1] == 23'h40002);
      sound_cs_3 = ~cpu_as_n & (cpu_a[23:1] == 23'h40003);

      sound_cs_4 = ~cpu_as_n & (cpu_a[23:1] == 23'h40004);
      sound_cs_5 = ~cpu_as_n & (cpu_a[23:1] == 23'h40005);
      sound_cs_6 = ~cpu_as_n & (cpu_a[23:1] == 23'h40006);
      //scroll 
      scroll_cs  = ~cpu_as_n & (cpu_a[23:1] >= 23'h50000 && cpu_a[23:1] < 23'h5002f); //96 
      //divide it in sub cs & use it bg scroll 
      //IO
      dsw_cs     = ~cpu_as_n & (cpu_a[23:1] == 23'h60000); // && cpu_a[23:1] < 24'hc0001); //2 
      inputs_cs  = ~cpu_as_n & (cpu_a[23:1] == 23'h60001); // && cpu_a[23:1] < 24'hc0003); //2 
      system_cs  = ~cpu_as_n & (cpu_a[23:1] == 23'h60002); // && cpu_a[23:1] < 24'hc0005); //2 
end


////// 68K databus input   /////////////////////// 
//
// this iS MDB ?  XXX 
// on the original board is done by assignement 
// and tristate 'z 
// try with tristate or assign here 

assign MDB[15:0] = cpu_din; 

//assign cpu_din = (!cpu_uds_n && MEMDIR) ? ram_do[15:0] : 16'bz;

//always @(*) begin
always @(posedge clk, posedge rst) begin
  if(rst) begin 
    cpu_din <= 16'h0000;
    end
  else begin
    if (clk) begin
      cpu_din <=      ~ROM0 | ~ROM1 ? cpu_rom_data[15:0] :  
                 ~RAM       ? ram_do[15:0] :  //& BUSOPN ??
                 dsw_cs     ? dipsw[15:0] : 
                 inputs_cs  ? {1'b1,1'b1,p2_button2,p2_button1,p2_right,p2_left,p2_down,p2_up,
                               1'b1,1'b1,p1_button2,p1_button1,p1_right,p1_left,p1_down,p1_up} :
                 system_cs  ? {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,
                               1'b1,1'b1,1'b1,p2_start,p1_start,1'b1,1'b1,1'b1} : 
                 sound_cs_2 ? z80_sound_latch_0 : 
                 sound_cs_3 ? z80_sound_latch_1 :
                 sound_cs_5 ? z80_sound_latch_2 :
                 16'd0;
             end
           end
end 

///////
// 74LS08 19R page 1
wire OBUSRQ = 1'b0;
//BR is set to 0 to make a cpu BUS request and grant (bg bus grant will be set when cpu is ready for dma) 

// ACTIVE LOW , 0  if DMA is run and obj and CPU must be stopped 
wire OBUSDIR = 1'b1; //OBJ bus direction page 14
// pld21 need it high or nothing will be output as everything check MBUSDIR  & OBUSDIR ?

wire MBUSDIR;
//PLD 20, 22M
// BUSOPN : active low if bus is not use by Memory or Object DMA
wire BUSOPN, MWRLB, MWRMB, MRDLB, MRDMB, BUSAK, bgack_n, vpa_n;

PLD20 PLD20_u(
  .AS_n(cpu_as_n),
  .UDS_n(cpu_uds_n),
  .LDS_n(cpu_lds_n),
  .RW(cpu_wr_n),
  .BG_n(bg_n),  //get reply that the cpu is ready for dma 
  .MBUSDIR(MBUSDIR),
  .OBUSDIR(OBUSDIR),
  .FC0(cpu_fc[0]),
  .FC1(cpu_fc[1]),
  .FC2(cpu_fc[2]),

  .BUSOPN(BUSOPN),
  .MWRLB(MWRLB),
  .MWRMB(MWRMB),
  .MRDLB(MRDLB),
  .MRDMB(MRDMB),
  .BUSAK(BUSAK),
  .BGACK_n(bgack_n), //tell the CPU that device as receive the CPU grant access (bg) , it tell that DMA as starrted in some way
  .VPA_n(vpa_n)
);

//74LS244
wire  MEMDIR = cpu_wr_n;
wire  ROM0, ROM1, RAM, MUSIC, MBUFEN, MBUFDR;
wire  RST_S1H, SEL_S1H, RST_S1Y, SEL_S1Y;
wire  RST_S2H, SEL_S2H, RST_S2Y, SEL_S2Y;
wire  MDMARQ, ODMARQ;
wire  RD_DISPW, RD_PLYER, RD_EXTIF;

ADRS ADRS_u(
  .A(cpu_a[23:17]),
  .MBUSDIR(MBUSDIR),
  .OBUSDIR(OBUSDIR),
  .MEMDIR(MEMDIR),

  .MAB(MAB[6:1]),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .RESET_A(rst),
  .MDB(MDB_out[15:0]),

  .ROM0(ROM0),
  .ROM1(ROM1),
  .RAM(RAM),
  .MUSIC(MUSIC),
  .MBUFEN(MBUFEN),
  .MBUFDR(MBUFDR),

  .RST_S1H(RST_S1H),
  .SEL_S1H(SEL_S1H),
  .RST_S1Y(RST_S1Y),
  .SEL_S1Y(SEL_S1Y),

  .RST_S2H(RST_S2H),
  .SEL_S2H(SEL_S2H),
  .RST_S2Y(RST_S2Y),
  .SEL_S2Y(SEL_S2Y),

  .MDMARQ(MDMARQ),
  .ODMARQ(ODMARQ),

  .RD_DISPW(RD_DISPW),
  .RD_PLYER(RD_PLYER),
  .RD_EXTIF(RD_EXTIF),

  .S1MASK(S1MASK),
  .S2MASK(S2MASK),
  .OBJMASK(OBJMASK),
  .S4MASK(S4MASK),
  .PRIOR_A(PRIOR_A),
  .PRIOR_B(PRIOR_B),

  .HREV(HREV),
  .YREV(YREV)
);

//MDMARQ : Memory DMA Request
//ODMARQ : Object DMA Request 

wire EXH_4_n, MBUSRQ, DMARD; //MBUSDIR

MDMA mdma_u(
  .P6M(P6M),
  .SYS_RESET(rst),
  .MDMARQ(MDMARQ), // Request DMA, start DMA 
  .BUSAK(BUSAK),
  .EXH_4(hpos[2]), //hpos XXX rev version 
  
  .EXH_4_n(EXH_4_n),
  .WRN6M(WRN6M),
  .MBUSRQ(MBUSRQ),
  .MBUSDIR(MBUSDIR),
  .DMSL_GL(DMSL_GL),
  .DMSL_S1(DMSL_S1),
  .DMSL_S2(DMSL_S2),
  .DMSL_S4(DMSL_S4),
  .KDA(KDA[12:1]),
  .MAB(MAB[15:1]),
  .DMARD(DMARD)
);

assign br_n = MBUSRQ;  
//                  '0b101  000'
//                  scrollram[40]&  0x8000 -> bit 16 up ! 
//flip_screen_set((m_scrollram[0x28]&0x8000)==0); 

//////// Scroll /////////////////////////
//
// Scrolling register latch
//


// XXX use sei021bu for scrollng check if cpu_address can be high both at same time 
// durring 1 6mhz clk cycle or how does that work ???
// bk1_scroll_x[8:0] <= { cpu_dout[4], bk1_scroll_x_lo[6:0], bk1_scroll_x_lo[7] };

reg [15:0] bk1_scroll_x_lo = 0;
reg [15:0] bk2_scroll_x_lo = 0;
reg [15:0] bk1_scroll_y_lo = 0;
reg [15:0] bk2_scroll_y_lo = 0;

always @(posedge clk, posedge rst) begin
  if (rst) begin
      bg_order <= 1'b0;
      bk1_scroll_x <= 9'b0;
      bk1_scroll_y <= 9'b0;
      bk2_scroll_x <= 9'b0;
      bk2_scroll_y <= 9'b0;
      end
  else if (clk) begin
    if (scroll_cs == 'b1) begin

      if      (cpu_a[6:1] == 'h6)
        //get 8 byte 
        bk1_scroll_x_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h5)
        //add the 9th bit / sign bit ? 
        bk1_scroll_x[8:0] <= { cpu_dout[4], bk1_scroll_x_lo[6:0], bk1_scroll_x_lo[7] };

      else if (cpu_a[6:1] == 'he)
        bk1_scroll_y_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'hd) 
        bk1_scroll_y[8:0] <= { cpu_dout[4], bk1_scroll_y_lo[6:0], bk1_scroll_y_lo[7] };

      else if (cpu_a[6:1] == 'h16) 
        bk2_scroll_x_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h15) 
        bk2_scroll_x[8:0] <= { cpu_dout[4], bk2_scroll_x_lo[6:0], bk2_scroll_x_lo[7] };

      else if (cpu_a[6:1] == 'h1e)
        bk2_scroll_y_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h1d)
         bk2_scroll_y[8:0] <= { cpu_dout[4], bk2_scroll_y_lo[6:0], bk2_scroll_y_lo[7] };

      else if (cpu_a[6:1] == 'h28) begin
        if ((cpu_dout[15:0] & 16'h100) == 16'h0)
          bg_order <= 1'b0;
        else
          bg_order <= 1'b1;
        end
    end
  end
end

///////// Sound ///////////////
//
// Sound register latch
//
always @(posedge clk, posedge rst) begin
  if (rst) begin
    m68k_sound_latch_0 <= 16'b0;
    m68k_sound_latch_1 <= 16'b0;
    end
  else begin
    if (cpu_a[23:0] == 24'h80000)
      m68k_sound_latch_0[15:0] <= cpu_dout[15:0];
    if (cpu_a[23:0] == 24'h80002)
      m68k_sound_latch_1[15:0] <= cpu_dout[15:0];
  end
end

//////// RAM //////////////////////////
//
// 68k cpu ram (64k)
// 2x Sony58257 - 32kx8 SRAM on PCB
//
wire [15:0] ram_do;

jtframe_ram16 #(.AW(15)) u_cpu_ram(
    .clk(clk),
    .addr(MAB[15:1]), 
    .data(cpu_dout[15:0]), //MDB_out  // 
    .we({~RAM & ~MWRMB, ~RAM & ~ MWRLB}),
    .q(ram_do[15:0])  //MDB_in ? //remove from data bus input if set here 
);

// XXX SPRITE SEEMS TO USE 8 6091 on board ! 

///////// SPRITE RAM //////////
//
// obj ram (2048)
// obj ram is read by the cpu 
// if cpu can't read obj ram content 
// there will be no scrolling during the 'cave screen'
//
wire [15:0] obj_do;

jtframe_dual_ram16 #(.AW(10)) u_obj_ram(
  //.clk0(N6M),
  .clk0(clk), //must be fast here because we use one chips to scan everything 
  //on the real board there is multiple chipset ....
  .data0(cpu_dout[15:0]),
  .addr0(cpu_a[10:1]),
  .we0({obj_cs && !cpu_wr_n && !cpu_uds_n, obj_cs && !cpu_wr_n && !cpu_lds_n}),
  .q0(obj_do),

  .clk1(clk), 
  .data1(),
  .addr1(obj_addr[10:1]),
  .we1(),
  .q1(obj_out)
);

endmodule
