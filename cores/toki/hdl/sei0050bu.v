//page 5
//
//
module SEI0050BU(
  input pxl_cen, //pin 9  CLK 
  input rst, //pin 8

  input VBL_ROM, //pin33 prom26 rom d7 

  output pld_i6, //29 30
  // Video out
  // THIS IS NOT WHAT IS REALLY OUTPUTED BYY THE SEI0050bu 
  
  //384x262 59.63 khz 15.62hz 
  output reg [8:0] hpos, //128 to 511 (511-128 == 383) [0, 383] == 384  
  output reg [8:0] vpos, //250 to 511 (511-250 == 261) [0, 261] == 262 ? 


  //output reg [8:0] hcnt,
  output T8H, //p22 CHAR_CEN
  output reg HBL, //p23 HSYNC 
  output L3, //p24  ~cblank
  output T3F, //p25 CHAR_ROM_CEN
  output T4H, //p26  hpos2 ?  char SIS 6091 ! 
  output HD, //p27   hsync 
  output VSYNC, //p28 csync

  //NOT IN ORIGINAL BUT NEED BY JTCORE 
  output reg HS,  //HS 
  output reg VS,  //VS 
  output LHBL,//~HBL ? 
  output reg LVBL// drived by VBL ROM ?  
  //this is a ~750khz clk
  //it's used to latch hpos,vpos 
  //before they are inputed into the ROM address
  //output reg char_cen,
  //every 4 pixel or 1.5mhz we must copy the pixel 
  //output reg char_rom_cen
);

assign pld_i6 = 0;
assign L3 = 0;
//assign T4H = 0;
assign HD = 0;
assign VSYNC = HS | VS;

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


//HBLANK is pin 23 (what I think was hsync hsync\acbefore ) it's then latche by 74LS174 & xor with pin 24 to create
//mask, hblk is then send to the cpu , mask is then use for hsync on the jamma
//output 


//parameter HBLANK_START  = 265; //high [265, 137]     | 265  
parameter HBLANK_START  = 266; //high [265, 137]     | 265  
//parameter HBLANK_START  = 262; //high [265, 137]     | 265  
//parameter HBLANK_END 	  = 9; //10 tick so stop at 9  | 9  we shift 3 to align but there's maybe a latch somewhere
parameter HBLANK_END 	  = 10; //10 tick so stop at 9  | 9  we shift 3 to align but there's maybe a latch somewhere
//parameter HBLANK_END 	  = 6; //10 tick so stop at 9  | 9  we shift 3 to align but there's maybe a latch somewhere

parameter HSYNC_START 	= 304; //[179,210] +50 hblank start  
parameter HSYNC_END 		= 336; //32

parameter H_TOTAL			  = 384; //384 ??
//512-268
//244

//40-128
//12

//244 + 12 lines = 256 lines 
//
parameter LVBLANK_START  = 240; //rom blank  | 239   
parameter LVBLANK_END		= 16; //15 ??? if 224 , only 223 line ? | 16

parameter VSYNC_START	  = 256; //pin3 ~vsync, 256 include,
parameter VSYNC_END		  = 261; //pin3 ~vsync, 261 include (6 ticks)
parameter V_TOTAL			  = 262; //checked on board pin3  

reg [8:0] hcnt, vcnt;

//reg pin4, pin5, pin6, pin7;
initial begin
	//hcnt  = 9'b0;
	vcnt  = 9'b0;
  hpos  = 9'b0; //recalc size for 1st iteration H_TOTAL - 138 -1 ?
  vpos  = 9'b0;
  hcnt  = 9'b0;
	//LHBL  = 1'b1;
	LVBL  = 1'b1;
	HS    = 1'b0;
	VS    = 1'b0;
end	

assign LHBL = HBL;

// the are not really @hpos1 it's betwee nedge ....
// half 11 half 00 @negedge ? 
assign T3F = (hpos[1:0] == 2'b11); // || hpos[1:0] == 2'b00);
assign T4H = (hpos[2:0] == 3'b100);
assign T8H = (hpos[2:0] == 3'b000);


//on other measure it look like that ... but it's the merged one 
//assign T3F = (hpos[1:0] == 2'b01);
//assign T4H = (hpos[2:0] == 3'b101);
//assign T8H = (hpos[2:0] == 3'b001);

always @(posedge pxl_cen) begin 
    if (hcnt == H_TOTAL - 1) begin  //256 ? 

      if (vcnt  == V_TOTAL - 1) begin
        vcnt <= 0;
        vpos <= 0;
        end
      else begin 
        vcnt <= vcnt + 1'd1;
        vpos <= vpos + 1'd1;
        end 
      end 

    if (hcnt  == H_TOTAL - 1) begin //we start a 0
      hcnt <= 0;
      hpos <= 0;
      end 
    else begin
      hcnt <= hcnt + 1'd1;
      //on original hardware once hcnt > 127 hpos[7] stay high until HTOTAL
      //??? XXX WHY ? it goes until 255 then stay high so counter 
      //come back at 128 until next 255 (255+128 => 383 total lines)
      //is there somewhere an other counter to know that we are > 255 
      //and just after the screen so we must keep hpos[7] high ?
      //hpos[7:0] <= hcnt[8:0] + 9'd1 > 9'd255 ? {1'b1, hcnt[6:0]}  + 8'b1 : hcnt[7:0] + 8'b1 ;
      //hpos[8:0] <= {1'b0, hcnt[8:0] + 9'd1 > 9'd255 ? {1'b1, hcnt[6:0]}  + 8'b1 : hcnt[7:0] + 8'b1};
      //hpos[8:0] <= {1'b0, hcnt[8:0] + 9'd1 > 9'd255 ? {1'b1, hcnt[6:0]}  + 8'b1 : hcnt[7:0] + 8'b1};
      hpos <= hpos + 1'd1;
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
    //+1 ? 
    //if (hpos[2:0] + 1'd1 == 3'b000 || hcnt == HBLANK_END) //we nneed 0 too but 384 + 1 is not 0
    //if (hpos[2:0]  == 3'b000 || hcnt == HBLANK_END) //we nneed 0 too but 384 + 1 is not 0
      //T8H <= 1'b1; 
     //else 
      //T8H <= 1'b0;

    case (hcnt)
      HBLANK_START: begin
        HBL <= 0;
        end 
      HBLANK_END : begin
        HBL <= 1;
      end
      HSYNC_START  : HS <= 1;
      HSYNC_END    : HS <= 0;
      endcase 
    
    case (vcnt)
      LVBLANK_START: 
        if (hcnt == HBLANK_START)
          LVBL <= 0;
      LVBLANK_END: 
        if (hcnt == HBLANK_END)
          LVBL <= 1;
      VSYNC_START: 
        if (hcnt == HSYNC_START)
          VS <= 1;
      VSYNC_END: 
        if (hcnt == HSYNC_START) 
          VS <= 0;
      endcase
end 

endmodule
