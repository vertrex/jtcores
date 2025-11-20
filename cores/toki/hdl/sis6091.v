/* 
* SIS 6091 PIN 

           ________
WE0     30-|      |-6  D0-0  
CLK0    31-|      |-7  D0-1
        27-|      |-8  D0-2 
        28-|      |-10 D0-3 
           |      |-12 D0-4 
A0-0    62-|      |-13 D0-5 
A0-1    63-|      |-14 D0-6
A0-2    64-|      |-15 D0-7
A0-3    65-|      |-16 D0-8
A0-4    66-|      |-17 D0-9
A0-5    67-|      |-18 D0-10 
A0-6    68-|      |-19 D0-11 
A0-7    69-|      |-22 D0-12
A0-8    70-|      |-23 D0-13
A0-9    71-|      |-24 D0-14 
           |      |-25 D0-15 
A1-0    75-|      |
A1-1    76-|      |-42 Q-0 
A1-2    77-|      |-43 Q-1 
A1-3    78-|      |-44 Q-2  
A1-4    79-|      |-45 Q-3 
A1-5    80-|      |-46 Q-4 
A1-6     1-|      |-47 Q-5 
A1-7     3-|      |-48 Q-6 
A1-8     4-|      |-49 Q-7 
A1-9     5-|      |-51 Q-8  
           |      |-53 Q-9  
DIR?    26-|      |-54 Q-10
?       35-|      |-55 Q-11
        40-|      |-56 Q-12 
RAM CLR 34-|      |-57 Q-13 
CLK1    73-|      |-58 Q-14 
        33-|      |-59 Q-15
?       38-|      | 
        39-|      |-60  //ACTIVATE SELECT ? O2FIND, O1FIND ??related to ~39 ...
?       36-|      | 
        37-|______|
  
Q == Q1 only ?i remove q0 !
Data = D0 only remove D1 
we must add a clear to set full ram to zero ! 
*/

module sis6091
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
    .AW        ( 10            )
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
