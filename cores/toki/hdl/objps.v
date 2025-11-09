// Get Pixel Data (PD), palette color, obj prio from XXX and serialize them 
// outputing obj1 & obj2 data 

module OBJPS(
    input        clk,
    input        rst,
    input        OBJ_P6M, // clock 
    input        T3F,     
    input        D1V_7,
    input [15:0] PD,       // obj Pixel Data from .., 
    input        OBJ_N6M,  // clock
    input        FIRST_LD, //first line data ? 
    input        SECND_LD, //second line data ? 
    input        OPSREV,  // rev obj ?
    input  [3:0] OBJCOL,  // OBJ palette color (obj1/2 [7:4])
    input        OSP1,    // obj sprite prio 1 ? 
    input        OSP2,    // obj sprite prio 2 ? 
    input        NOOBJ_CT2,   // no obj ? 
    input        HREV,    // reverse horizontal from dipswitch
    input        HD,      // clock from sei0050bu XXX
    input        E1FIND,  //even obj 1 find 
    input        E2FIND,  //even obj 2 find 
    input        O1FIND,  //odd  obj 1 find 
    input        O2FIND,  //odd obj 2 find 
    input        OBJMASK, //obj mask
    //output 
    output       D1V_7P,
    output       ND1V_7P,
    output [9:0] OBJ1,    //obj data : pix data + palette data + prior 1 + prior 2 
    output       OBJON,  //obj on (depend of find ?)
    output [9:0] OBJ2,   
    output       DLHD    // data line hd ?
);

/////////////// NOT DRIVEN //////// 
assign OBJON = 1'b0;
assign DLHD = 1'b0;
/////////////////////////////////

wire LS175_Q1;
wire NC0; 
wire [1:0]  NC1;
wire NC2;
wire T3F_2;

// 74LS175
LS175 u161(
    .CLK(clk),
    .CLR_n(1'b1),
    .CEN(OBJ_P6M),
    .D({1'b0, D1V_7 ,LS175_Q1, T3F}),
    .Q({NC0, D1V_7P, T3F_2, LS175_Q1}),
    .Qn({NC2, ND1V_7P, NC1[1:0]})
);

// 74LS273
//14C
wire [7:0] u163_q;

LS273 u163(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(FIRST_LD),
    .D({NOOBJ_CT2, OSP2, OSP1, OBJCOL[3:0], OPSREV}),
    .Q(u163_q[7:0])
);


//13C 
LS174 u165(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(SECND_LD),
    .D(u163_q[6:1]),
    .Q(OBJ1[9:4])
);

//14A 
wire pld_i9;
wire sei100_2_38;

LS273 u169(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(SECND_LD),
    .D({NOOBJ_CT2, OSP2, OSP1, OBJCOL[3:0], OPSREV}),
    .Q({pld_i9, OBJ2[9:4], sei100_2_38 })
);

// 
wire [3:0] OBJ1_COLOR;

sei0010bu u162_sei10(
    .clk(clk),
    .rst(rst),
    .cen(OBJ_N6M),
    .load(T3F_2),
    .rev(1'b0),
    .rom_data(PD[15:0]),
    .color(OBJ1_COLOR[3:0])
);

//74LS244 
wire PLD_O7;
wire [3:0] OBJ1_COLOR_EN;
assign OBJ1_COLOR_EN[3:0] = ~PLD_O7 ? OBJ1_COLOR[3:0] : 4'b0;

wire [3:0] OBJ1_COLOR_SHIFT;
//74LS273 
LS273 u166(
    .CLK(clk),
    .CLRn(1'b1),
    .CEN(OBJ_N6M),
    .D({OBJ1_COLOR_SHIFT[3:0] , OBJ1_COLOR_EN[3:0]}),
    .Q({OBJ1[3:0], OBJ1_COLOR_SHIFT[3:0]})
);



// XXX TODO 
// 1 sei0100bu
// pld29 
// 74ls244

endmodule 
