///////////////////////////////////////////////////
///////////// SG0140 OHMAX ////////////////////////
///////////////////////////////////////////////////

// MODE == 11 OHMAX   ?

//Latch De-Mux
//OVD is multiplexed
//when CTLT 1 : OVD contains high bits of OH (Object Horizontal position)
//when CTLT 2 : OVD contains ADDR (Offset Address ROM) & NOOBJ
module sg0140_ohmax(
  input            clk,
  input            rst, //pin 40
  //input      [1:0] MODE,

  input            NOOBJ,
  // OVD
  input      [8:4] OVD, // OVD[8:4]
  input            HREV, //pin 3 (MASK_A ?)
  input            CTLT1 , //pin 38 //
  input            CTLT2, //pin 39 //PIC_A_EN (6mhz)

  //Object H position extracted from OVD (metdata ?) use to get data from rom ?
  //to get data from rom we need the ROM_INDEX which is stored in some of the
  //RAM and then the line_number % .. need to translate that
  output reg [8:4] OH ,
  output reg [4:0] ADDR,
  output reg       NOOBJ_CT2 //if NOOBJ_CT2 is 0 OBJ1/OBJ2 color are in z state or 'hf in simulation
                             //so nothing is drawn
);

reg [3:0] ADDR_LATCH;
reg ctlt1_d;
reg ctlt2_d;

always @(posedge clk) begin
      if (rst) begin
          OH        <= 5'b0;
          ADDR      <= 5'b0;
          NOOBJ_CT2 <= 1'b0;
          ctlt1_d   <= 1'b1;
          ctlt2_d   <= 1'b1;
          end
      else begin
          ctlt1_d <= CTLT1;
          ctlt2_d <= CTLT2;
          //???? TEST NOOBJ_CT2 tout le temps a 1 ou a 0 pour voir si ca fait
          //quuqchose
          //NOOBJ_CT2 <= NOOBJ; //?  //NOOBJ CT2 must be low if obj is not on the line or we don't want to make it aappear glitch may apear here we must check on the originla if this come only as a copy of NOOBJ each CT2 or if there is something else XXX

          // Phase 1 : Capture ROM index bits (ADDR) from CHAR word
          if (ctlt1_d && !CTLT1) begin
              ADDR[4:0] <= OVD[8:4];
          end

          // Phase 2 : Capture object H position and NOOBJ from HPOS word
          if (ctlt2_d && !CTLT2) begin
              if (~HREV)
                OH[8:4] <= OVD[8:4];
              else
                OH[8:4] <= ~OVD[8:4];
              NOOBJ_CT2 <= NOOBJ;
          end
          //else
            //NOOBJ_CT2 <= 1'b0;
        end
end

endmodule
