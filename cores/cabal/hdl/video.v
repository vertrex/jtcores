module cabal_video(
  input             rst,

  // Clock
  input             clk,
  input             P6M,
  input             N6M,

  // Video out
  input       [3:0] gfx_en, // debug : graphical layer enable

  output            HS,
  output            VS,
  output            LHBL,
  output            LVBL,
  output reg        HBLB,
  output            INT_T,
  output      [8:0] hpos,
  output      [8:0] vpos,

  // Shared video RAM (XXX)
  output     [10:1] palette_ram_addr,
  input      [15:0] palette_ram_out,

  output     [10:1] char_ram_addr,
  input      [15:0] char_ram_out,

  output      [8:1] tile_ram_addr,
  input      [15:0] tile_ram_out,

  output     [10:1] sprite_ram_addr,
  input      [15:0] sprite_ram_out,

  //chars rom
  input      [15:0] chars_rom_data,
  input             chars_rom_ok,
  output     [13:1] chars_rom_addr,
  output            chars_rom_cs,
  //chars rom
  input      [15:0] tiles_rom_data,
  input             tiles_rom_ok,
  output     [18:1] tiles_rom_addr,
  output            tiles_rom_cs,
   //chars rom
  input      [15:0] sprite_rom_data,
  input             sprite_rom_ok,
  output     [18:1] sprite_rom_addr,
  output            sprite_rom_cs, 
  //prom 05
  input      [7:0]  prom_05_data,
  input             prom_05_ok,
  output reg [7:0]  prom_05_addr,
  output            prom_05_cs,
  //prom 10
  input      [7:0]  prom_10_data,
  input             prom_10_ok,
  output     [7:0]  prom_10_addr,
  output            prom_10_cs,

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b
);

////////// VIDEO SYNC /////////////
//
wire HBL;
wire L3;
wire HD;
wire VSYNC; //seems to be ~ sei0050bu XXX (page 5)
wire T8H;
wire T3F;
wire T4H;
wire VCLK;
wire N1H;

SEI0050BU sei0050bu_u(
  .clk(clk),
  .rst(rst),
  .P6M(P6M),
  .N6M(N6M),

  .VBL_ROM(VBL_ROM),
  .hpos(hpos),
  .vpos(vpos),

  .N1H(N1H),
  .T8H(T8H), //char cen
  .HBL(HBL),
  .L3(L3),
  .T3F(T3F),
  .T4H(T4H),
  .HD(HD),
  .VSYNC(VSYNC),
  .VCLK(VCLK),
  .HS(HS),
  .VS(VS)
);


wire VBL_ROM;

assign prom_05_cs = 1'b1;

always @(posedge clk)
  if (~N6M) begin
    prom_05_addr[7:0] <= vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)
  end

// Based on Toki schematics 
//assign OBJT1 =   prom_26_data[0];
//assign STARTV =  prom_26_data[2];
//assign VORIGIN = prom_26_data[3];
assign INT_T =   prom_05_data[4];
assign VBL_ROM = prom_05_data[7];
//assign OBJT2 =   prom_26_data[1]; //need to be latched

assign LVBL = VBL_ROM;
assign LHBL = HBL; // ?

always @(posedge clk) begin
  if (T8H)
    HBLB <= HBL;
end 


// rom 
assign prom_10_addr = 8'b0;
assign prom_10_cs = 1'b0;


////// TEXT / CHAR ////////// 
// 
//
wire [1:0] char_code;
wire [5:0] char_color;
assign chars_rom_cs = 1'b1;

scrn_char u_scrn_char(
  .clk(clk),
  .rst(rst),
  .pxl_cen(N6M),
  //+ decallage a gauche 
  .vpos(vpos[8:0]), //+8'd1 ?
  .hpos(hpos[8:0] + 9'd1),

  .char_ram_addr(char_ram_addr),
  .char_ram_out(char_ram_out),

  .char_rom_data(chars_rom_data),
  .char_rom_ok(chars_rom_ok),
  .char_rom_addr(chars_rom_addr),

  .code(char_code),
  .color(char_color)
);  


////// BK / TILES ////////// 
// 
//
wire [3:0] bk_code, bk_color;
assign tiles_rom_cs = 1'b1;

scrn_bk u_scrn_bk(
  .clk(clk),
  .rst(rst),
  .pxl_cen(N6M),
  .vpos(vpos[8:0]), //+8'd1 ?
  .hpos(hpos[8:0]),

  .tile_ram_addr(tile_ram_addr),
  .tile_ram_out(tile_ram_out),

  .bk_rom_data(tiles_rom_data),
  .bk_rom_ok(tiles_rom_ok),
  .bk_rom_addr(tiles_rom_addr),

  .code(bk_code),
  .color(bk_color)
);  

assign sprite_rom_addr = 18'b0;
assign sprite_rom_cs = 1'b0;
assign sprite_ram_addr[10:1] = 10'b0;

//DAC  output 
assign palette_ram_addr[10:1] = 
                                (char_code[1:0] != 'h3) ?  {2'd0, char_color[5:0], char_code[1:0]} : 
                                (  bk_code[3:0] != 'hf) ?  {2'b10,  bk_color[3:0], bk_code[3:0]}
                                : 'h3ff;

assign r = palette_ram_out[3:0];
assign g = palette_ram_out[7:4];
assign b = palette_ram_out[11:8];

/////// RAM DUMP ////////
//
//
//


`ifdef SIMULATION

`define dump_ram16_split(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE/2; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH.u_hi.mem[i], MEM_PATH.u_lo.mem[i]); \
    end \
    $fclose(fd); \
end

`define dump_dual_ram16_split(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE/2; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH.u_hi.u_ram.mem[i], MEM_PATH.u_lo.u_ram.mem[i]); \
    end \
    $fclose(fd); \
end

`define dump_ram16(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH[i][15:8], MEM_PATH[i][7:0]); \
    end \
    $fclose(fd); \
end

// Macro pour dumper une RAM 8 bits (si jamais tu en as besoin pour le SIS6091 standard)
`define dump_ram8(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
      $fwrite(fd, "%c", MEM_PATH[i]); \
    end \
    $fclose(fd); \
end

parameter DUMP_START_FRAME = 4;

integer  frame_counter = 0;
always @(posedge VS) begin
   frame_counter = frame_counter + 1;
end

reg dump_done = 0;

always @(posedge clk) begin 
  if (frame_counter == DUMP_START_FRAME && !dump_done) begin
     $display("DUMPING");

     `dump_ram16_split("cpu_ram.bin", 32768, $root.game_test.u_game.u_game.u_main.u_cpu_ram)
     `dump_dual_ram16_split("video_ram.bin", 512, $root.game_test.u_game.u_game.u_main.u_tile_ram)
     `dump_dual_ram16_split("palette_ram.bin", 2048, $root.game_test.u_game.u_game.u_main.u_palette_ram)
     `dump_dual_ram16_split("color_ram.bin", 2048, $root.game_test.u_game.u_game.u_main.u_char_ram)
     //`dump_dual_ram16_split("sprite_ram.bin", 1024, $root.game_test.u_game.u_game.u_main.u_sprite_ram)

     dump_done = 1;
     end 
end

`endif

endmodule
