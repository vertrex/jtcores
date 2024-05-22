/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-8-2021 */

// Applies horizontal scaling to an analogue signal

module jtframe_hsize #( parameter
    COLORW     =4     // bits per colour
    //VIDEO_WIDTH=256   // screen pixel width (excluding blanking)
) (
    input              clk,
    input              pxl_cen,
    input              pxl2_cen,

    input        [3:0] scale,
    input        [4:0] offset,
    input              enable,

    input [COLORW-1:0] r_in,
    input [COLORW-1:0] g_in,
    input [COLORW-1:0] b_in,
    input              HS_in,
    input              VS_in,
    input              HB_in,
    input              VB_in,
    // filtered video
    output reg            HS_out,
    output reg            VS_out,
    output reg            HB_out,
    output reg            VB_out,
    output reg [COLORW-1:0] r_out,
    output reg [COLORW-1:0] g_out,
    output reg [COLORW-1:0] b_out
);

//localparam VW = VIDEO_WIDTH <= 256 ? 9 : (VIDEO_WIDTH <= 512 ? 9 : 10);
localparam VW = 9; // Max 512 pixels including blanking
localparam SW = 8;

wire [COLORW*3-1:0] rgb_out, rgb_in;
reg  [    VW-1:0] wrcnt, hwcnt,rd_z=0, rd_out, rgbcnt;
reg  [      VW:0] rdcnt_l=0, rdcnt=0, hrmax=0;
wire [ VW+SW-2:0] summand;
reg  [    SW-1:0] sum;
reg  [    VW-1:0] hb0, hb1;

reg  line=0;
reg  VSl, HSl, LHBl, LHBll, VBl, VBll, LHB_chnl,LHB_chn,repr;
reg  [SW-2:0] rdfrac=0,rgbfrac=0;

assign rgb_in   = {r_in, g_in, b_in};
assign summand  = {{VW{1'b0}},~scale[3],{SW-6{scale[3]}},scale};


always @(posedge clk) if(pxl_cen) begin
    HSl    <=  HS_in;
    LHBl   <= ~HB_in;
    LHBll  <=  LHBl;
    HB_out <=  HB_in;
    hwcnt  <= (hb0-hb1)>>1;
    rd_z   <= hwcnt+hb1;
    hrmax  <= rdcnt_l-{1'b0,hwcnt};
    HS_out <= HS_in;
    VB_out <= VB_in;
    VS_out <= VS_in;

    // VB must be adjusted to prevent the bottom line from being washed out
    if( ~HB_in & ~LHBl ) {VBll, VBl} <= {VBl, VB_in};

    if( HS_in & ~HSl ) begin
        line  <= ~line;
        wrcnt <= 0;
        VSl   <= VS_in;
        if( enable ) VS_out <= VSl;
    end else begin
        wrcnt <= wrcnt + 1'd1;
    end
    // Register when HB toggles
    if(  LHBl   & ~LHBll  ) hb1 <= wrcnt;
    if(  HB_in  &  LHBl   ) hb0 <= wrcnt;

    if( wrcnt==rd_z) LHB_chn <= 1;
    if( LHB_chn && rdcnt >= {1'b0,hwcnt} && wrcnt > rd_z ) LHB_chn <= 0;
    if(!LHB_chn && rdcnt >= hrmax) begin
        LHB_chn <= 1;
        if( enable ) VB_out <= VBll;            
    end
    // colour output
    {r_out,g_out,b_out} <= enable ? (~HB_out ? rgb_out : {3*COLORW{1'b0}}) : rgb_in;
end

always @(posedge clk) if(pxl2_cen) begin
    LHB_chnl       <= LHB_chn;
    {rdcnt,rdfrac} <= {rdcnt,rdfrac} + {1'b0,summand};
    if( LHB_chn && ~LHB_chnl) {rgbcnt,rgbfrac} <= {hb1,{SW-1{1'b0}}};
    else if( LHB_chn)         {rgbcnt,rgbfrac} <= {rgbcnt,rgbfrac} + summand;
    else                       rgbcnt          <= 0;
    if( wrcnt==rd_z ) begin 
        {rdcnt,rdfrac}  <= { {VW-4{offset[4]}}, offset,{SW-1{1'b0}} };
        if( !repr) begin 
            rdcnt_l <= rdcnt;
            repr    <= 1;
        end 
    end else begin
        repr <= 0;
    end 
end

jtframe_rpwp_ram #(.DW(COLORW*3), .AW(VW+1)) u_line(
    .clk    ( clk       ),
    // Port 0: writes
    .din    ( rgb_in    ),
    .wr_addr({line, wrcnt}),
    .we     ( pxl_cen   ),
    // Port 1
    .rd_addr({line, rgbcnt}),
    .dout   ( rgb_out   )
);

endmodule