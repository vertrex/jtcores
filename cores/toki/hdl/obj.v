////////// SCAN SPRITE RAM  /////////////////////////////
//
// draw 16x16 sprite line by line
// 
//
module scan_obj_ram(
  input                 clk,
  input                 rst,

  input                 pxl_cen,
  input                 LHBL,

  input           [7:0] vpos,
 
  //XXX two ram chips to copy two words will be faster?
  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output reg     [19:1] gfx_rom_addr,
  output reg            gfx_rom_cs,

  input           [8:0] line_buffer_addr, //8:0 ??
  output          [7:0] line_buffer_out
);

/// STATE MACHINE
reg [3:0] state = 4'd0;
parameter STATE_START =           4'd0;
parameter STATE_FETCH_RAM_WORDS = 4'd1;
parameter STATE_COPY_RAM_WORDS  = 4'd2;
parameter STATE_START_DECODING  = 4'd3;
parameter STATE_DECODING_CHECK  = 4'd4;
parameter STATE_FETCH_ROM_WORDS = 4'd5;
parameter STATE_COPY_ROM_WORDS  = 4'd6;
parameter STATE_PLANE_COLOR     = 4'd7;
parameter STATE_COPY_PIXEL      = 4'd8;
parameter STATE_FINISHED        = 4'd9;

reg  [7:0]  previous_vpos;

reg         flip_x;
reg  [3:0]  color;
reg  [8:0]  x;
reg  [8:0]  y;

reg [12:0] rom_index; //0xFFF / 4096 tiles 

reg  [3:0] pix_index; //4*4 pix => 16 pix 
reg [15:0] ram_words [3:0];
reg  [1:0] ram_words_index;
reg [15:0] rom_words;
reg  [1:0] rom_words_index;

reg [15:0] plane1, plane2, plane3, plane4;

reg [8:0] line_buffer_index;
reg [3:0]  plane_color;

reg write_pixel;

jtframe_obj_buffer #(.DW(8), .AW(9), .ALPHAW(4), .BLANK_DLY(2), .KEEP_OLD(1), .FLIP_OFFSET(4)) obj_buffer(
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

always @(posedge clk, posedge rst) begin
    if (rst) begin
      previous_vpos <= 8'd0;
      flip_x <= 1'd0;
      pix_index <= 4'd0;
      rom_index <= 13'd0;
      rom_words_index <= 2'd0;
      ram_words_index <= 2'b0;
      ram_addr <= 10'h0;
      write_pixel <= 1'b0; 
      state <= STATE_START;
      end
    else begin
    case (state)
      STATE_START : begin
        previous_vpos <= vpos;
        write_pixel <= 1'b0; 
        pix_index <= 4'd0;
        rom_index <= 13'd0;
        rom_words_index <= 2'd0;
        ram_words_index <= 2'b0;
        ram_addr <= 10'h0;
        state <= STATE_FETCH_RAM_WORDS;
      end      

      STATE_FETCH_RAM_WORDS : begin
         write_pixel <= 1'b0;
         ram_words[ram_words_index] <= ram_out[15:0];
         ram_addr <= ram_addr + 10'd1;
         state <= STATE_COPY_RAM_WORDS;
      end

      STATE_COPY_RAM_WORDS: begin
        //XXX SKIP UNUSED there is glitch after the big machine in level 1 
        if (ram_addr == 'h3ff) begin
           state <= STATE_FINISHED;
           end
        else begin
          if (ram_words_index == 2'd0 && ram_words[0] == 'hf000)
            state <= STATE_FINISHED;
          else if (ram_words_index  == 2'd2 && ram_words[2] == 'hf000)
            state <= STATE_FINISHED;
          else if (ram_words_index == 2'd3) begin
            state <= STATE_START_DECODING;
            ram_words_index <= 2'd0;
            end
          else begin
            ram_words_index <= ram_words_index + 2'd1; 
            state <= STATE_FETCH_RAM_WORDS;
          end
        end
      end

      STATE_START_DECODING : begin
         if (({ram_words[2][15], ram_words[1][11:0]} != 13'b0)) begin
           //XXX MUST SKIP GLITCH
           flip_x <= ram_words[0][8];
           color <= ram_words[1][15:12];
           rom_index[12:0] <= {ram_words[2][15], ram_words[1][11:0]};
           x[8:0] <= ram_words[2][8:0] + (ram_words[0][7:4] * 8'd16); 
           y[8:0] <= ram_words[3][8:0] + (ram_words[0][3:0] * 8'd16);
           rom_words_index <= 2'd0;
           pix_index <= 0;
           // check  here ? 
           state <= STATE_DECODING_CHECK;
           end
         else
           state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_DECODING_CHECK: begin
        if (({1'b0, vpos[7:0]} >= y && {1'b0, vpos[7:0]} <= y + 15) && (x < 256 || x[8:0] > 9'd497)) begin
           state <= STATE_FETCH_ROM_WORDS;
           end 
         else 
           state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_FETCH_ROM_WORDS : begin
        write_pixel <= 1'b0;
        if (rom_words_index <= 1)
          //XXX XXX look at sprite.v & char.v 
          gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, vpos[7:0]} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index});
        else
          gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, vpos[7:0]} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index}%19'd2) + 19'd32;
        gfx_rom_cs <= 1'b1; 
        state <=  STATE_COPY_ROM_WORDS;
      end 

      STATE_COPY_ROM_WORDS : begin 
        if (gfx_rom_ok)  begin
          rom_words <= gfx_rom_data[15:0];
          gfx_rom_cs <= 1'b0;
          //prefetch next rom addr so it won't ait to much time ? 
          state <= STATE_PLANE_COLOR;
          end
      end

      STATE_PLANE_COLOR:begin
        //use rom_words index to know which rom words to know which offset
        //from current pixel ? 
        //read directly the 4 pixel so it goes in 1 cycle ?
        //rather than 4 ? 
        //pixel 1 2,3,4 
        //pix_index - (rom_words_index * 4)
        // write directly 32 bits 4 pixel in obj_buffer ? 
        // XXX 
        plane_color <= {rom_words[pix_index - (rom_words_index*4)+ 12], rom_words[pix_index - (rom_words_index*4) + 8], rom_words[pix_index - (rom_words_index*4) + 4], rom_words[pix_index - (rom_words_index*4)]};
        write_pixel <= 1'b0;
        line_buffer_index <= flip_x ?  x[8:0] + 8'd15 - {5'b0, pix_index} :
                                             x[8:0] + {5'b0, pix_index};
        state <= STATE_COPY_PIXEL;
      end 

      STATE_COPY_PIXEL: begin 
        write_pixel <= 1'b1;
        if (pix_index < 15) begin
          pix_index <= pix_index + 4'd1;
          if (pix_index + 1 == 4 || pix_index + 1 == 8 || pix_index + 1 == 12) begin
            rom_words_index <= rom_words_index + 2'd1;
            state <= STATE_FETCH_ROM_WORDS;
          end 
          else 
            state <= STATE_PLANE_COLOR; 
          end              
        else if (ram_addr == 'h3ff) 
          state <= STATE_FINISHED; 
        else
          state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_FINISHED: begin
        write_pixel <= 1'b0; 
        ram_addr <= 10'h0;
        if (previous_vpos != vpos)
          state <= STATE_START;
        previous_vpos <= vpos;
      end
     
      default:
          $display("sprite state machine error !");

    endcase
  end
end

endmodule
