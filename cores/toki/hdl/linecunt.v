module LINECUNT(
   input         clk,
   input  [15:0] OVD, //Object Video Data (is it metadata positon for object ?)
   input   [3:0] VA,
   input         ODHREV,
   input         RESETA,
   input         SPR1_3,
   input         SPR2_3,
   input         CTLT1,
   input         CTLT2,
   input         HREV,
   input         OBJ_N6M,
   input         ODD_LD, //odd line data ? odd load ? 
   input         EVN_LD,
   input         HBLB,    //hblank 
   input         OBJT2_7,
   input         V1B,  //use to switch odd / even ? 
   input         T8H,  // cen 
   input         VH4,  // cen 
   input         VH8,  // cen 
   input         NOOBJ,  // ? 
   input  [15:0] obj_rom_1_data,
   input         obj_rom_1_ok,
   input  [15:0] obj_rom_2_data,
   input         obj_rom_2_ok,
//output 
   output [18:1] obj_rom_1_addr,
   output        obj_rom_1_cs,
   output [18:1] obj_rom_2_addr,
   output        obj_rom_2_cs,
   output  [3:0] OBJCOL,
   output        OBJ_HREV,
   output        OSP1,
   output        OSP2,
   output [15:0] PD,      // pixel data output from ROM 
   output        EVNCLR,  // clear evn ram ? 
   output        ODDCLR,
   output  [8:0] O1A,     // odd 1 address 
   output  [8:0] E1A,     // even 1 address 
   output        ODDWREN, // ~EVNCLR 
   output        EVNWREN, // ~ODDCLR 
   output  [8:0] O2A,     // odd 2 address 
   output  [8:0] E2A      // even 2 address 
);

// 74LS174 20F 
wire [5:0] u171_Q;

LS174 u171_20F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT1),
   .D({OVD[10:9], OVD[3:0]}),
   .Q(u171_Q[5:0])
);

// 74LS174 21F 
wire [5:0] u172_Q;
wire NC;

LS174 u172_21F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT1),
   .D({1'b0, OVD[15:11]}),
   .Q({NC, u172_Q[4:0]})
);

// 74LS273 20E 
wire [6:0] u174_Q;

LS273 u174_20E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT2),
   .D({u172_Q[1:0], u171_Q[5:0]}),
   .Q({OBJCOL[0], u174_Q[6:0]})
);

// 74LS273 21E 
wire [3:0] u175_Q;

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
assign obj_rom_1_cs = 1'b1; //OE => 74LS273 22E Q7 XXX

//ROM 22C 
//HN62404
//4M-bit 
assign obj_rom_2_cs = 1'b1; //OE => 74LS273 22E Q7 XXX
//split in two ? on original use two separated rom of 16bits 
//read same address on the two but enable one or the other with an inverter
//U177 22F
//WE USE ONE ROM NOT TWO SO IT WILL NOT WORK AS IT WE NEED TO << 1 ?  
//assign obj_rom_addr[19:1] = {u174_Q[6:4], SG0140_Q[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4};
assign obj_rom_1_addr[18:1] = {u174_Q[6:4], ADDR[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4};
assign obj_rom_2_addr[18:1] = {u174_Q[6:4], ADDR[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4};
//wait for obj_rom_ok ? XXX

assign PD[15:0] = ~ROM_CE ? obj_rom_1_data[15:0] : obj_rom_2_data[15:0];

//SEI0140 16D 
//MODE=OHMAX 
wire [8:0] OH;   //Object H position extracted from OVD (metdata ?) use to get data from rom ?
//to get data from rom we need the ROM_INDEX which is stored in some of the
//RAM and then the line_number % .. need to translate that  
wire [4:0] ADDR;
wire NOOBJ_CT2;

sg0140_ohmax sg0140_u174_16D(
   //input 
   .cen(1'b1), // XXX
   .clk(clk),
   .rst(RESETA), // pin 40 
   //41, 9, 10, 28-36 1'b0
   .CTLT1(CTLT1),
   .CTLT2(CTLT2),
   //38 CLT1 clk   / ? 
   //39 CLT2 clk 2 / en2 ? 
   //36,37 1'b1 OHMAX mode
   //.Q({NOOBJ_CT2, ADDR[4:0] ,OH[8:4]})

   .MODE(2'b11), //OHMAX mode
   .NOOBJ(NOOBJ),
   .OVD(OVD[8:4]),
   .HREV(1'b1), ////3 HREV //HREY ?
   //output 
   .OH(OH[8:4]),
   .ADDR(ADDR[4:0]),
   .NOOBJ_CT2(NOOBJ_CT2)
   //.D({OVD[7:4], NOOBJ, OVD[8]}),  //11-16
);


//74LS273 
//22E 

wire [8:0] FH;
wire ROM_CE;

LS273 u176(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT2),
   .D({OH[8], OVD[15],  SPR2_3, SPR1_3 ,OVD[3:0]}),
   .Q({FH[8], ROM_CE, OSP2 ,OSP1 ,OH[3:0]})
);

//74LS04 U177
//wire ROM_CE_N = ~ROM_CE;

//74LS273
//14D 
LS273 u1716(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(CTLT2),
   .D(OH[7:0]),
   .Q(FH[7:0])
);

// transform object H position into an address that will match the line buffer
// position ? so we can get the data via the address ?
// it's storead as 4 bytes blob that will then be deserialzied by objps 
// before been stored in ram 
// so each ram address effectively store a pixel that's why sei0060bu 
// may have two 4 bits counter, it count for each pixel because each one is
// deserialized by the other part objps and thten stored  in ram
//


// act as X pos counter for the line buffer 
// so we have the position to store the pixel deserialized by the SEI0010BU (see objps)  in the line buffer 

//SEI0060BU
//12CD
SEI0060BU sei60bu_u1711(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(FH[8:0]),
   .ODD_LD(ODD_LD),
   .EVN_LD(EVN_LD),
   .HBLB(HBLB),
   .OBJT2_7(OBJT2_7),
   .V1B(V1B),
   .T8H(T8H),
   .HREV(HREV),
   .OA(O1A[8:0]),
   .EA(E1A[8:0]),
   .EVNCLR(EVNCLR),
   .ODDCLR(ODDCLR)
);

//74LS04 
//22F 

assign ODDWREN = ~ODDCLR;
assign EVNWREN = ~EVNCLR;

//SEI0060BU
//16CD 
SEI0060BU sei60bu_u1712(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(OH[8:0]),
   .ODD_LD(ODD_LD),
   .EVN_LD(EVN_LD),
   .HBLB(HBLB),
   .OBJT2_7(OBJT2_7),
   .V1B(V1B),
   .T8H(T8H),
   .HREV(HREV),
   .OA(O2A[8:0]),
   .EA(E2A[8:0]),
   .EVNCLR(),
   .ODDCLR()
);


endmodule 
