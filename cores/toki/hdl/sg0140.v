///////////////////////////////////////////////////
///////////// SG0140 ABSEL ////////////////////////
///////////////////////////////////////////////////

// SG0140 
//
//priority / color mixer
// SG 0140 have 4 different mode 
// mode is selected with pin 37/36

//        37,36 
// MODE == 00 ABSEL (absolut selection or a b / select? )
// MODE == 10 VCHECK  ? 
// MODE == 01 SORT4B  ? 
// MODE == 11 OHMAX   ? 

//sg0140_absel 
module sg0140(
  input       clk, // 
  //input       rst,// pin 40 
  input       cen, // pin 41, 38, 26 clock & enable

  //BK1 
  input [3:0] PIC_A, //pin 9-12  
  //input     PIC_A_EN //pin 38 6Mhz  enable color  ? 
  input [3:0] COL_A, //pin 13-16 
  input       COL_A_EN,// pin 39 
  input       MASK_A,  // pin 3 

  // CHAR
  input [3:0] PIC_B, //pin 28-31 
  //input     PIC_B_EN //pin 26 6Mhz enable color  ? 
  input [3:0] COL_B, //pin 32-35
  input       COL_B_EN,   // pin 27 enable  
  input       MASK_B, // pin 2
  input [1:0] MODE, //pin 36,37

  output reg  [7:0] Q,  //17-20,23-25

  output reg  ON_A, //pin 8 
  output reg  ON_B //pin 7
); 

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)   
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH; 

