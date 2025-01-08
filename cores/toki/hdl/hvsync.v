////////// hvsync //////////////////////////////
//
// handle crt horizontal and vertical scrolling 
// generate hblank, vblank, hsync, vsync signal 
// for the @6mhz video clock 
//
//

//rename SEI005BU
module hvsync(
  input clk,
  input pxl_cen,
 
  // Video out 
  output reg lhsync,
  output reg lvsync,
  output reg lhblank,
  output reg lvblank, 
  
  output display_on,
  
  output reg [8:0] hpos,
  output reg [8:0] vpos 
);

//each line 
//HSync - 15.31996kHz rapide 
//Measured on DAC UEC-51 pin 13 
//width 42.4us
//period 64 us 
//frequency 15.62khz 
//duty cycle 66.25 
//
//6*10**6 /390 => 15384
//
//each frame
//VSync - 59.6094Hz lent, devrait etre toute les 3 lignes et on a choisis
//toute les 6 lignes 
//6*10**6/(390*258) => 58.63 
//MEASURE on board

 //1/16.77 => 0.05963029218843172
//16.77ms => 59.6302 
//
//(6*10**6)/(390*258)
//59.630292188431724 (donc mame est ok sur 390*258)
//
//
//59.61hz on SN74LS244N
//width 683us
//period 16.7753 
//
//6*10**6/(401*251)
//59.61192635940031
//
// Retro tink : 
// input lines 261p 
// H-freg 15.56 
// V-freq 59.61 
// Samples/lines 1754
// ADC Clock : 27.29Mhz 
// buffer lag : 2.0ms (31)
//
///////// 68K interrupt ///////////////////////////
//
// interrupt at each vblank 
// 59.61hz,59.60hz verified on board
// interrupt routine fill char, bg1, bg1, palette ram
// during dip-switch char ram is zero filled @vblank
// ram drawing and filling is longer than vblank period 

//current ?
//parameter HBLANK_END 	  = 0;   
//parameter HSYNC_START 	= HBLANK_START + 44;
//parameter HSYNC_END 		= HBLANK_START + 76;
//parameter H_TOTAL			  = 390;

//parameter VBLANK_START  = 240;
//parameter VBLANK_END		= 16;
//parameter VSYNC_START	  = VBLANK_START + 10;
//parameter VSYNC_END		  = VBLANK_START + 13;
//parameter V_TOTAL			  = 258;

// old toki core I tested that to have the wave working at some point ...
// maybe before "dma stuff"
//parameter HBLANK_START  = 256;
//parameter HBLANK_END 	= 0;   
//parameter HSYNC_START 	= HBLANK_START + 45 ;
//parameter HSYNC_END 		= HBLANK_START + 77;
//parameter H_TOTAL			= 391;

//parameter VBLANK_START  = 240; 
//parameter VBLANK_END		= 16;
//parameter VSYNC_START	= VBLANK_START + 13; 
//parameter VSYNC_END		= VBLANK_START + 19; 
//parameter V_TOTAL			= 261; //with 3 more pixel in x wew don't have the change


//parameter HBLANK_START  = 255;
//parameter HBLANK_END 	  = 390;  //390?  
//parameter HSYNC_START 	= HBLANK_START + 44; //le +94 ?? 
//parameter HSYNC_END 		= HBLANK_START + 44 + 11; //38.4  pourquoi pas un nombre pile pour avoir 64 us 
//parameter H_TOTAL			  = 391;

//parameter VBLANK_START  = 240;
//parameter VBLANK_END		= 15;
//parameter VSYNC_START	  = VBLANK_START + 10; //il faut troyver le delta est le start
//parameter VSYNC_END		  = VBLANK_START + 13;
//parameter V_TOTAL			  = 259; //25]8


// MODELINE 
// MY pour du  59.61192635940031 6*10**6/(401*251) le plus proche de la board


//parameter HBLANK_START  = 255;
//parameter HBLANK_END 	  = 400;  //390?  
//parameter HSYNC_START 	= HBLANK_START + 44; //le +94 ?? 
//parameter HSYNC_END 		= HBLANK_START + 44 + 11; //38.4  pourquoi pas un nombre pile pour avoir 64 us 
//parameter H_TOTAL			  = 401;

