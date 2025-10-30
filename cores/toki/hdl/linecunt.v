module LINECUNT(
   input  [15:0] OVD,
   input   [3:0] VA,
   input         ODHREY,
   input         RESETA,
   input         SPR1_3,
   input         SPR2_3,
   input         CTLT1,
   input         CTLT2,
   input         HREY,
   input         OBJ_N6M,
   input         ODD_LD,
   input         EVN_LD,
   input         HBLB,
   input         OBJ2_7,
   input         Y1B,
   input         T8H,

   //
   output  [3:0] OBJCOL,
   output        OBJ_HREV,
   output        OSP1,
   output        OSP2,
   output [15:0] PD,
   output        EVNCLR,
   output        ODDCLR,
   output  [8:0] O1A,
   output  [8:0] E1A,
   output        ODDWREN,
   output        EVNWREN,
   output  [8:0] O2A,
   output  [8:0] E2A
);

////////// NOT DRIVEN ///////////// 
assign OBJCOL[3:0] = 4'b0;
assign OBJ_HREV = 1'b0;
assign OSP1 = 1'b0;
assign OSP2 = 1'b0;
assign PD[15:0] = 16'b0;
assign EVNCLR = 1'b0;
assign ODDCLR = 1'b0;
assign O1A[8:0] = 9'b0;
assign E1A[8:0] = 9'b0;
assign ODDWREN = 1'b0;
assign EVNWREN = 1'b0;
assign O2A[8:0] = 9'b0;
assign E2A[8:0] = 9'b0;


///////////////////////////////////
endmodule 
