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

  //chars rom
  input      [15:0] chars_rom_data,
  input             chars_rom_ok,
  output reg [12:0] chars_rom_addr,
  output            chars_rom_cs,
  //chars rom
  input      [15:0] tiles_rom_data,
  input             tiles_rom_ok,
  output reg [17:0] tiles_rom_addr,
  output            tiles_rom_cs,
   //chars rom
  input      [15:0] sprite_rom_data,
  input             sprite_rom_ok,
  output reg [17:0] sprite_rom_addr,
  output            sprite_rom_cs, 
  //prom 05
  input      [7:0]  prom_05_data,
  input             prom_05_ok,
  output reg [7:0]  prom_05_addr,
  output            prom_05_cs,
  //prom 10
  input      [7:0]  prom_10_data,
  input             prom_10_ok,
  output reg [7:0]  prom_10_addr,
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
assign VBL_ROM = VSYNC; 

assign LVBL = VBL_ROM;
assign LHBL = HBL; // ?

always @(posedge clk) begin 
  if (T8H)
    HBLB <= HBL;
end 

// rom 
assign chars_rom_addr = 13'b0; 
assign chars_rom_cs = 1'b0;
assign tiles_rom_addr = 18'b0;
assign tiles_rom_cs = 1'b0;
assign sprite_rom_addr = 18'b0;
assign sprite_rom_cs = 1'b0;
assign prom_10_addr = 8'b0;
assign prom_10_cs = 1'b0;

//DAC  output 
assign r = 4'hf;
assign g = 4'h0;
assign b = 4'h0;

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
    for (i = 0; i < SIZE; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH.u_hi.mem[i], MEM_PATH.u_lo.mem[i]); \
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

parameter DUMP_START_FRAME = 38;

integer  frame_counter = 0;
always @(posedge VS) begin
   frame_counter = frame_counter + 1;
end

reg dump_done = 0;

always @(posedge clk) begin 
  if (frame_counter == DUMP_START_FRAME && !dump_done) begin
     $display("DUMPING");

     //`dump_ram16("scnddma_u151.bin", 1024, obj_u.scnddma_u.u_151.mem)
     //`dump_ram16("scnddma_u152.bin", 1024, obj_u.scnddma_u.u_152.mem)
     //`dump_ram16_split("scnddma_u153.bin", 1024, obj_u.scnddma_u.u_153)
     //`dump_ram16_split("objdma_u141.bin", 1024, obj_u.objdma_u.u_141);
     //`dump_ram16("linebuf_u181.bin", 1024, obj_u.linebuf_u.u_181.mem)
     //`dump_ram16("linebuf_u182.bin", 1024, obj_u.linebuf_u.u_182.mem)
     //`dump_ram16("linebuf_u183.bin", 1024, obj_u.linebuf_u.u_183.mem)
     //`dump_ram16("linebuf_u184.bin", 1024, obj_u.linebuf_u.u_184.mem)

     //`dump_ram16_split("cpu_ram.bin", 32768, $root.game_test.u_game.u_game.u_main.u_cpu_ram)

     dump_done <= 1;
     end 
end

`endif

endmodule
