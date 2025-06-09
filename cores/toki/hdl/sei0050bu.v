module SEI0050BU(
  input clk, //needed ???
  input pxl_cen,
  input rst,

  // Video out
  // THIS IS NOT WHAT IS REALLY OUTPUTED BYY THE SEI0050bu 
  //
  output reg HS,
  output reg VS,
  output reg LHBL,
  output reg LVBL,

  output reg [7:0] hpos, //7:0 and ~hblank pin for 8 ? XXX it's not synced on clock but shift 1/2 clock
  output reg [8:0] hcnt,
  output reg [7:0] vpos,  // same ? 

  //this is a ~750khz clk
  //it's used to latch hpos,vpos 
  //before they are inputed into the ROM address
  output reg char_cen,
  //every 4 pixel or 1.5mhz we must copy the pixel 
  output reg char_rom_cen
);

// Retro tink : 
// input lines 261p 
// H-freg 15.56 khz  
// V-freq 59.61 hz 
// Samples/lines 1754
// ADC Clock : 27.29Mhz 
// buffer lag : 2.0ms (31)

// mame source : 
// VSync - 59.6094Hz
// HSync - 15.31996kHz


// CALC ON SEI0050BU 
// hsync freq  : 15.61khz (period 64us) / 15.62khz ? 
// vsync : 2.55khz (6 period of hsync)
// vblank : 37 cycle de hsync ! 
// vblank generated via PROM, 82S135 @ 59.61 hz 
// PROM generate different 59.61hz 


// 256x224

//XXX is hblank vpos pin8 ? 
parameter HBLANK_START  = 256; //pin 40 on board, 256 include 
//parameter HBLANK_START  = 263; //pin 40 on board, 256 include 
parameter HBLANK_END 	  = 383; //383 ? //pinb 40 on board, 256 + 128 include 
//parameter HBLANK_END 	  = 6; //383 ? //pinb 40 on board, 256 + 128 include 

//parameter HSYNC_START 	= 264; //304 csync p33 
parameter HSYNC_START 	= 304; //304 csync p33 
parameter HSYNC_END 		= 336; //336 csync p33 (31/32? ticks)

parameter H_TOTAL			  = 383; //384 ??

//vblank is on pin 28 of sei50bu 
//vpos pin [0:22][1:2]
//checked two times with and without merge
//
//
// USE LVBL DIRECTLY AS IT'S LIKE THAT IN THE seibu50
//parameter VBLANK_START  = 240; //checked on board pin 28 SEI0050BU, 240 included in ~vblank
parameter LVBLANK_START  = 239; //checked on board pin 28 SEI0050BU, 240 included in ~vblank
//parameter VBLANK_END		= 15;  //checked on board pin 28 SEI0050BU, 15 included in ~vblank, 16 not
parameter LVBLANK_END		= 15;  //checked on board pin 28 SEI0050BU, 15 included in ~vblank, 16 not
//cheked two times with and without merge 
parameter VSYNC_START	  = 256; //pin3 ~vsync, 256 include,
parameter VSYNC_END		  = 261; //pin3 ~vsync, 261 include (6 ticks)
parameter V_TOTAL			  = 261; //checked on board pin3  

//reg [8:0] hcnt, vcnt;
reg [8:0] vcnt;

reg pin4, pin5, pin6, pin7;

initial begin
	hcnt  = 9'b0;
	vcnt  = 9'b0;
  hpos  = 8'b0; //recalc size for 1st iteration H_TOTAL - 138 -1 ?
  vpos  = 8'b0;
  hcnt  = 9'b0;
	LHBL  = 1'b1;
	LVBL  = 1'b1;
	HS    = 1'b0;
	VS    = 1'b0;
end	

