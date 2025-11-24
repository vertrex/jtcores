////// Horizontal & Vertical position ///// 
// Sprite attribute decoder and latch 
// During objdma it read MDB to get and decode sprite information 
// (Position X, Y, tile code, color, flip, ...) 
// and send that data to the objdma module  
module HVPOS(
  input           clk,
  input    [15:0] MDB,    // Data from CPU RAM  (data from CPU RAM)
  input     [2:1] FDA,    // DMA counter address (address CPU RAM) 
  input           RDCLK,  // RDCLK DMA clk strobe (N6M)   
  input           OIBDIR, // currently DMA 
  input           BUSAK,  // cp bus ack 
  input           OBUSRQ, // ~ object bus request  
  input           XOBDIR, // ~ currently DMA 
  //ouput 
  output          OBUSAK,  // Object bus aknowledge 
  output   [15:0] OBJ_DB,  // == Memory data bus hold during dma 
  output          HREVD_1, // flip flag 
  output          VREVD_1, // flip flag 
  output          SPR1_1,  // Sprite 1 priority 
  output          SPR2_1,  // Sprite 2 priority 
  output          OBJEN_1, // Sprite is enabled / active  
  // Mutiplexed data contain X or Y coordinate (depending of RD_VPOS / RD_HPOS)
  output  [3:0]   ND1,     // Nibble data 1 (Y[3:0]) 
  // Mutiplexed data contain X or Y coordinate (depending of RD_VPOS / RD_HPOS) 
  output  [8:0]   ND2,     // Nibble data 2 (Y[8:4])
  output          RD_VPOS  // Read vertical position (last words of sprite ram is being read during DMA) 
);

//74LS244P 10J 
//74LS22P  19J
assign OBJ_DB[15:0] = MDB[15:0]; 

//PLD25 
wire ORIGIN;
wire CTRL_LT; // Control latch (latch sprite attribute : palette, flip, priority)
wire RD_HPOS; // Read Horizontal position 
wire LT_VPOS; // Latch vertical position 
wire LT_HPOS; // Latch horizontal position
wire RD_CHAR; // Read char 
wire CARY_M;
wire XC4;     // X clock, 4 bit counter

/////// Address deconding ////////
//
// Decode lower bits of FDA 
// Sprite is 4 words (16bits) of RAM  
// Identifies which one is on the bus 
// word 0  : CTRL_LT 
//          obj enable, origin, sprite 2, sprite 1, vrevd (flip y unused?) , hrevd (flip x  
//          x offset [7:4],  y offset [3:0]
// word 1 : RD_CHAR 
//          tile color : [15:12]
//          tile index low bits  : [11:0] 
// word 2 : RD_HPOS :  tile index high bits [15],  X coordinate [8:0] (need to add previous offset) (LT_HPOS if ORIGIN low in CTRL_LT)  
// word 3 : RD_VPOS :  Y coordinate (LT_VPOS if ORIGIN low in CTRL LT) 
//

//+0   x....... ........  sprite disable ??
//+0   .xx..... ........  tile is part of big sprite (4=first, 6=middle, 2=last)
//+0   .....x.. ........  ??? always set? (could be priority - see Bloodbro)
//+0   .......x ........  Flip x
//+0   ........ xxxx....  X offset: add (this * 16) to X coord
//+0   ........ ....xxxx  Y offset: add (this * 16) to Y coord

//+1   xxxx.... ........  Color bank
//+1   ....xxxx xxxxxxxx  Tile number (lo bits)
//+2   x....... ........  Tile number (hi bit)
//+2   .???.... ........  (set in not yet used entries)
//+2   .......x xxxxxxxx  X coordinate
//+3   .......x xxxxxxxx  Y coordinate

PLD25 pld25_u(
    .FDA(FDA[2:1]), //0 or 1 ???
    .RDCLK(RDCLK),
    .ORIGIN(ORIGIN),
    .OIBDIR(OIBDIR),
    .POS_8(POS[8]),
    .CARY_M(CARY_M), //XXX loop from other 
    .XC4(XC4), // XXX 
    .BUSAK(BUSAK),
    .OBUSRQ(OBUSRQ),

    .CTRL_LT(CTRL_LT),
    .RD_VPOS(RD_VPOS),  // page 14 objdma
    .RD_HPOS(RD_HPOS),
    .LT_VPOS(LT_VPOS),
    .LT_HPOS(LT_HPOS),
    .ND2_8(ND2[8]),
    .OBUSAK(OBUSAK),
    .RD_CHAR(RD_CHAR)
);

