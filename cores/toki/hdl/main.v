////////// main module  //////////////////////
//
//  - Motorola 68k main cpu @10mhz 
//  - cpu address bus 
//  - cpu 2*32kx8 ram
//  - palette / video / bk1 / bk2 / obj ram
//  - scrolling & sound latch
//
// FPGA-only adaptations are deliberately kept at this integration level:
//   * priority muxes replace internal tri-state address/data buses;
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

  output            MUSIC, //active low

  output            S1MASK,
  output            S2MASK,
  output            OBJMASK,
  output            S4MASK,
  output            PRIOR_A,
  output            PRIOR_B,
  output            HREV,
  output            VREV,

  output     [12:1] KDA,
  output     [17:1] MAB,
  output     [15:0] MDB_CPU_OUT,
  output     [15:0] MDB_RAM_OUT,

  input       [7:0] SEI0100_MDB_IN,

  output            MWRLB,
  output            MRDLB,
  output            DMSL_S1,
  output            DMSL_S2,
  output            DMSL_S4,
  output            DMSL_GL,

  output            RST_S1H, 
  output            SEL_S1H, 
  output            RST_S1Y, 
  output            SEL_S1Y,
  output            RST_S2H, 
  output            SEL_S2H, 
  output            RST_S2Y, 
  output            SEL_S2Y,

  output            WRN6M,
  output            BUSAK,

  input             OBUSDIR,
  input             OBUSRQ,

  output            ODMARQ,

  input             OIBDIR,
  input      [10:1] FDA
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
wire RD_DISPW, RD_PLYER, RD_EXTIF;

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
    .eab(cpu_a[23:1]),
    //DATA BUS (one INOUT bus on PCB) 
    .iEdb(cpu_din),
    .oEdb(cpu_dout),
    
    //ASYNCHRONOUS BUS CONTROL 
    .ASn(cpu_as_n),
    .eRWn(cpu_wr_n),
    .UDSn(cpu_uds_n),
    .LDSn(cpu_lds_n),
    // DTACK is grounded on original PCB, use jtframe_68kdtack_cen to wait for
    // SDRAM ROM data 
    //.DTACKn(1'b0),
    .DTACKn(dtack_n),

    //BUS ARBITRATION CONTROL
    .BRn(br_n),
    .BGn(bg_n),
    .BGACKn(bgack_n),

    // PERIPHERAL CONTROL
    .E(), 
    .VMAn(),
    .VPAn(vpa_n),

    /// PROCESSOR STATUS 
    .FC0(cpu_fc[0]),
    .FC1(cpu_fc[1]),
    .FC2(cpu_fc[2]),

    //INTERUPT CONTROL 
    .IPL0n(ipl0_n),      //int @vblank
    .IPL1n(1'b1),
    .IPL2n(1'b1)  
);

// 74LS244P 17K,17P, 22K
// priority mux instead of tri-state
assign MAB[17:1] = !BUSOPN  ? cpu_a[17:1] :
                   !MBUSDIR ? {2'b0, 3'b111, KDA[12:1]} :
                   !OIBDIR  ? {1'b0, 6'b011011, FDA[10:1]} : //DMARD =0 p. 14
                   17'b0;

// 74LS246
// bidrectional bus
// cpu -> Memory
assign MDB_CPU_OUT[15:0] = cpu_dout[15:0];
assign MDB_RAM_OUT[15:0] = ram_do[15:0];

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
  .CEN(HBLB),
  .D(INT_T),
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

wire bus_cs  = cpu_rom_cs;
// On the PCB /DTACK is grounded because program ROM access is asynchronous.
// The FPGA program ROM is shared SDRAM, so only ROM misses and DMA ownership
// may extend a cycle. BUSOPN becomes active only
// after a DMA controller owns the bus. Gating on BR itself prevents the
// 68000 from finishing its current cycle and issuing BG.
wire bus_busy = (cpu_rom_cs & ~cpu_rom_ok) | BUSOPN;

jtframe_68kdtack_cen  u_dtack(
    .rst        (rst), 
    .clk        (clk),
    .cpu_cen    (cen10),
    .cpu_cenb   (cen10b),
    .bus_cs     (bus_cs), 
    .bus_busy   (bus_busy),
    .bus_legit  (1'b0),
    .ASn        (cpu_as_n),
    .DSn        ({cpu_uds_n, cpu_lds_n}),
    .num        (cen_num),
    .den        (cen_den),
    .DTACKn     (dtack_n),
    .bus_ack    (1'b0),
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
assign cpu_rom_addr[18:1] = cpu_a[18:1];

always @(*) begin
    cpu_rom_cs = ~cpu_as_n & (cpu_a[23:1] < 23'h30000);
end


////// 68K databus input   /////////////////////// 
assign      cpu_din = ~ROM0 | ~ROM1 ? cpu_rom_data[15:0] :  
                 ~RAM       ? ram_do[15:0] :
                 ~RD_DISPW  ? dipsw[15:0]  :
                 ~RD_PLYER  ? {1'b1,1'b1,p2_button2,p2_button1,p2_right,p2_left,p2_down,p2_up,
                               1'b1,1'b1,p1_button2,p1_button1,p1_right,p1_left,p1_down,p1_up} :
                 ~RD_EXTIF  ? {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,
                               1'b1,1'b1,1'b1,p2_start,p1_start,service,1'b1,1'b1} :
                 ~MUSIC     ? {8'd0, SEI0100_MDB_IN} : 
                 16'd0;
///////
// 74LS08 19R page 1
wire MBUSDIR;
// BUSOPN : active low if bus is not use by Memory or Object DMA
wire BUSOPN, MWRMB, MRDMB, bgack_n, vpa_n;

// PLD 20, 22M
PLD20 PLD20_u(
  .AS_n(cpu_as_n),
  .UDS_n(cpu_uds_n),
  .LDS_n(cpu_lds_n),
  .RW(cpu_wr_n),
  .BG_n(bg_n),  // get reply that the cpu is ready for dma 
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
  .BGACK_n(bgack_n), // tell the CPU that device as receive the CPU grant access (bg)
  .VPA_n(vpa_n)
);

//74LS244
wire  MEMDIR = cpu_wr_n;
wire  ROM0, ROM1, RAM, MBUFEN, MBUFDR;
wire  MDMARQ;

ADRS ADRS_u(
  .clk(clk),
  .rst(rst),
  .A(cpu_a[23:17]),
  .MBUSDIR(MBUSDIR),
  .OBUSDIR(OBUSDIR),
  .MEMDIR(MEMDIR),

  .MAB(MAB[6:1]),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .MDB(MDB_CPU_OUT[15:0]),

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
  .VREV(VREV)
);

//MDMARQ : Memory DMA Request
//ODMARQ : Object DMA Request 
wire EXH_4_n, MBUSRQ, DMARD;

MDMA mdma_u(
  .clk(clk),
  .rst(rst),
  .P6M(P6M),
  .N6M(N6M),
  .MDMARQ(MDMARQ), // Request DMA, start DMA 
  .BUSAK(BUSAK),
  // XXX fix that ! or remove comment
  // Compatibility-only input: MDMA currently only inverts it to EXH_4_n,
  // and that output has no consumer.  This normalized bit is therefore not
  // claimed as sheet-6 physical EXH4; the live raw/XORed EXH bus stays in
  // video.v until the U652 net is actually reconnected outside that wrapper.
  .EXH_4(hpos[2]),
  
  .EXH_4_n(EXH_4_n),
  .WRN6M(WRN6M),
  .MBUSRQ(MBUSRQ),
  .MBUSDIR(MBUSDIR),
  .DMSL_GL(DMSL_GL),
  .DMSL_S1(DMSL_S1),
  .DMSL_S2(DMSL_S2),
  .DMSL_S4(DMSL_S4),
  .KDA(KDA[12:1]),
  .DMARD(DMARD)
);

assign br_n = (MBUSRQ & OBUSRQ);

//////// RAM //////////////////////////
//
// 68k cpu ram (64k)
// 2x Sony58257 - 32kx8 SRAM on PCB
//
wire [15:0] ram_do;

jtframe_ram16 #(.AW(15)) u_cpu_ram(
    .clk(clk),
    .addr(MAB[15:1]),
    .data(cpu_dout[15:0]),
    .we({~RAM & ~MWRMB, ~RAM & ~ MWRLB}),
    .q(ram_do[15:0]) 
);

endmodule
