module LINEBUF(
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

endmodule 
