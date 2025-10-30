module LINEBUF(
    input         clk,
    input         EVNWREN,
    input         OBJ_N6M,
    input   [9:0] OBJ1,
    input   [9:0] OBJ2,
    input   [8:0] E1A,
    input         EVNCLR,
    input         DIV_7P,
    input         OBJ_P6M,
    input   [8:0] E2A,
    input   [8:0] O1A,
    input         ODDCLR,
    input         NDIV_7P,
    input   [8:0] O2A,
    //output 
    output        E1FIND,
    output        E2FIND,
    output        O1FIND,
    output        O2FIND,
    output  [7:0] OOD,
    output        PRIOR_C,
    output        PRIOR_D
);

//////////// NOT DRIVEN /////////////// 
assign E1FIND = 1'b0;
assign E2FIND = 1'b0;
assign O1FIND = 1'b0;
assign O2FIND = 1'b0;
assign OOD[7:0] = 8'b0;
assign PRIOR_C = 1'b0;
assign PRIOR_D = 1'b0;

///////////////////////////////////////

// XXXX MUST ADD DIV_7p directio n?
sis6091 u_181(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0(OBJ1[9:0]), //6,7,8,10,12-19,22-25
  .addr0(E1A[8:0]),//62-71
  .we0({EVNWREN, EVNWREN}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5  //XXX USXE addr0 ????? if not addr1 depending of direction? ???
  .we1({1'b0, 1'b0}),
  .q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
);

//
sis6091 u_182(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0(OBJ2[9:0]), //6,7,8,10,12-19,22-25
  .addr0(E2A[8:0]),//62-71
  .we0({EVNWREN, EVNWREN}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
  .q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
);

//
sis6091 u_183(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0(OBJ1[9:0]), //6,7,8,10,12-19,22-25
  .addr0(O1A[8:0]),//62-71
  .we0({1'b0, 1'b0}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
  .q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
);

//
sis6091 u_184(
  .clk0(clk),
  .cen0(OBJ_N6M), //31
  .data0(OBJ2[9:0]), //6,7,8,10,12-19,22-25
  .addr0(O2A[8:0]),//62-71
  .we0({1'b0, 1'b0}), //30
  .q0(),

  .clk1(clk),
  .cen1(OBJ_P6M), //73
  .data1(), //data 1 or addr1 ?
  .addr1(), //75-80,1,3,4,5
  .we1({1'b0, 1'b0}),
  .q1({PRIOR_D, PRIOR_C, OOD[7:0]}) //42-56
);

endmodule 