//always @(negedge pxl_cen) begin
always @(posedge pxl_cen) begin
  // + 1 ? otherwise it's the next pixel 
   if (hpos[1:0]   == 2'b10)
      char_rom_cen <= 1'b1;
   else 
      char_rom_cen <= 1'b0;
end 

always @(posedge pxl_cen) begin 
  //if (pxl_cen) begin
  //
    if (hcnt == 256) begin 
      vcnt <= vcnt + 1'd1;
      vpos <= vpos + 1'd1;

      if (vcnt  == V_TOTAL) begin
        vcnt <= 0;
        vpos <= 0;
        end
      end 

    if (hcnt  == H_TOTAL) begin
      hcnt <= 0;
      hpos <= 0;
      //char_cen <= 1'b1 ?
      //vpos <= vpos + 1'd1;
      //vcnt <= vcnt + 1'd1;

      //VPOS start as 255+128 ? (or finish at 255+ 128-255)
      //so start at 255 ?? 
      //hpos is 0 128 tick avec vpos start ...

      //if (vcnt  == V_TOTAL) begin
        //vcnt <= 0;
        //vpos <= 0;
        //end
      end 
    else begin
      hcnt <= hcnt + 1'd1;
      //on original hardware once hcnt > 127 hpos[7] stay high until HTOTAL
      //??? XXX WHY ? it goes until 255 then stay high so counter 
      //come back at 128 until next 255 (255+128 => 383 total lines)
      //is there somewhere an other counter to know that we are > 255 
      //and just after the screen so we must keep hpos[7] high ?
      //hpos[7:0] <= hcnt[8:0] + 9'd1 > 9'd255 ? {1'b1, hcnt[6:0]}  + 8'b1 : hcnt[7:0] + 8'b1 ;
      hpos[7:0] <= hcnt[8:0] + 9'd1 > 9'd255 ? {1'b1, hcnt[6:0]}  + 8'b1 : hcnt[7:0] + 8'b1 ;
      end

    //to check on SEI50BU original for same 
    //ask sei010bu to latch every 4 pix 
    //if (hpos[1:0] + 1'd1 == 2'b11 || hcnt == HBLANK_END)
      //char_rom_cen <= 1'b1;
    //else 
      //char_rom_cen <= 1'b0;

    //it's synced on clock but HPOS is NOT ! 
    //so there is a shift of 180 degres 
    //it's start every 8 (first start at end of 7) at clock tick
    //
    //+1 ? 
    //if (hpos[2:0] + 1'd1 == 3'b000 || hcnt == HBLANK_END) //we nneed 0 too but 384 + 1 is not 0
    if (hpos[2:0]  == 3'b000 || hcnt == HBLANK_END) //we nneed 0 too but 384 + 1 is not 0
      char_cen <= 1'b1; 
     else 
      char_cen <= 1'b0;

    case (hcnt)
      HBLANK_START - 1 : begin
        LHBL <= 0;
        end 
      HBLANK_END : begin
        LHBL <= 1;
      end
      HSYNC_START-1  : HS <= 1;
      HSYNC_END-1    : HS <= 0;
      endcase 
    
    case (vcnt)
      LVBLANK_START - 1: 
        if (hcnt == HBLANK_START)
          LVBL <= 0;
      LVBLANK_END: 
        if (hcnt == HBLANK_END)
          LVBL <= 1;
      VSYNC_START - 1: 
        if (hcnt == HSYNC_START)
          VS <= 1;
      VSYNC_END: 
        if (hcnt == HSYNC_START) 
          VS <= 0;
      endcase
    //end	
end 

always @(posedge char_cen, posedge rst) begin
   if (rst)
     pin4 <= 1'b1;
   else begin 
     pin4 <= ~pin4; 
   end 
end 

//always @(posedge pxl_cen, posedge rst) begin
  //if (rst)
    //char_cen <= 1'b0;
  //else begin 
    //original use 3'b100 with two 8 bits rom 
    //we currently use one 16 bits rom 
    //if (hpos[2:0] ==  3'b100)// + 1 ? 
    //voir sur l original !
    //half char cen 
    //if (hpos[1:0] -1  ==  2'b10) //working like 2'd3  
      //char_cen <= 1'b1;
    //else 
      //char_cen <= 1'b0;
  //end 
//end 

//assign display_on = ~(vblank | hblank);
  
endmodule
