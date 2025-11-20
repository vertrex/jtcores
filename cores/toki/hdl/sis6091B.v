/* 
* SIS 6091B PIN 

           ________
???     30-|      |-6  
????    31-|      |-7  
        27-|      |-8  ??-2 
        28-|      |-10 ??-3 
           |      |-12 ??-4 
??-0    62-|      |-13 ??-5 
??-1    63-|      |-14 ??-6
??-2    64-|      |-15 ??-7
??-3    65-|      |-16 ??-8
??-4    66-|      |-17 ??-9
??-5    67-|      |-18 ??-10 
??-6    68-|      |-19 ??-11 
??-7    69-|      |-22 ??-12
??-8    70-|      |-23 ??-13
??-9    71-|      |-24 ??-14 
           |      |-25 ??-15 
??-0    75-|      |
??-1    76-|      |-42 ?-0 
??-2    77-|      |-43 ?-1 
??-3    78-|      |-44 ?-2  
??-4    79-|      |-45 ?-3 
??-5    80-|      |-46 ?-4 
??-6     1-|      |-47 ?-5 
??-7     3-|      |-48 ?-6 
??-8     4-|      |-49 ?-7 
??-9     5-|      |-51 ?-8  
           |      |-53 ?-9  
????    26-|      |-54 ?-10
?       35-|      |-55 ?-11
        40-|      |-56 ?-12 
??????? 34-|      |-57 ?-13 
????    73-|      |-58 ?-14 
        33-|      |-59 ?-15
?       38-|      | 
        39-|      |-60  //ACTIVATE SELECT ? O2FIND, O1FIND ??related to ~39 ...
?       36-|      | 
        37-|______|
  
Q == Q1 only ?i remove q0 !
Data = D0 only remove D1 
we must add a clear to set full ram to zero ! 
*/

module sis6091B
(
    // Port 0
    input          clk0,
    input          cen0,
    input   [15:0] data0,
    input   [10:1] addr0,
    input   [ 1:0] we0,
    output  [15:0] q0,  //sis 6091 have only one output 
    // Port 1
    input          clk1,
    input          cen1,
    input   [15:0] data1, //sis 6091 have not data 1 it either use first add or scnd ?
    input   [10:1] addr1,
    input   [ 1:0] we1,
    output  [15:0] q1
);

jtframe_dual_ram_cen #(
    .DW        ( 8             ),
    .AW        ( 10 )
)
u_lo(
    .clk0       ( clk0              ),
    .cen0(cen0),
    .clk1       ( clk1              ),
    .cen1(cen1),
    // Port 0
    .data0      ( data0[7:0]        ),
    .addr0      ( addr0             ),
    .we0        ( we0[0]            ),
    .q0         ( q0[7:0]           ),
    // Port 1
    .data1      ( data1[7:0]        ),
    .addr1      ( addr1             ),
    .we1        ( we1[0]            ),
    .q1         ( q1[7:0]           )
);

jtframe_dual_ram_cen #(
    .DW        ( 8             ),
    .AW        ( 10            )
)
u_hi(
    .clk0       ( clk0              ),
    .cen0(cen0),
    .clk1       ( clk1              ),
    .cen1(cen1),
    // Port 0
    .data0      ( data0[15:8]       ),
    .addr0      ( addr0             ),
    .we0        ( we0[1]            ),
    .q0         ( q0[15:8]          ),
    // Port 1
    .data1      ( data1[15:8]       ),
    .addr1      ( addr1             ),
    .we1        ( we1[1]            ),
    .q1         ( q1[15:8]          )
);

endmodule
