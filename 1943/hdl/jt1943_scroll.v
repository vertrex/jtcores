/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-2-2019 */

// 1943 Scroll Generation
// Schematics pages 8/15...

module jt1943_scroll(
    input              rst,
    input              clk,  // >12 MHz
    input              cen6  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              cen3,
    input       [ 7:0] V128, // V128-V1
    input       [ 8:0] H, // H256-H1
    input              LVBL,

    input       [ 1:0] scrposh_cs,
    input       [ 7:0] vpos,
    input              SCxON,
    input              flip,
    input       [ 7:0] din,
    input              wr_n,

    input              pause,
    // Palette PROMs D1, D2
    input   [7:0]      prog_addr,
    input              prom_msb_we,
    input              prom_lsb_we,
    input   [3:0]      prom_din,    

    // Map ROM    
    output reg  [13:0] map_addr,
    input       [15:0] map_data,
    // Gfx ROM
    output reg  [16:0] scr_addr,
    input       [15:0] scrom_data,
    output      [ 5:0] scr_pxl
);

parameter HOFFSET=9'd5;
parameter SIMFILE_MSB="", SIMFILE_LSB="";
parameter AS8MASK = 1'b1;

wire [8:0] Hfix = H + HOFFSET; // Corrects pixel output offset
reg  [ 8:0] HS;
reg  [ 7:0] VF, SV, SH, PIC;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0]; // SCHF2_1-8
reg  [15:0] hpos; // called "SP" on the schematics

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;


`ifdef TESTSCR1
//reg [15:0] hpos_test;
always @(posedge LVBL or posedge rst)
    if( rst )
        hpos <= 'd768;
    else
        hpos <= hpos + 16'd8;
`endif

wire [9:0] SCHF = { HF[6]&~Hfix[8], ~Hfix[8], H7, HF[6:0] }; // SCHF30~21

always @(posedge clk) if(cen6) begin
    VF <= {8{flip}}^V128;
    SV <= VF + ( pause ? 8'd0 : vpos );
    {PIC, SH } <= hpos + { {7{SCHF[9]}},SCHF[8:0] };
    map_addr <= { PIC, SH[7:5], SV[7:5] };
    HS[8:3] <= SCHF[8:3];
    HS[2:0] <= SCHF[2:0] ^ {3{flip}};
end


/* H1  = C18
   H8  = D19
   H16 = C20 
   H32 = D20
   H64 = C21
   H128= D21
   H256= C22

*/

always @(posedge clk) 
    if( rst ) begin
        hpos <= 'd0;
    end else if(cen6) begin // same cen as main CPU
        if( scrposh_cs[1] && !wr_n ) hpos[15:8] <= din;
        if( scrposh_cs[0] && !wr_n ) hpos[ 7:0] <= din;
    end

wire [7:0] dout_high = map_data[ 7:0];
wire [7:0] dout_low  = map_data[15:8];

reg scr_hflip;
reg [7:0] addr_lsb;

reg [4:0] scr_attr0, scr_attr1;

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    if( HS[2:0]==3'd1 ) begin // dout_high/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        scr_attr1 <= scr_attr0;
        scr_attr0 <= dout_high[6:2];
        scr_addr[16:1] <= {   dout_high[0] & AS8MASK, dout_low, // AS
                        HS[4:3]^{2{dout_high[6]}} /*scr_hflip*/, 
                        {5{dout_high[7] /*vflip*/}}^VF[4:0] }; /*vert_addr*/
    end
    scr_addr[0] <= ~HS[2]^dout_high[6];
end

// Draw pixel on screen
reg [3:0] w,x,y,z;
reg [3:0] scr_attr2, scr_col0, scr_pal0;

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( HS[1:0]==2'd2 ) begin
            { z,y,x,w } <= scrom_data;     
            scr_hflip   <= scr_attr1[4] ^ flip; // must be ready when z,y,x are.
            scr_attr2   <= scr_attr1[3:0];
        end
    else
        begin
            if( scr_hflip ) begin
                w <= {1'b0, w[3:1]};
                x <= {1'b0, x[3:1]};
                y <= {1'b0, y[3:1]};
                z <= {1'b0, z[3:1]};
            end
            else  begin
                w <= {w[2:0], 1'b0};
                x <= {x[2:0], 1'b0};
                y <= {y[2:0], 1'b0};
                z <= {z[2:0], 1'b0};
            end
        end
    scr_col0  <= scr_hflip ? { w[0], x[0], y[0], z[0] } : { w[3], x[3], y[3], z[3] };
    scr_pal0  <= scr_attr2;
end

wire [7:0] pal_addr = SCxON ? { scr_pal0, scr_col0 } : 8'hFF;

// Palette
jtgng_prom #(.aw(8),.dw(2),.simfile(SIMFILE_MSB)) u_prom_msb(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din[1:0]  ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_msb_we    ),
    .q      ( scr_pxl[5:4]   )
);

jtgng_prom #(.aw(8),.dw(4),.simfile(SIMFILE_LSB)) u_prom_lsb(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_lsb_we    ),
    .q      ( scr_pxl[3:0]   )
);

endmodule // jtgng_scroll