//parameter VBLANK_START  = 240;
//parameter VBLANK_END		= 15;
//parameter VSYNC_START	  = VBLANK_START + 5; //il faut troyver le delta est le start
//parameter VSYNC_END		  = VBLANK_START + 8;
//parameter V_TOTAL			  = 251; //25]8


//Modeline "256x240" 6.000000 256 292 320 384   240 248 251 262 -hsync -vsync
//https://www.neo-arcadia.com/forum/viewtopic.php?t=37718
// neoarcadia
//

//parameter HBLANK_START  = 255;
//parameter HBLANK_END 	  = 383;  //390?  
//parameter HSYNC_START 	= 292; //le +94 ?? 
//parameter HSYNC_END 		= 320; //38.4  pourquoi pas un nombre pile pour avoir 64 us 
//parameter H_TOTAL			  = 384;

//parameter VBLANK_START  = 240;
//parameter VBLANK_END		= 15;
//parameter VSYNC_START	  = 248; //il faut troyver le delta est le start
//parameter VSYNC_END		  = 251; 
//parameter V_TOTAL			  = 262; //
// mame source : 
// VSync - 59.6094Hz
// HSync - 15.31996kHz
//   
//>>> 6*10**6/(357*282)
//59.59830740806961

// XXX 
// CALC ON SEI0050BU 
// hsync freq  : 15.61khz (period 64us)
// vsync : 2.55khz (6 period of hsync)
// vblank : 37 cycle de hsync ! 


parameter HBLANK_START  = 256;
parameter HBLANK_END 	  = 384; //
parameter HSYNC_START 	= 263; //
parameter HSYNC_END 		= 384; // 7 ? 
parameter H_TOTAL			  = 384;

//vblank is on pin 28 of sei50bu 
//vpos pin [0:22][1:2]
parameter VBLANK_START  = 240; //checked on board pin 28 SEI0050BU, 240 included in vblank
parameter VBLANK_END		= 15;  //checked on board pin 28 SEI0050BU, 15 included in vblank, 16 not
parameter VSYNC_START	  = 256; //pin3 ~vsync, 256 include, 
parameter VSYNC_END		  = 261; //pin3 ~vsync, 261 include
parameter V_TOTAL			  = 261; //checked on board pin 


reg [8:0] hcnt, vcnt;

initial begin
	hcnt = 9'b0;
	vcnt = 9'b0;
  hpos = 9'b0; //recalc size for 1st iteration H_TOTAL - 138 -1 ?
  vpos = 9'b0;
  hcnt = 9'b0;
	hblank = 1'b1;
	vblank = 1'b0;
	hsync = 1'b0;
	vsync = 1'b0;
end	

always @(posedge clk) begin 
  if (pxl_cen) begin
    if (hcnt  == H_TOTAL) begin
      hcnt <= 0;
      hpos <= 0;
      vpos <= vpos + 1'd1;
      vcnt <= vcnt + 1'd1;

      if (vcnt  == V_TOTAL) begin
        vcnt <= 0;
        vpos <= 0;
        end
      end 
    else begin
      hcnt <= hcnt + 1'd1;
      hpos <= hpos + 1'd1;
      end

    //if (hcnt == 384) //we reset hpos at the point we want 
      //hpos <= 0;
    //else 
      //hpos <= hpos + 1'd1;

    //if (hcnt == 128)
    //vpos <= vcnt; //less glitch because after we switch buffer ?
     

    case (hcnt)
      HBLANK_START-1 : begin
        //vpos <= vcnt; //less glitch because after we switch buffer ?
        hblank <= 1;
        end 
      HBLANK_END   : begin
        hblank <= 0;
      end
      HSYNC_START-1  : hsync <= 1;
      HSYNC_END-1    : hsync <= 0;
      endcase 
    
    case (vcnt)
      VBLANK_START-1: 
        if (hcnt == HBLANK_START)
          vblank <= 1;
      VBLANK_END: 
        if (hcnt == HBLANK_END)
          vblank <= 0;
      VSYNC_START-1: 
        if (hcnt == HSYNC_START)
          vsync <= 1;
      VSYNC_END: 
        if (hcnt == HSYNC_START) 
          vsync <= 0;
      endcase
    end	
end 

assign display_on = ~(vblank | hblank);
  
endmodule
