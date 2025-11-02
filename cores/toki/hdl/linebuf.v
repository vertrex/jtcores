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

///////////////////////////////////////
wire [9:0] Q_EVN1;
wire [9:0] Q_EVN2; 
wire [9:0] Q_ODD1;
wire [9:0] Q_ODD2;

wire [5:0] nc0;
wire [5:0] nc1;
wire [5:0] nc2;
wire [5:0] nc3;

// XXXX MUST ADD DIV_7p directio n?
sis6091 u_181(
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

//
sis6091 u_182(
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
sis6091 u_183(
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
sis6091 u_184(
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
