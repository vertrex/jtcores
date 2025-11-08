module OBJPS(
    input        clk,
    input        OBJ_P6M,
    input        T3F,
    input        DIV_7,
    input [15:0] PD,
    input        OBJ_N6M,
    input        FIRST_LD,
    input        SECND_LD,
    input        OPSREV,
    input  [3:0] OBJCOL,
    input        OSP1, 
    input        OSP2,
    input        NOOBJ, 
    input        HREV,
    input        HD,
    input        E1FIND,
    input        E2FIND,
    input        O1FIND,
    input        O2FIND,
    input        OBJMASK,
    //output 
    output       DIV_7P,
    output       NDIV_7P,
    output [9:0] OBJ1,
    output       OBJON,
    output [9:0] OBJ2,
    output       DLHD
);

/////////////// NOT DRIVEN //////// 
assign DIV_7P = 1'b0;
assign NDIV_7P = 1'b0;
assign OBJ1[9:0] = 10'b0;
assign OBJON = 1'b0;
assign OBJ2[9:0] = 10'b0;
assign DLHD = 1'b0;
/////////////////////////////////




endmodule 