//
/// DECODE SPRITE WORDS 0 : CTRL data  
//

//74LS174 U134  
LS174 u134(
  .CLK(clk),
  .CLRn(XOBDIR),
  .CEN(CTRL_LT),
  .D({OBJ_DB[15], OBJ_DB[13], OBJ_DB[11:8]}),
   // MAME IS A BIT WRONG FOR THAT WE MAY WANT TO EXPLAIN AND CORRECT IT ?
   //15        /13    /11      /10    /9       /8 (flipx)
  .Q({OBJEN_1, ORIGIN, SPR2_1, SPR1_1, VREVD_1, HREVD_1})
);

wire [8:0] POS;

//74LS173 u135 & 74LS173 u136
wire [3:0] OFST;
reg  [3:0] offset_x; 
reg  [3:0] offset_y; 

always @(posedge clk) begin
    if (~CTRL_LT) begin // & RDCLK ?
        // 9H [3:0] (Offset Y)
        offset_y <= OBJ_DB[3:0];
        // 10H [7:4] (Offset X)
        offset_x <= OBJ_DB[7:4];
    end
end

assign OFST[3:0] = (RD_VPOS == 1'b0) ? offset_y[3:0] :
                   (RD_HPOS == 1'b0) ? offset_x[3:0] :
                                       4'b0;

///
/// DECODE SPRITE WORDS 1 : RD_CHAR  (tile coder + tile low bits) 
/// DECODE SPRITE WORDS 2 : RD_HPOS (LT_HPOS if ~ORIGIN in CTRL LT) 
/// DECODE SPRITE WORDS 3 : RD_VPOS (LT_VPOS if <ORIGIN in CTRL LT) 
// LT latch data of vpos to be combined with offset ?  

///
/// DEMUX DATA 
///

//74F841 u137 11H 
reg   [9:0] u137_latch;
wire  [9:0] u137;

always @(posedge clk) begin
    if (LT_HPOS) // & RDCLK ? 
      u137_latch <= {1'b0, OBJ_DB[8:0]};
    end

//assign {CARY_M, POS[8:4], ND2[3:0]} = ~RD_HPOS  ? u137_latch : 10'bz;

//74F841 u138 12H 

reg   [9:0] u138_latch;
wire  [9:0] u138;

always @(posedge clk) begin
    if (LT_VPOS)
      u138_latch <= {1'b0, OBJ_DB[8:0]};
    end

//assign {CARY_M, POS[8:4], ND1[3:0]} = ~RD_VPOS ? u138_latch : 10'bz; 


//74F827 u139 13H 

//assign {CARY_M, POS[8:4] , ND2[3:0]} = ~RD_CHAR ? {1'b1, OBJ_DB[8:0]} : 10'bz;


assign ND1[3:0] = ~RD_VPOS ? u138_latch[3:0] : 4'b0;  // Y pos low bits 

assign ND2[3:0] = ~RD_HPOS ? u137_latch[3:0] : //X pos low bits 
                  ~RD_CHAR ? OBJ_DB[3:0] : // tile code 
                  4'b0;

// position use by the adder 
assign POS[8:4] = ~RD_HPOS ? u137_latch[8:4] :
                  ~RD_VPOS ? u138_latch[8:4] :
                  ~RD_CHAR ? OBJ_DB[8:4] :
                   5'b0;

// bit 9 for the adder 
assign CARY_M = ~RD_HPOS ? u137_latch[9] : 
                ~RD_VPOS ? u138_latch[9] : 
                ~RD_CHAR ? 1'b1 : 
                1'b0;
      

//74F283 14H 
assign {XC4, ND2[7:4]} = {3'b0, CARY_M} + POS[7:4] + OFST[3:0];


endmodule 
