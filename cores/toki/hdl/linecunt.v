module LINECUNT(
   input         clk,
   input  [15:0] OVD,
   input   [3:0] VA,
   input         ODHREV,
   input         RESETA,
   input         SPR1_3,
   input         SPR2_3,
   input         CTLT1,
   input         CTLT2,
   input         HREV,
   input         OBJ_N6M,
   input         ODD_LD,
   input         EVN_LD,
   input         HBLB,
   input         OBJT2_7,
   input         V1B,
   input         T8H,
   input         VH4,
   input         VH8,
   input  [15:0] obj_rom_data,
   input         obj_rom_ok,
//output 
   output [19:1] obj_rom_addr,
   output        obj_rom_cs,
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

// 74LS174 20F 
reg [5:0] u171_Q;

LS174 u171_20F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT1),
   .D({OVD[10:9], OVD[3:0]}),
   .Q(u171_Q[5:0])
);

// 74LS174 21F 
reg [5:0] u172_Q;
wire NC;

LS174 u172_21F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT1),
   .D({1'b0, OVD[15:11]}),
   .Q({NC, u172_Q[4:0]})
);

// 74LS273 20E 
reg [6:0] u174_Q;

LS273 u174_20E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT2),
   .D({u172_Q[1:0], u171_Q[5:0]}),
   .Q({OBJCOL[0], u174_Q[6:0]})
);

// 74LS273 21E 
reg [3:0] u175_Q;

LS273 u175_21E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT2),
   //.D({ODHREV, VA8, VA4, VA2, VA1, u172_Q[4:2]}),
   .D({ODHREV, VA[3:0], u172_Q[4:2]}),
   .Q({OBJ_HREV, u175_Q[3:0], OBJCOL[3:1]})
);


//ROM 20C
//HN62404 
//4M-bit 

//ROM 22C 
//HN62404
//4M-bit 
assign obj_rom_cs = 1'b1; //OE => 74LS273 22E Q7 XXX
//split in two ? on original use two separated rom of 16bits 
//read same address on the two but enable one or the other with an inverter
//U177 22F
//WE USE ONE ROM NOT TWO SO IT WILL NOT WORK AS IT WE NEED TO << 1 ?  
//assign obj_rom_addr[19:1] = {u174_Q[6:4], SG0140_Q[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4};
assign obj_rom_addr[19:1] = {u174_Q[6:4], SG0140_Q[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4, 1'b1};
//wait for obj_rom_ok ? XXX

assign PD[15:0] = obj_rom_data[15:0];


//SEI0140 16D 
//MODE=OHMAX 
wire [4:0] SG0140_Q;


//74LS273 
//22E 

//74LS273
//14D 

//SEI0060BU
//12CD

//74LS04 
//22F 


//SEI0060BU
//16CD 




endmodule 
