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

/* 
jtframe_obj_buffer #(.DW(8),.AW(9), .ALPHAW(4), .BLANK_DLY(1), .KEEP_OLD(1), .FLIP_OFFSET(4)) obj_buffer(
  .clk(clk),
  .LHBL(LHBL), //swap buffer at each line (horizontal blank)
  .flip(1'b0), //flip whole screen ?
  
  .wr_data({color[3:0], plane_color[3:0]}), //in new data writes 
  .wr_addr(line_buffer_index), //in new data addr
  .we(write_pixel), //write_pixel),      //in new data enable

  .rd_addr(line_buffer_addr),  //in read addr
  .rd(pxl_cen),  //pxl cen  //~hblank ?or for each rd ?   //data will be erased after the rd event ! ??
  .rd_data(line_buffer_out)  //output read data
);
*/

module sis6091B
(
    input          clk,
    input          wr_cen,
    input          we,
    input   [15:0] data, //wr_data 
    input   [10:1] addr,
    input          rd_cen,
    //input        swap / LHBL 
    //input        flip ??? 

    //default value -> 15'hf ?  for clear ?  
    input          clr_n, //pin34  
    //output         find, 
    output  [15:0] q //rd_data 
);

// XXX clr 
// use single port ?
// output find ? 

integer i ;
reg [15:0] data_clr; 
reg [10:1] addr_clr;

always @(posedge clk)  begin 
    if (~clr_n) begin  
       for (i=0; i < 1024; i = i+1) begin  
         data_clr[15:0] <= {6'b0, 1'b0, 1'b0, 8'hff};
         addr_clr <= i;
         end
    end 
    else begin  
       addr_clr <= addr; 
       data_clr <= data;
   end     
end
 

jtframe_dual_ram_cen #(.DW(8), .AW(10))
u_lo(
    .clk0(clk),
    .cen0(wr_cen),
    .clk1(clk),
    .cen1(rd_cen),
    // Port 0
    .data0(data_clr[7:0]),
    .addr0(addr_clr),
    .we0(we),
    .q0(),
    // Port 1
    .data1(8'b0),
    .addr1(addr),
    .we1(1'b0),
    .q1(q[7:0])
);

jtframe_dual_ram_cen #(.DW(8), .AW(10))
u_hi(
    .clk0(clk),
    .cen0(wr_cen),
    .clk1(clk),
    .cen1(rd_cen),
    // Port 0
    .data0(data_clr[15:8]),
    .addr0(addr_clr),
    .we0(we),
    .q0(),
    // Port 1
    .data1(8'b0),
    .addr1(addr),
    .we1(1'b0),
    .q1(q[15:8])
);

endmodule
