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
  input             clk,
  input             rst,
  input             CLK_3_6,
  input             CS3812,
  
  input             SA0, // Sound Address
  input       [7:0] SD_OUT, // Sound data 
  output      [7:0] SD_IN,

  input        RESET_A, //active low
  output       IRQ3812, //active low

  input        PRCLK1,
  input        SRDB,
  input        SWRB, 
  input        SEL6295,


/////////////////////////////////
////////////// OLD IO ///////////
/////////////////////////////////

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
  output     [7:0]  ym3812_dout,
  input             ym_wr
);


////////// YM3812 /////////////////////////////////// 
//
// MUSIC
//
reg ym3812_addr;
wire signed [15:0] opl_snd;
wire opl_sample;

//type 1 ou 2?
jtopl2   u_YM3812(
    .rst(rst), //RESET A
    .clk(clk), //CLK_3_6 ? 
    .cen(CLK_3_6), //CLK_3_6 //1 if clk is CLK_3_6
    .din(SD_OUT[7:0]),  //SD[0:7] ym_cs_1 
    .addr(SA0), // cmd addr SA0 
    .cs_n(CS3812), //CS3812
    .wr_n(~ym_wr), //SWRB //NO RD ?  
    .dout(ym3812_dout), // separate so keep it or put on shared SD bus ?  
    .irq_n(IRQ3812), //IRQ3812
    .snd(opl_snd[15:0]), //? 
    .sample(opl_sample) //? 
);

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
// XXX NOT ON THE SCHEMATICS ???
assign pcm_rom_addr = { adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14] ,adpcm_rom_addr[15] , adpcm_rom_addr[12:0]}; 
/// XXX NOT WORKING ANYMORE 
jt6295 #(.INTERPOL(1))  u_adpcm(
    .rst(rst),
    .clk(clk), //PRCLK1? 
    .cen(PRCLK1),//1 
    .ss(1'b1), // pin7 high, select low sample rate
     //CPU interface
    .wrn(SWRB | SEL6295),   // wr selected // XX there is norCS 
    .din(SD_OUT[7:0]),  // input data from z80 
    .dout(oki_dout), // output data to z80 // put on shared SD 
     //ROM interface
    .rom_addr(adpcm_rom_addr), // output 18 memory address to read
    .rom_data(pcm_rom_data),   // input  data read
    .rom_ok(pcm_rom_ok),       // high when rom_data is valid and matches rom_addr //SRDB ?
     //Sound output
    .sound(oki_snd[13:0]), // sound output 
    .sample(oki_sample)    // sample rate  
);


//assign SD_IN = CS3812_IN & ~SRDB                       ? ym3812_dout :
               //~SEL6295 & ~SRDB                        ? oki_dout :
               //8'hff;

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

//always @(*) ? assign directly ?
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
    .cen(1'b1), //3_6 ?
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
