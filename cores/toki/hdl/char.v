////////// char ram  //////////////////////////////////
//
// State machine that draw a line of 8x8 tile
// each time line number change.
// RAM is fully scanned, address in ram give 
// tile position on screen, there is 32 tiles by line
// RAM data describe a tile :
//  -  [3:0] color
//  - [11:0] index of tile in ROM 
//  
//  Tile data are DWORD stored in ROM as 4 bit planes 
//  second dword of each data is at address + 0x8000
//
//  each pixel of tile are 8 bits : 
//    4 bits color, 4 bits index (rom data)
//  pixel are transparent if ROM data is 0xf
//  pixel value is an index into the video palette 
//
module scan_char_ram(
  input                 clk,
  input                 rst,

  input           [7:0] line_number,

  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  //input          [15:0] gfx_rom_data,
  //input                 gfx_rom_ok,
  //output reg     [16:1] gfx_rom_addr,
  //output reg            gfx_rom_cs,

  input           [15:0] char_rom_1_data,
  input                 char_rom_1_ok,
  output reg     [15:1] char_rom_1_addr,
  output reg            char_rom_1_cs,

  input           [15:0] char_rom_2_data,
  input                 char_rom_2_ok,
  output reg     [15:1] char_rom_2_addr,
  output reg            char_rom_2_cs,



  input           [7:0] line_buffer_addr,
  output          [7:0] line_buffer_out
);

(* ramstyle = "no_rw_check" *)reg [7:0] line_buffer [255:0];
assign line_buffer_out = line_buffer[line_buffer_addr];

reg [3:0]  state = 4'd0;

parameter STATE_START = 4'd0;
parameter STATE_FETCH_RAM  = 4'd1;
parameter STATE_COPY_ROM_WORDS = 4'd2;
//parameter STATE_COPY_SECOND_ROM_WORD = 4'd3;
parameter STATE_FETCH_PIXEL = 4'd4;
parameter STATE_FINISHED = 4'd5;
parameter STATE_NEXT_PIXEL = 4'd6;
parameter STATE_WAIT_RAM = 4'd7;
parameter STATE_FETCH_ROM = 4'd8;

reg  [4:0] tile_index;
reg [15:0] first_rom_word;
reg [15:0] second_rom_word;
reg  [2:0] pix_index;
reg  [7:0] previous_line_number;

reg  [3:0] color;
reg [11:0] rom_index; //4096 tiles 

always @(posedge clk, posedge rst) begin
  if (rst) begin 
      tile_index <= 0;
      pix_index <= 0;
      state <= STATE_START;
      end
  else begin  
    case (state)
      STATE_START : begin
        tile_index <= 0;
        pix_index <= 0;
        state <= STATE_FETCH_RAM;
      end

      STATE_FETCH_RAM: begin
        ram_addr[10:1] <= (({2'b0, line_number}/10'd8)*10'd32) + {5'b0, tile_index[4:0]};
        state <= STATE_WAIT_RAM; 
      end

      STATE_WAIT_RAM: begin //if not there is a 8 pix shift ... XXX
        state <= STATE_FETCH_ROM; 
      end  

      STATE_FETCH_ROM: begin
        rom_index[11:0] <= ram_out[11:0];
        color[3:0] <= ram_out[15:12];
        char_rom_1_addr[15:1] <= (ram_out[11:0]*15'd8) + ({7'h0, line_number}%15'd8);
        char_rom_2_addr[15:1] <= (ram_out[11:0]*15'd8) + ({7'h0, line_number}%15'd8);
        char_rom_1_cs <= 1'b1;
        char_rom_2_cs <= 1'b1;
        state <= STATE_COPY_ROM_WORDS;
      end  

      STATE_COPY_ROM_WORDS: begin 
       if (char_rom_1_ok & char_rom_2_ok) begin 
          char_rom_1_cs <= 1'b0;
          char_rom_2_cs <= 1'b0;
          ///XXX no need to copy ... ?
          first_rom_word[15:0] <= char_rom_1_data[15:0];
          second_rom_word[15:0] <= char_rom_2_data[15:0]; 
          pix_index <= 3'b0;
          state <= STATE_FETCH_PIXEL;
          end
      end

      STATE_FETCH_PIXEL:  begin
        //8 bits : color 4 bits, 4 bits index
        //pix index         
        //0 {second_rom_word[4], second_rom_word[0], first_rom_word[4], first_rom_word[0]}
        //1 {second_rom_word[5], second_rom_word[1], first_rom_word[5], first_rom_word[1]}
        //2 {second_rom_word[6], second_rom_word[2], first_rom_word[6], first_rom_word[2]}
        //3 {second_rom_word[7], second_rom_word[3], first_rom_word[7], first_rom_word[3]}
       
        // 
        //4 {second_rom_word[12], second_rom_word[8], first_rom_word[12], first_rom_word[8]}
        //5 {second_rom_word[13], second_rom_word[9], first_rom_word[13], first_rom_word[9]}
        //6 {second_rom_word[14], second_rom_word[10], first_rom_word[14], first_rom_word[10]}
        //7 {second_rom_word[15], second_rom_word[11], first_rom_word[15], first_rom_word[11]}
        
        if (pix_index < 4)
          line_buffer[tile_index*8 + {2'b0, pix_index}] <= {color[3:0], {second_rom_word[pix_index + 4], second_rom_word[pix_index + 4'd0], first_rom_word[pix_index + 4], first_rom_word[pix_index + 4'd0]} };
        else 
          //XXX use 8 bits rom and do +1 rather than fetching two 16 bits 
          line_buffer[tile_index*8 + {2'b0, pix_index}] <= {color[3:0], {second_rom_word[pix_index + 8], second_rom_word[pix_index + 4], first_rom_word[pix_index + 8], first_rom_word[pix_index + 4]} };

        //if ({plane4[pix_index],plane3[pix_index],plane2[pix_index],plane1[pix_index]} == 'hf)
          //line_buffer[tile_index*8 + {2'b0, pix_index}] <= 'hf;
        state <= STATE_NEXT_PIXEL;
      end

      STATE_NEXT_PIXEL: begin
        if (pix_index < 3'd7) begin
          pix_index <= pix_index + 2'd1;
          state <= STATE_FETCH_PIXEL;
          end
        else if (pix_index == 7) begin
          if (tile_index == 31)
            state <= STATE_FINISHED;
          else begin
            tile_index <= tile_index + 1'b1; 
            state <= STATE_FETCH_RAM;
            end
          end
      end

      STATE_FINISHED: begin
        if (previous_line_number != line_number) begin
          tile_index <= 0;
          pix_index <= 0;
          state <= STATE_START;
          end
        previous_line_number <= line_number;
      end
    
     default : 
       state <= STATE_FINISHED;

    endcase 
    end
end

endmodule
