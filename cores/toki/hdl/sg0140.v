// priority / color mixer
//
// MODE == ABSEL (absolut selection or a b / select? )
// MODE == YCHECK  ? 
// MODE == SORT4B  ? 
// MODE == OHMAX   ? 
module sg0140(
  input clk, //n6m 

  input [3:0] char_color,
  input [3:0] char_code, 
  input       char_en, //? S4CLLT T8H 
  input       char_mask, // S4MASK ? char_cs ?  page 3 address selection 

  input [3:0] bk1_color,
  input [3:0] bk1_code,  
  input       bk1_en,// S1 CLLT hpos 0
  input       bk1_mask, // ? S1MASK page 3 address selection   bk2 select ? 

  output reg [1:0]     pri, 

  output reg [7:0] palette_addr
); 

//it seem sg0140 get other input like clk from other module like bk 1 output
//scroll pos0 etc 
//it certainly do other stuff like partial mixing
//
reg [7:0] char_latch;
reg [7:0] bk_latch; 

//always @(posedge clk) begin 
  //met pri a 1 si un des deux et differ de hf ?
  //if (char_en)
//always @(posedge char_en)
    //char_latch[7:0] <= {char_code[3:0], char_color[3:0]};

//always @(posedge bk_en)
  //if (bk_en)
    //bk_latch[7:0] <= {bk1_code[3:0], bk1_color[3:0]};

always @(posedge clk) begin 
    bk_latch[7:0] <= {bk1_code[3:0], bk1_color[3:0]};
    char_latch[7:0] <= {char_code[3:0], char_color[3:0]};

    pri <= {  
           char_latch[3:0] == 'hf ? 1'b0: 1'b1,
           bk_latch[3:0] == 'hf ? 1'b0 : 1'b1
         };

  //  00   bk1 0 char 0 (e)
  //  01   bk1 1 char 0 (8)   
  //  10   bk1 0 char 1 (4)
  //  11   bk1 1 char 1 (4) //char > bk1 so ok

  //pri <= { bk1_color[3:0] != 'hf ? 1'b0 : 1'b1, 
           //char_color[3:0] != 'hf ? 1'b0: 1'b1 };
  //assign ? 
  palette_addr[7:0] <= char_latch[3:0] != 'hf ?  char_latch :
                                                 bk_latch;
end

endmodule
