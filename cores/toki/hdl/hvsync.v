////////// hvsync //////////////////////////////
//
// handle crt horizontal and vertical scrolling 
// generate hblank, vblank, hsync, vsync signal 
// for the @6mhz video clock 
//
module hvsync(
  input clk,
  input pxl_cen,
 
  // Video out 
  output reg hsync,
  output reg vsync,
  output reg hblank,
  output reg vblank,
  
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
parameter HBLANK_START  = 256;
parameter HBLANK_END 	  = 0;   
parameter HSYNC_START 	= HBLANK_START + 44; //le +94 ?? 
parameter HSYNC_END 		= HBLANK_START + 44 + 11; //38.4  pourquoi pas un nombre pile pour avoir 64 us ?  
parameter H_TOTAL			  = 390;

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
parameter VBLANK_START  = 240;
parameter VBLANK_END		= 16;
parameter VSYNC_START	  = VBLANK_START + 10; //il faut troyver le delta est le start
parameter VSYNC_END		  = VBLANK_START + 13;
parameter V_TOTAL			  = 258; //25]8

initial begin
	hpos = 9'b0;
	vpos = 9'b0; 
	hblank = 1'b1;
	vblank = 1'b0;
	hsync = 1'b0;
	vsync = 1'b0;
end	

always @(posedge clk) if (pxl_cen) begin
  if (hpos == H_TOTAL-1) begin
	  hpos <= 0;
	  vpos <= vpos + 1'd1;
	 
	  if (vpos == V_TOTAL-1) begin
	    vpos <= 0;	
	  	end
 		end 
  else begin
	  hpos <= hpos + 1'd1;
  end
	 
  case (hpos)
	  HBLANK_START : hblank <= 1;
    HBLANK_END   : hblank <= 0;
	  HSYNC_START  : hsync <= 1;
	  HSYNC_END    : hsync <= 0;
  endcase 
  
  case (vpos)
    VBLANK_START : if (hpos == HBLANK_START) vblank <= 1;
	  VBLANK_END   : if (hpos == HBLANK_END) vblank <= 0;
	  VSYNC_START  : if (hpos == HSYNC_START) vsync <= 1;
	  VSYNC_END 	 : if (hpos == HSYNC_START) vsync <= 0;
  endcase
end	
		
assign display_on = ~(vblank | hblank);
  
endmodule