always @(posedge clk) begin 
  if (cen) begin 
    if (COL_B_EN)
       COL_B_LATCH[3:0] <= COL_B[3:0];

    if (COL_A_EN)
       COL_A_LATCH[3:0] <= COL_A[3:0];

    ON_A <= (PIC_A[3:0] == 4'hf) ? 1'b0 : 1'b1;
    ON_B <= (PIC_B[3:0] == 4'hf) ? 1'b0 : 1'b1;

    Q[7:0] <= PIC_B[3:0] != 'hf ?  {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                   {COL_A_LATCH[3:0], PIC_A[3:0]};
  end
end

endmodule

///////////////////////////////////////////////////
///////////// SG0140 OHMAX ////////////////////////
///////////////////////////////////////////////////

// MODE == 11 OHMAX   ? 

//sg0140_absel 
module sg0140_ohmax(
  input       clk,
  input       rst, //pin 40
  input       cen,
  input [1:0] MODE,

  //input [5:0] D, 
  input NOOBJ,
  input [4:0] OVD,
  input HREV, //pin 3 (MASK_A ?)
  input CTLT1 , //pin 38 //
  input CTLT2, //pin 39 //PIC_A_EN (6mhz)
  
  //Q 
  output reg [8:4] OH ,
  output reg [4:0] ADDR,
  output reg NOOBJ_CT2
); 

always @(posedge clk or posedge rst) begin 
  if (rst) begin 
    OH <= 5'b0;
    ADDR  <= 5'b0;
    end 

  else if (clk)begin 
     if (CTLT1)
      OH[8:4]  <= OVD[4:0]; 

    if (CTLT2)
      ADDR[4:0] <= OVD[4:0]; 

    if (CTLT2)
      NOOBJ_CT2 <= NOOBJ;
    //Q <= { NOOBJ_CT2, D[4:0], D[4:0]};
  end 
  
end 
endmodule

///////////////////////////////////////////////////
///////////// SG0140 VCHECK ///////////////////////
///////////////////////////////////////////////////

//see explanation on hvpos : 
//it calcualte and output the line % 16 diff to know which pixel is the line
// on and use that as address, 
// but it never get vpos but it get all info to calcualte it himself 
// so maybe it just keep a counter at start of 4'b0 
// and then calcualte with the VPD the %16 of the line 
// and output it that's all !
// then tehre is EVNWR2 & ODDWR2 it wwrite one time to one and one t ime the
// other 
// we may want to switch that for each line 
// we have a counter so it's easy
// maybe it was to avoid giving all the signal but that seems super complex 
// way of doing it ...
// we may also not pass signal for over 256 
// or if objen is not enable 
//

module sg0140_vcheck(
  input             clk,
  input             rst, //pin 40
  //VPD [0:4] seems low by default and high when activated 
  //VPD [7:5] seem  high by default and low  when activated
  //  ram_words[0][3:0n ( 16 + pos )
  //  is that just synchronize with screen VCLK and has an internal counter to
  //  know on which line we are ? 
  //  it count line it self and make the dif f?????? 
  //

  // {OFST[3:0], } when toki only it's always the same value :
  input       [7:0] VPD,     
  // set by main.addrs to start object DMA request 
  // it alert the controller that a transfer will happen
  input             ODMARQ, // always same frequency 
  // OBUSAK = ~BUSAK & ~BUSRQ  bus request acknowledge by the cpu 
  // CPU assert that the bus is ready and can be used by 
  // the DMA controller and will stop driving address bus
  input             OBUSAK, // always same frequency 
  input             SDTS,   // 59.61khz when high evnwr2 & oddwr2 is high (there are active low) 
  input             VORIGIN,// always same frequency : 
  // ACTIVE HIGH when DMA is counting 
  // it's the inverse of the DMA counter activation Q_148 
  // which is high when DMA counter compute address
  // so we certainly need to get OBUSRQ LOW UNTIL OVER256 i high 
  input             OVER256,// active low 15.61khz high always at same moment, evn and odd is high too
  

  input             OVER48, // just an ack that VFIND was received by other sg0140 and we can continue ? 
  input             VREVD_2,// OBJ_DB[9] active low (active during attract when there is the magician), generally active when there is sprite but not during cave stuff  is that   isd that the 8 bit if > 256 or in other screen like {VREV, VPD} % 16  
  input             OBJEN_3,// it seem to only appear when there is a new object on the screen like toki, a fireball
  // or a new ennemy then it doesn't appear if it's already in memory ? 
  
  input             H2,     // every 4 pixel ? 
  input             RDCLK,  // 6mhz 
  input             VCLK,   // 15.61khz
  input             VREV,   // should be used only as reverse axis strange
  input             NV256,  // 59.61 high at half period when over256 is high (>256 v  over256 >256 h ?)  // ? 
  //output 
  output reg  [3:0] VMT,    // output y pos - current line % 16   
  //address is 19:1 
  output reg        EVNWR2, // use DMA2_EA of other sg0140 ?    @6mhz  
  output reg        ODDWR2, // use DMA2_OA of other sg0140 in scndma  @6mhz 

  //RELATED TO OBUSAK  (~BUSAK & ~UBSRQ) but when does it end ?  
  //active low after OBUSAK, it will write address from FDA[10:1] to the
  //memory address bus so we can read data from the memory of the cpu 
  //and copy all object to other memory during this time frame 
  //
  //it's also assigned to OBUSDIR that is use in main.PLD to assert BUSOPEN 
  // OBUSDIR is also used to main bgack_n low via pld20
  // so it effectively keep the bus ack low until obusdir / oibdir finish 
  output reg        OIBDIR,  //ACTIVE LOW, becore low avec OBUSRQ change to become high again 
                             // until ???

  // asserted by dma controller (us) after receving the ODMARQ  to tell 
  // that it's ready to handle request
  // generally become low when finish the request 
  // but here we get it low before OIBDIR is getting low which is strange
  output reg        OBUSRQ, // ACTIVE LOW, low one cycle before OIBDIR CHANGE 
  
  output            VFIND   // == OVER256 (send OVER256 to next sg0140 ?)   
);

assign VFIND = OVER256;

reg [8:0] line_number; 

always @(posedge clk or posedge rst) begin 
  if (rst) begin
    OBUSRQ <= 1'b1; 
    OIBDIR <= 1'b1; 
    EVNWR2 <= 1; 
    ODDWR2 <= 1;
    end 

  else if (clk) begin 
    //reset line number
    //at vblank
    //
    if (~RDCLK) begin // &SDTS ?  

      if (~SDTS) 
        line_number <= 0;
      else if (VCLK) 
        line_number <= line_number +  1; 

      if (~ODMARQ) begin 
        //we acknowledge we receive dma request 
        //and we're ready 
        OBUSRQ <= 1'b0;
        end 

      // CPU IS READY WE  CAN READ DATA FROM MEMORY 
      if (~OBUSAK)  begin 
        OBUSRQ <= 1'b1; 
        OIBDIR <= 1'b0; 
        end 

      //OIBDIR must be low until we get OVER256 low  ? 
      //becaue if OVER256 is low it mean the dma counter finished
      //so we can stop reading  from the memory bus 
      // by setting oibdir to 0
      if (OVER256 == 1'b0) begin 
        OIBDIR <= 1'b1;
        end 

      // if  < NV256  & OBJ_EN  ? to avoid reprocess it ? 
      // TEST ON TOKI sprite ?
      //output to EVNWR2 or ODDWR2 depending of line number [0] ? 
      if (line_number >= {1'b0, VPD[7:0]} + 15 && line_number <= {1'b0, VPD[7:0]} + 15) begin 
        VMT[3:0] <= ((line_number - {VREVD_2, VPD[7:0]}) % 16);
      end 

      // EVNWR & ODDWR are clocked @rdclk 
      // and are activated between OVER256 & OVER48 

      //XXX We;re stuck here becauuse we never put the line 
      //down because the counter never start 
      //so it never end because we never get OVER256 & OVER48 down
      //as counter never start need to check u144..u147

      if (~OVER256 & ~OVER48) begin 
        if (line_number[0]) begin 
          EVNWR2 <= 1'b0;
          ODDWR2 <= 1'b1;
          end 
        else begin 
          ODDWR2 <= 1'b0;
          EVNWR2 <= 1'b1; 
          end 
        end 
      else begin 
        EVNWR2 <= 1'b1; 
        ODDWR2 <= 1'b1;
        end 
    
    end 
  end 
end 


endmodule

///////////////////////////////////////////////////
///////////// SG0140 SORT 40///////////////////////
///////////////////////////////////////////////////

module sg0140_sort40(
  input       clk,
  input       rst, //pin 40

  input   RDCLK, //main clk ? 

  // condition ? 
  //input   OVER48, //active high 
  input   VFIND, //OVER256 active high when dma is counting 

  input   XSDTS,
  input   ILD2,
  input   NH2,  //~h_pos[1] 

  //clk & enable ? 
  input   V1B,  //vpos[0]
  input   H2,   // 38 A_EN ?  //h_pos[1]
  input   H2_2, //h_pos[1] EN ? 
  
  // 5 output signal do DMA2 ???? 
  input   H16,  //h_pos[4]
  input   H32,  //h_pos[5]
  input   H64,  //h_pos[6]
  input   H128, //h_pos[7]
  input   H256, //h_pos[8]
  
  output reg  OVER48, //just ack that we receive vfind from the other sg0140 ? to syncrhonize ?
  output reg  [5:0] DMA2_EA,
  output reg  [5:0] DMA2_OA
);


always @(posedge clk, posedge rst) begin 
  if (rst) begin 
      DMA2_EA <= 6'b0; 
      DMA2_OA <= 6'b0;
      end 
  else if (RDCLK) begin  // &~XSDTS ? 
      if (V1B == 1'b1)  begin  //ligne impair  ? 
        DMA2_OA <= {H256, H128, H64, H32, H16, H2}; 
        end 
      else begin 
        DMA2_EA <= {H256, H128, H64, H32, H16, H2};
        end 

        // CHECK CLOCK HERE BECAUSE VFIND TAKE SOME TIME SO IT MAY USE AN
        // OTHER CLOCK TO CHANGE ILD2 ? XSDTS ??
      if (VFIND == 1'b1) 
        OVER48 <= 1'b0;
      else 
        OVER48 <= 1'b1;
  end 
end 
  

endmodule 
