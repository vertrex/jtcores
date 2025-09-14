////////// seibu sound system  /////////////////////////////
//
// seibu sound system is composed of :
// - Z80 @3.579545 MHz
// - YM3812 OPL2 @3.579545 MHz
// - MSM6295 @1Mhz 
// - YM3931 (not implemented)
//
// z80 communicate with the main 68k cpu :
//   - recv  command for the MSM6295
//   - recv  data for the YM3812
//   - send  ack of cmd/data
//
// /-----------\         /-------\
// | z80  rom  |         |68k    |
// | encrypted |         |       |      
// | 8.m3 8192 |         |       |
// |           |         \-------/
// |           |             |
// \-----------/        /---------\     /--------\
//      |               |  latch  |     |ROM 9.m1|
//      |               |         |     |131072  |
//      |               \---------/     \--------/
//      |                    |              |
// /---------\           /------\        /-------\ 
// |         |           |      |------- |MSM6295|--->/-------\
// | sei80bu | z80 rom   | z80  |        \-------/    | sound |
// |         |---------->|      |        /------\     | mixer |--> sound out
// |         |  |      |--------|YM3812|---->|       |
// |         |           \------/        \------/     \-------/
// \---------/               |
//                           |
//                    /----------------\
//                    | 7.m7 65536     |
//                    | z80 bank       |
//                    | encrypted      |
//                    \----------------/
//
module music1(
  input             CLK_3_6,
  input             CS3812,
  
  input             SA, // Sound Address
  input       [7:0] SD, // Sound data 

  input        RESET_A, //active low
  output       IRQ3812, //active low

  input        PRCLK1,
  input        SRDB,
  input        SWRB, 
  input        SEL6295,


/////////////////////////////////
////////////// OLD IO ///////////
/////////////////////////////////
  input             rst,
  input             clk,

  input             oki_cen,

  output     [15:0] snd,
  input       [1:0] fxlevel,
  input             enable_fm,
  input             enable_psg,

  // OKI 6295 ADPCM 
  input       [7:0] pcm_rom_data,
  input             pcm_rom_ok, 
  output     [16:0] pcm_rom_addr,
  output            pcm_rom_cs,

  output     [7:0]  oki_dout,
  input      [7:0]  z80_dout,
  input             oki_wr,
  input             cen_fm,
  input             ym_cs_0,
  input             ym_cs_1,
  input             ym_wr,
  output     [7:0]  ym3812_dout,
  output            ym3812_irq_n
);


//YM3812 
//MSM6295GS 
//6295 2MB MASK ROM

//YM3014 //3814  (DAC)
// FLR / MIXER 
// PWR AMP

////////////////////////////////////////////
///////////////// OLD CODE ///////////////// 
////////////////////////////////////////////

///////// OKIM6295   /////////////////////// 
//
// ADPCM sound effects 
//
wire       oki_sample;
wire signed [13:0] oki_snd;
wire [17:0] adpcm_rom_addr;

assign pcm_rom_cs = 1'b1;

// pcm rom byte 13 and 15 are swapped, that could be a simple encryption 
assign pcm_rom_addr = { adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14] ,adpcm_rom_addr[15] , adpcm_rom_addr[12:0]}; 

jt6295 #(.INTERPOL(1))  u_adpcm(
    .rst(rst),
    .clk(clk),
    .cen(oki_cen),
    .ss(1'b1), // pin7 high, select low sample rate
     //CPU interface
    .wrn(~oki_wr),   // wr selected
    .din(z80_dout),  // input data from z80 
    .dout(oki_dout), // output data to z80
     //ROM interface
    .rom_addr(adpcm_rom_addr), // output 18 memory address to read
    .rom_data(pcm_rom_data),   // input  data read
    .rom_ok(pcm_rom_ok),       // high when rom_data is valid and matches rom_addr
     //Sound output
    .sound(oki_snd[13:0]), // sound output 
    .sample(oki_sample)    // sample rate  
);

////////// YM3812 /////////////////////////////////// 
//
// MUSIC
//
reg ym3812_addr;
wire signed [15:0] opl_snd;
wire opl_sample;

jtopl2   u_YM3812(
    .rst(rst),
    .clk(clk),
    .cen(cen_fm),
    .din(z80_dout),
    .addr(ym_cs_1), // cmd addr 
    .cs_n(~(ym_cs_0 | ym_cs_1)),
    .wr_n(~ym_wr), 
    .dout(ym3812_dout),
    .irq_n(ym3812_irq_n),
    .snd(opl_snd[15:0]),
    .sample(opl_sample)
);

///////// MIXING /////////////////
//
// MIX YM3812 & OKI6295 
//
//
//1: pcmgain <= 8'h20 ;   // 200%
//0: pcmgain <= 8'h10 ;   // 100%
//2: pcmgain <= 8'h0c ;   // 75%
//3: pcmgain <= 8'h08 ;   // 50%
//
reg [7:0] fx_volume;
reg [7:0] fm_volume;

always @(posedge clk)  begin //posedge clk ?
  if (clk) begin
   fm_volume <=  ~enable_fm ? 8'h00 : 8'h10; 
   fx_volume <=  ~enable_psg ? 8'h00 : 
                        (fxlevel == 2'h0) ? 8'h08 : 
                        (fxlevel == 2'h1) ? 8'h0c : 
                        (fxlevel == 2'h2) ? 8'h10 : 
                                            8'h20; 
   end
end

jtframe_mixer #(.W1(14)) u_mixer(
    .rst(rst),
    .clk(clk),
    .cen(1'b1),
    // input signals
    .ch0(opl_snd[15:0]), // fm 
    .ch1(oki_snd[13:0]), // fx
    .ch2(16'd0),
    .ch3(16'd0),
    //
    .gain0(fm_volume),
    .gain1(fx_volume),
    .gain2(8'd0),
    .gain3(8'd0),
    .mixed(snd),
    .peak()
);

endmodule
