////////// main module  //////////////////////
//
//  - Motorola 68k main cpu @10mhz 
//  - cpu address bus 
//  - cpu 2*32kx8 ram
//  - palette / video / bk1 / bk2 / sprite ram
//  - scrolling & sound latch
// 
module toki_main(
  input             rst,

  // Clock
  input             clk,
  //input             pxl_cen,
  //input             pxl2_cen,

  // Video
  input             LVBL, //cpu IPL0n triggered by 82s135 pin 11 
  input       [7:0] hpos,
  input       [7:0] vpos,

  // Input
  input      [1:0]  start_button,
  input      [5:0]  joystick1,
  input      [5:0]  joystick2,

  input      [31:0] dipsw,
  input             dip_pause,     
  input             service,

  input      [15:0] cpu_rom_data,
  input             cpu_rom_ok,
  output reg [18:1] cpu_rom_addr,
  output reg        cpu_rom_cs,

  //Shared video RAM 
  input      [10:1] palette_addr,
  output     [15:0] palette_out,

  //input      [10:1] vram_addr,
  output     [15:0] vram_out,


  //input      [10:1] bk1_addr,
  output     [15:0] bk1_out,

  //input      [10:1] bk2_addr,
  output     [15:0] bk2_out,

  input      [10:1] sprite_addr,
  output     [15:0] sprite_out,

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

  output      [8:0] bk1_hpos,
  output      [8:0] bk1_vpos,
  output      [8:0] bk2_hpos,
  output      [8:0] bk2_vpos
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
wire cpu_wr;                // Read = 1, Write = 0
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
wire br_n;
wire bgack_n;
wire cen10;
wire cen10b;
wire dtack_n;
wire int1;

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
    .eRWn(cpu_wr),     // ouput  : write=0, read =1 
    .UDSn(cpu_uds_n),  // ouput  : upper byte strobe
    .LDSn(cpu_lds_n),  // output : lower byte strobe
    .DTACKn(dtack_n),  // input  : data transfer ack

    //BUS ARBITRATION CONTROL 
    .BRn(1'b1),        // input  : bus request
    .BGn(bg_n),        // output : bus grant 
    .BGACKn(1'b1),     // input  : Bus grant ack 

    // PERIPHERAL CONTROL 
    .E(),              // output : cpu enable 
    .VMAn(),           // output : valid pheripheral memory address
    .VPAn(inta_n),     // output :valid peripheral address detected  

    /// PROCESSOR STATUS 
    .FC0(cpu_fc[0]),   // output 
    .FC1(cpu_fc[1]),   // output 
    .FC2(cpu_fc[2]),   // output 

    //INTERUPT CONTROL 
    .IPL0n(int1),      //int @vblank
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
wire inta_n;
assign inta_n = ~&{cpu_fc[2], cpu_fc[1], cpu_fc[0], ~cpu_as_n};

jtframe_virq u_virq(
    .rst        (rst),
    .clk        (clk),
    .LVBL       (LVBL), //~LVBL ???
    .dip_pause  (dip_pause), //handle cpu pause
    .skip_en    (),
    .skip_but   (),
    .clr        (~inta_n),
    .custom_in  (),
    .blin_n     (),
    .blout_n    (int1),
    .custom_n   ()
);


///////// 68K dtack //////////////////////////////
//
// handle 68k clock and data trasnfer acknowledge
// bus is busy if cpu rom is not available 
//

// cpu clock 48*5/24 => 10mhz 
localparam [3:0] cen_num =  4'd5;
localparam [4:0] cen_den = 5'd24;

wire bus_cs   = |{cpu_rom_cs};
wire bus_busy = |{cpu_rom_cs & ~cpu_rom_ok}; 

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
    .wait2      (1'b0),
    .wait3      (1'b0),
    // unused
    .fave       (),
    .fworst     ()
);

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (clk),
    .cen        (cen10b),
    .rst        (rst),
    .cpu_BRn    (br_n),
    .cpu_BGACKn (bgack_n),
    .cpu_BGn    (bg_n),
    .cpu_ASn    (cpu_as_n),
    .cpu_DTACKn (dtack_n),
    .dev_br     (1'b1)
);

///////// 68k bus mapping  ////////////////////
//
// 0x000000, 0x05ffff : rom        (393216)(ro)
// 0x060000, 0x06d7ff : cpu ram     (55296)(rw)
// 0x06d800, 0x06dfff : spriteram    (2048)(rw) 
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
reg ram_cs, sprite_cs, palette_cs, bk1_cs, bk2_cs, vram_cs,  
    scroll_cs, dsw_cs, inputs_cs, system_cs;
reg sound_cs_3, sound_cs_5;

always @(posedge clk or posedge rst) begin
  if (rst) begin
    ram_cs <= 1'd0;
    sprite_cs <= 1'd0;
    palette_cs <= 1'd0;
    bk1_cs <= 1'd0;
    bk2_cs <= 1'd0;
    vram_cs <= 1'd0;
    scroll_cs <= 1'd0;
    dsw_cs <= 1'd0;
    inputs_cs <= 1'd0;
    system_cs <= 1'd0;
    cpu_rom_addr <= 18'd0;
  end else begin
     if(!cpu_as_n) begin
      if (cpu_a[23:0] < 24'h60000)
        cpu_rom_addr[18:1] <= cpu_a[18:1];

      cpu_rom_cs <= (                        cpu_a[23:0] < 24'h60000);
      ram_cs <= (cpu_a[23:0] >= 24'h60000 && cpu_a[23:0] < 24'h6d800);
      //video 
      sprite_cs  <= (cpu_a[23:0] >= 24'h6d800 && cpu_a[23:0] < 24'h6e000); //2048
      palette_cs <= (cpu_a[23:0] >= 24'h6e000 && cpu_a[23:0] < 24'h6e800); //2048
      bk1_cs     <= (cpu_a[23:0] >= 24'h6e800 && cpu_a[23:0] < 24'h6f000); //2048
      bk2_cs     <= (cpu_a[23:0] >= 24'h6f000 && cpu_a[23:0] < 24'h6f800); //2048
      vram_cs    <= (cpu_a[23:0] >= 24'h6f800 && cpu_a[23:0] < 24'h70000); //2048
      //sound latch
      sound_cs_2 <= (cpu_a[23:0] == 24'h80004);
      sound_cs_3 <= (cpu_a[23:0] == 24'h80006);
      sound_cs_4 <= (cpu_a[23:0] == 24'h80008);
      sound_cs_5 <= (cpu_a[23:0] == 24'h8000a);
      sound_cs_6 <= (cpu_a[23:0] == 24'h8000c);
      //scroll 
      scroll_cs  <= (cpu_a[23:0] >= 24'ha0000 && cpu_a[23:0] < 24'ha005f); //96 
      //IO
      dsw_cs     <= (cpu_a[23:0] >= 24'hc0000 && cpu_a[23:0] < 24'hc0001); //2 
      inputs_cs  <= (cpu_a[23:0] >= 24'hc0002 && cpu_a[23:0] < 24'hc0003); //2 
      system_cs  <= (cpu_a[23:0] >= 24'hc0004 && cpu_a[23:0] < 24'hc0005); //2 
    end else begin
      ram_cs <= 1'd0;
      sprite_cs <= 1'd0;
      palette_cs <= 1'd0;
      bk1_cs <= 1'd0;
      bk2_cs <= 1'd0;
      vram_cs <= 1'd0;
      scroll_cs <= 1'd0;
      dsw_cs <= 1'd0;
      inputs_cs <= 1'd0;
      system_cs <= 1'd0;
      cpu_rom_addr <= 18'd0;
    end
  end
end


////// 68K databus input   /////////////////////// 
//
always @(posedge clk, posedge rst) begin
  if(rst) begin 
    cpu_din <= 16'h0000;
    end
  else begin
    if (clk) begin
      cpu_din <= cpu_rom_cs ? cpu_rom_data[15:0] :  
                 ram_cs     ? ram_do[15:0] :
                 palette_cs ? palette_do[15:0] :
                 sprite_cs  ? sprite_do[15:0] : 
                 vram_cs    ? vram_do[15:0] : 
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


//////// Scroll /////////////////////////
//
// Scrolling register latch
//
reg [15:0] bk1_scroll_x_lo = 0;
reg [15:0] bk2_scroll_x_lo = 0;
reg [15:0] bk1_scroll_y_lo = 0;
reg [15:0] bk2_scroll_y_lo = 0;

// XXX use sei021bu for scrollng check if cpu_address can be high both at same time 
// durring 1 6mhz clk cycle or how does that work ???
// bk1_scroll_x[8:0] <= { cpu_dout[4], bk1_scroll_x_lo[6:0], bk1_scroll_x_lo[7] };

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
        bk1_scroll_x_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h5)
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
    .data(cpu_dout[15:0]), 
    .addr(cpu_a[15:1]), 
    .we({ram_cs && !cpu_wr && !cpu_uds_n, ram_cs && !cpu_wr && !cpu_lds_n}),
    .q(ram_do[15:0])
);

///////// VIDEO RAM //////////
// 
// video ram (2048)
// we use special ram that copy content @vblank
// because during dipswitch (only) vram is reset at each frame
// that make cpu write to vram longer than a vblank period
// C1 on PCB
wire [15:0] vram_do;

/*

reg [7:0] hpos_shift_0 = 0;

always @(pxl_cen) begin 
   if (hpos[8:0] > 256) //or hblank simply ?
   //if (LHBL == 1'b0)
     hpos_shift_0 <= 8'd0;
     //vpos_shift = vpos + 1; 
   else
     hpos_shift_0 <= hpos[7:0]; //better way to calculate ? << 2 ? 
     //hpos_shift_0 <= hpos[7:0] + 8'd4; //better way to calculate ? << 2 ? 
     //vpos_shift <= vpos 
end 
*/ 
//replace by 4:0 ? directly in add_out ???

sis6091 #(.W(10)) u_vram_ram(
  .clk(clk),
  .trigger_n(LVBL),
  .we({vram_cs && !cpu_wr && !cpu_uds_n , vram_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]),  //if we lower cpu addr in we don't have the shift
  .data(cpu_dout[15:0]),
  .q_in(vram_do),

  // WHICH CLOCK ???
  //XXX latchc or enable for a certain time XXX must use char_addr_en to
  //enable or latched pos  ...
  //check what it get just after hblank 
  //10 pin :( we have 8 pin capable 
  //left 8 for hpos or vblank still can be usefull if 
  //vpos 7 is low 
  //        tile addr 256*256 / 32 
  //        256 x/32
  //        256 y/32
  //
  //.addr_out({vpos[7:3], hpos_shift_0[7:3]}),//+ 2'd2 ? hpos[4] ?  ^ every 32pix ? 
  .addr_out({vpos[7:3], hpos[7:3]}),//+ 2'd2 ? hpos[4] ?  ^ every 32pix ? 
  .q(vram_out[15:0])
); 

///////// BK1 RAM //////////
//
// background 1 (2048)
// D4 on pcb
//

//sei021bu ? 
//wire signed [8:0] bk1_hpos;// = hpos[7:0] + bk1_scroll_x[8:0];
//wire signed [8:0] bk1_vpos;// = vpos[7:0] + bk1_scroll_y[8:0];

sei0021bu sei21bu_bk1_h(
   .pos(hpos),
   .scroll(bk1_scroll_x),
   .scrolled(bk1_hpos)
);

sei0021bu sei21bu_bk1_v(
   .pos(vpos),
   .scroll(bk1_scroll_y),
   .scrolled(bk1_vpos)
);

sis6091 #(.W(10)) u_bk1_ram(
  .clk(clk),
  .trigger_n(LVBL),
  .we({bk1_cs && !cpu_wr && !cpu_uds_n, bk1_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(),
  
  .addr_out({bk1_vpos[8:4], bk1_hpos[8:4]}),
  .q(bk1_out)
); 

///////// BK2 RAM //////////
//
// background 2 (2048)
// F4 on pcb
//wire signed [8:0] vpos_shift_2 = vpos[7:0] + bk2_scroll_y[8:0];
//wire signed [8:0] hpos_shift_2 = hpos[7:0] + bk2_scroll_x[8:0];

sei0021bu sei21bu_bk2_h(
   .pos(hpos),
   .scroll(bk2_scroll_x),
   .scrolled(bk2_hpos)
);

sei0021bu sei21bu_bk2_v(
   .pos(vpos),
   .scroll(bk2_scroll_y),
   .scrolled(bk2_vpos)
);

sis6091 #(.W(10)) u_bk2_ram(
  .clk(clk),
  .trigger_n(LVBL),
  .we({bk2_cs && !cpu_wr && !cpu_uds_n, bk2_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(),
  
  .addr_out({bk2_vpos[8:4], bk2_hpos[8:4]}),
  .q(bk2_out)
);

///////// PALETTE RAM //////////
// 
// palette ram (2048)
// palette is read and checked by main cpu 
// H4 on PCB behind UEC-51
wire [15:0]  palette_do;

sis6091 #(.W(10)) u_palette_ram(
  .clk(clk),
  .trigger_n(LVBL),
  .we({palette_cs && !cpu_wr && !cpu_uds_n, palette_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(palette_do),

  .addr_out(palette_addr[10:1]),
  .q(palette_out)
); 

// XXX SPRITE SEEMS TO USE 8 6091 on board ! 

///////// SPRITE RAM //////////
//
// sprite ram (2048)
// sprite ram is read by the cpu 
// if cpu can't read sprite ram content 
// there will be no scrolling during the 'cave screen'
//
wire [15:0] sprite_do;

sis6091 #(.W(10)) u_sprite_ram(
  .clk(clk),
  .trigger_n(LVBL),
  .we({sprite_cs && !cpu_wr && !cpu_uds_n, sprite_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(sprite_do),

  .addr_out(sprite_addr[10:1]),
  .q(sprite_out)
);



endmodule
