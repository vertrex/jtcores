// Define dual-linebuffer (line odd or even) for obj 1 & obj 2 
// Odd and Even line are switched at each hbl 
// Object 1 & 2 are written to current WREN line (either odd or even)
// and read from other line 
// selected object is data is outputed 

module LINEBUF(
    input         clk,
    input         EVNWREN,  // Even write en 
    input         OBJ_N6M,  // ~Clk 6mhz  
    input   [9:0] OBJ1,     // Obj 1 data 
    input   [9:0] OBJ2,     // Obj 2 data 
    input   [8:0] E1A,      // Even 1 addr 
    input         EVNCLR,   // Even clear 
    input         D1V_7P,  
    input         OBJ_P6M,  // Clk 6Mhz
    input   [8:0] E2A,      // Even 2 addr 
    input   [8:0] O1A,      // Obj 1 addr 
    input         ODDCLR,   // Odd line clear 
    input         ND1V_7P,  //~div 7p 
    input   [8:0] O2A,      // Odd 2 addr 
    //output 
    output        E1FIND,  // Even 1 find (en?) 
    output        E2FIND,  // Even 2 find (en?)
    output        O1FIND,  // Odd 1 find  (en?)
    output        O2FIND,  // Odd 2 find  (en?)
    output  [7:0] OOD,     // object out data 
    output        PRIOR_C, // object priority C
    output        PRIOR_D  // object priority D
);

//////////// NOT DRIVEN /////////////// 
assign E1FIND = 1'b0;
assign E2FIND = 1'b0;
assign O1FIND = 1'b0;
assign O2FIND = 1'b0;

///////////////////////////////////////
wire [9:0] Q_EVN1;
wire [9:0] Q_EVN2; 
wire [9:0] Q_ODD1;
wire [9:0] Q_ODD2;

wire [5:0] nc0;
wire [5:0] nc1;
wire [5:0] nc2;
wire [5:0] nc3;

// XXX  THIS MODULE USE ONLY 6091B that are different than 6091 !!!

// XXXX MUST ADD D1V_7p directio n?
sis6091B u_181(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0({6'b0, OBJ1[9:0]}), //6,7,8,10,12-19,22-25
  .addr0({1'b0, E1A[8:0]}),//62-71
  .we0({EVNWREN, EVNWREN}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5  //XXX USXE addr0 ????? if not addr1 depending of direction? ???
  .we1({1'b0, 1'b0}),
  //.q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
  .q1({nc0, Q_EVN1}) //42-56
);

//6091 B 
sis6091B u_182(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0({6'b0, OBJ2[9:0]}), //6,7,8,10,12-19,22-25
  .addr0({1'b0, E2A[8:0]}),//62-71
  .we0({EVNWREN, EVNWREN}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
  //.q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
  .q1({nc1, Q_EVN2}) //42-56
);

//
sis6091B u_183(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0({6'b0, OBJ1[9:0]}), //6,7,8,10,12-19,22-25
  .addr0({1'b0, O1A[8:0]}),//62-71
  .we0({1'b0, 1'b0}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
//.q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
  .q1({nc2, Q_ODD1}) //42-56
);

//
sis6091B u_184(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0({6'b0, OBJ2[9:0]}), //6,7,8,10,12-19,22-25
  .addr0({1'b0, O2A[8:0]}),//62-71
  .we0({1'b0, 1'b0}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
//.q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
  .q1({nc3, Q_ODD2}) //42-56
);

//we need to mix the bus ourself here 
assign {PRIOR_D, PRIOR_C, OOD[7:0]} = E1FIND ? Q_EVN1 : E2FIND ? Q_EVN2 :  O1FIND ? Q_ODD1 : O2FIND ? Q_ODD2 : 10'b0; 
//O*FIND IS OUT !

//E1FIND / E2FIND / O1FIND / O2FIND ACTIVATE OBJON on objps 
//and clock obj out -> so taht means something that it's activated 
//if address / entry exist ??? or output is not full of 0 ?
//look at jotego linebufer impl that have clr and maybe also that 

endmodule 
