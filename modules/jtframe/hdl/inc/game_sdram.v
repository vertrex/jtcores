// jt{{.Core}}_game_sdram.v is automatically generated by JTFRAME
// Do not modify it
// Do not add it to git

`ifndef JTFRAME_COLORW
`define JTFRAME_COLORW 4
`endif

`ifndef JTFRAME_BUTTONS
`define JTFRAME_BUTTONS 2
`endif

module jt{{.Core}}_game_sdram(
    `include "jtframe_common_ports.inc"
    `include "jtframe_mem_ports.inc"
);

/* verilator lint_off WIDTH */
localparam [25:0] BA1_START  =`ifdef JTFRAME_BA1_START  `JTFRAME_BA1_START  `else 26'd0 `endif;
localparam [25:0] BA2_START  =`ifdef JTFRAME_BA2_START  `JTFRAME_BA2_START  `else 26'd0 `endif;
localparam [25:0] BA3_START  =`ifdef JTFRAME_BA3_START  `JTFRAME_BA3_START  `else 26'd0 `endif;
localparam [25:0] PROM_START =`ifdef JTFRAME_PROM_START `JTFRAME_PROM_START `else 26'd0 `endif;
localparam [25:0] HEADER_LEN =`ifdef JTFRAME_HEADER     `JTFRAME_HEADER     `else 26'd0 `endif;
/* verilator lint_on WIDTH */

{{ range .Params }}
parameter {{.Name}} = {{ if .Value }}{{.Value}}{{else}}`{{.Name}}{{ end}};
{{- end}}

{{- if .Ioctl.Dump }}
/* verilator tracing_off */
wire [7:0] ioctl_aux;
{{- range $k, $v := .Ioctl.Buses }}{{ if $v.Name}}
wire [{{$v.DW}}-1:0] {{$v.Name}}_dimx;
wire [  1:0] {{$v.Name}}_wemx;{{if $v.Amx}}
wire [{{$v.AW}}-1:{{$v.AWl}}] {{$v.Amx}};{{ end }}{{end -}}
{{end}}{{end}}

`ifndef JTFRAME_IOCTL_RD
wire ioctl_ram = 0;
`endif
// Audio channels {{ range .Audio.Channels }}{{ if .Name }}
{{ if .Stereo }}wire {{ if not .Unsigned }}signed {{end}}{{ data_range . }} {{.Name}}_l, {{.Name}}_r;{{ else -}}
wire {{ if not .Unsigned }}signed {{end}}{{ data_range . }} {{.Name}};{{ end }}{{end}}{{if .Rc_en}}
wire {{if gt .Filters 1}}[{{sub .Filters 1}}:0] {{end}}{{.Name}}_rcen;{{end}}{{- end}}
wire mute;
// Additional ports
{{range .Ports}}wire {{if .MSB}}[{{.MSB}}:{{.LSB}}]{{end}} {{.Name}};
{{end}}
// BRAM buses
{{- range $cnt, $bus:=.BRAM }}
{{ if .Dual_port.Name }}
{{ if not .Dual_port.We }}wire    {{ if eq .Data_width 16 }}[ 1:0]{{else}}      {{end}}{{.Dual_port.Name}}_we; // Dual port for {{.Dual_port.Name}}
{{end}}{{end}}
{{- end}}
// SDRAM buses
{{ range .SDRAM.Banks}}
{{- range .Buses}}
wire {{ addr_range . }} {{.Name}}_addr;
wire {{ data_range . }} {{.Name}}_data;
wire        {{.Name}}_cs, {{.Name}}_ok;
{{- if .Rw }}
wire        {{.Name}}_we;
wire {{ data_range . }} {{.Name}}_din;
wire [ 1:0] {{.Name}}_dsn;
{{end}}{{end}}
{{- end}}
wire        prom_we, header;
wire [21:0] raw_addr, post_addr;
wire [25:0] pre_addr, dwnld_addr, ioctl_addr_noheader;
wire [ 7:0] post_data;
wire [15:0] raw_data;
wire        pass_io;
{{ if .Clocks }}// Clock enable signals{{ end }}
{{- range $k, $v := .Clocks }}
    {{- range $v }}
    {{- range .Outputs }}
wire {{ . }}; {{ end }}{{ end }}{{ end }}
wire gfx8_en, gfx16_en, ioctl_dwn;

assign pass_io = header | ioctl_ram;
assign ioctl_addr_noheader = `ifdef JTFRAME_HEADER header ? ioctl_addr : ioctl_addr - HEADER_LEN `else ioctl_addr `endif ;

wire rst_h, rst24_h, rst48_h, hold_rst;
`ifdef JTFRAME_CLK96
wire clk48=clk;
`endif
/* verilator tracing_off */
jtframe_rsthold u_hold(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .hold   ( hold_rst  ),
    .rst_h  ( rst_h     )
`ifdef JTFRAME_CLK24 ,
    .rst24  ( rst24     ),
    .clk24  ( clk24     ),
    .rst24_h( rst24_h   )
`endif
`ifdef JTFRAME_CLK48 ,
    .rst48  ( rst48     ),
    .clk48  ( clk48     ),
    .rst48_h( rst48_h   )
`endif
);
/* verilator tracing_on */
jt{{if .Game}}{{.Game}}{{else}}{{.Core}}{{end}}_game u_game(
    .rst        ( rst_h     ),
    .clk        ( clk       ),
`ifdef JTFRAME_CLK24
    .rst24      ( rst24_h   ),
    .clk24      ( clk24     ),
`endif
`ifdef JTFRAME_CLK48
    .rst48      ( rst48_h   ),
    .clk48      ( clk48     ),
`endif
`ifdef JTFRAME_CLK96
    .rst96      ( rst96     ),
    .clk96      ( clk96     ),
`endif
    // Audio channels
    {{if .Audio.Mute}}.mute( mute ),
    {{end}}{{ range .Audio.Channels -}}
    {{ if .Name }}{{ if .Stereo }}.{{.Name}}_l   ( {{.Name}}_l    ),
    .{{.Name}}_r   ( {{.Name}}_r    ),{{ else -}}
    .{{.Name}}     ( {{.Name}}      ),{{ end }}{{ end }}{{if .Rc_en}}
    .{{.Name}}_rcen( {{.Name}}_rcen ),
{{end}}{{ end}}
    {{ if eq (len .Audio.Channels) 0 }}
    // Sound output
`ifdef JTFRAME_STEREO
    .snd_left       ( snd_left      ),
    .snd_right      ( snd_right     ),
`else
    .snd            ( snd           ),
`endif
    .game_led       ( game_led      ),
    .sample         ( sample        ), {{ end }}
    .snd_en         ( snd_en        ),
    .snd_vol        ( snd_vol       ),
{{- range $k,$v := .Clocks }} {{- range $v}}
    {{- range .Outputs }}
    .{{ . }}    ( {{ . }}    ), {{end}}{{end}}
{{ end }}
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    // cabinet I/O
    .cab_1p   ( cab_1p  ),
    .coin     ( coin    ),
    .joystick1    ( joystick1        ), .joystick2    ( joystick2        ), `ifdef JTFRAME_4PLAYERS
    .joystick3    ( joystick3        ), .joystick4    ( joystick4        ), `endif `ifdef JTFRAME_MOUSE
    .mouse_1p     ( mouse_1p         ), .mouse_2p     ( mouse_2p         ), `endif `ifdef JTFRAME_SPINNER
    .spinner_1p   ( spinner_1p       ), .spinner_2p   ( spinner_2p       ), `endif `ifdef JTFRAME_ANALOG
    .joyana_l1    ( joyana_l1        ), .joyana_l2    ( joyana_l2        ), `ifdef JTFRAME_ANALOG_DUAL
    .joyana_r1    ( joyana_r1        ), .joyana_r2    ( joyana_r2        ), `endif `ifdef JTFRAME_4PLAYERS
    .joyana_l3    ( joyana_l3        ), .joyana_l4    ( joyana_l4        ), `ifdef JTFRAME_ANALOG_DUAL
    .joyana_r3    ( joyana_r3        ), .joyana_r4    ( joyana_r4        ), `endif `endif `endif `ifdef JTFRAME_DIAL
    .dial_x       ( dial_x           ), .dial_y       ( dial_y           ), `endif
    // DIP switches
    .status         ( status        ),
    .dipsw          ( dipsw         ),
    .service        ( service       ),
    .tilt           ( tilt          ),
    .dip_pause      ( dip_pause     ),
    .dip_flip       ( dip_flip      ),
    .dip_test       ( dip_test      ),
    .dip_fxlevel    ( dip_fxlevel   ),
    .enable_psg     ( enable_psg    ),
    .enable_fm      ( enable_fm     ),
    // Ports declared in mem.yaml
    {{- range .Ports}}
    .{{.Name}}   ( {{.Name}} ),
    {{- end}}
    // Memory interface - SDRAM
    {{- range .SDRAM.Banks}}
    {{- range .Buses}}{{if not .Addr}}
    .{{.Name}}_addr ( {{.Name}}_addr ),{{end}}{{ if not .Cs}}
    .{{.Name}}_cs   ( {{.Name}}_cs   ),{{end}}
    .{{.Name}}_ok   ( {{.Name}}_ok   ),
    .{{.Name}}_data ( {{.Name}}_data ),
    {{- if .Rw }}
    .{{.Name}}_we   ( {{.Name}}_we   ),
    {{if not .Dsn}}.{{.Name}}_dsn  ( {{.Name}}_dsn  ),{{end}}
    {{if not .Din}}.{{.Name}}_din  ( {{.Name}}_din  ),{{end}}
    {{- end}}
    {{end}}
    {{- end}}
    // Memory interface - BRAM
{{ range $cnt, $bus:=.BRAM -}}
    {{if not .Addr}}.{{.Name}}_addr ( {{.Name}}_addr ),{{end}}{{ if .Rw }}
    {{if not .Din}}.{{.Name}}_din  ( {{.Name}}_din  ),{{end}}{{end}}{{ if .Dual_port.Name }}
    {{ if not .Dual_port.We }}.{{.Dual_port.Name}}_we ( {{.Dual_port.Name}}_we ),  // Dual port for {{.Dual_port.Name}}{{end}}
    {{ else }}{{ if not $bus.ROM.Offset }}{{end}}
    {{- end}}
{{- end}}
    // PROM writting
    .ioctl_addr   ( pass_io ? ioctl_addr       : ioctl_addr_noheader  ),
    .prog_addr    ( pass_io ? ioctl_addr[21:0] : raw_addr      ),
    .prog_data    ( pass_io ? ioctl_dout       : raw_data[7:0] ),
    .prog_we      ( pass_io ? ioctl_wr         : prog_we       ),
    .prog_ba      ( prog_ba        ), // prog_ba supplied in case it helps re-mapping addresses
`ifdef JTFRAME_PROM_START
    .prom_we      ( prom_we        ),
`endif
    {{- with .Download.Pre_addr }}
    // SDRAM address mapper during downloading
    .pre_addr     ( pre_addr       ),
    {{- end }}
    {{- with .Download.Post_addr }}
    // SDRAM address mapper during downloading
    .post_addr    ( post_addr      ),
    {{- end }}
    {{- with .Download.Post_data }}
    .post_data    ( post_data      ),
    {{- end }}
`ifdef JTFRAME_HEADER
    .header       ( header         ),
`endif
`ifdef JTFRAME_IOCTL_RD
    .ioctl_ram    ( ioctl_ram      ),
    .ioctl_din    ( {{.Ioctl.DinName}}      ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ), `endif
    .ioctl_cart   ( ioctl_cart     ),
    // Debug
    .debug_bus    ( debug_bus      ),
    .debug_view   ( debug_view     ),
`ifdef JTFRAME_STATUS
    .st_addr      ( st_addr        ),
    .st_dout      ( st_dout        ),
`endif
`ifdef JTFRAME_LF_BUFFER
    .game_vrender( game_vrender  ),
    .game_hdump  ( game_hdump    ),
    .ln_addr     ( ln_addr       ),
    .ln_data     ( ln_data       ),
    .ln_done     ( ln_done       ),
    .ln_hs       ( ln_hs         ),
    .ln_pxl      ( ln_pxl        ),
    .ln_v        ( ln_v          ),
    .ln_we       ( ln_we         ),
`endif
    .gfx_en      ( gfx_en        )
);
/* verilator tracing_off */
assign dwnld_busy = ioctl_rom | prom_we; // prom_we is really just for sims
assign dwnld_addr = {{if .Download.Pre_addr }}pre_addr{{else}}ioctl_addr{{end}};
assign prog_addr = {{if .Download.Post_addr }}post_addr{{else}}raw_addr{{end}};
assign prog_data = {{if .Download.Post_data }}{2{post_data}}{{else}}raw_data{{end}};
assign gfx8_en   = {{ .Gfx8 }}
assign gfx16_en  = {{ .Gfx16 }}
assign ioctl_dwn = ioctl_rom | ioctl_cart;
`ifdef VERILATOR_KEEP_SDRAM /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
jtframe_dwnld #(
`ifdef JTFRAME_HEADER
    .HEADER    ( `JTFRAME_HEADER   ),
`endif{{ if .Balut }}
    .BALUT      ( {{.Balut}}    ),  // Using offsets in header for
    .LUTSH      ( {{.Lutsh}}    ),  // bank assignment
    .LUTDW      ( {{.Lutdw}}    ),
{{else}}
`ifdef JTFRAME_BA1_START
    .BA1_START ( BA1_START ),
`endif
`ifdef JTFRAME_BA2_START
    .BA2_START ( BA2_START ),
`endif
`ifdef JTFRAME_BA3_START
    .BA3_START ( BA3_START ),
`endif{{end}}
`ifdef JTFRAME_PROM_START
    .PROM_START( PROM_START ),
`endif
    .SWAB      ( {{if .Download.Noswab }}0{{else}}1{{end}}),
    .GFX8B0    ( {{ .Gfx8b0 }}),
    .GFX16B0   ( {{ .Gfx16b0 }})
) u_dwnld(
    .clk          ( clk            ),
    .ioctl_rom    ( ioctl_dwn      ),
    .ioctl_addr   ( dwnld_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .gfx8_en      ( gfx8_en        ),
    .gfx16_en     ( gfx16_en       ),
    .prog_addr    ( raw_addr       ),
    .prog_data    ( raw_data       ),
    .prog_mask    ( prog_mask      ), // active low
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       ( header         ),
    .sdram_ack    ( prog_ack       )
);
`ifdef VERILATOR_KEEP_SDRAM /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
{{ $holded := false }}
{{ $holded_slot := false }}
{{ range $bank, $each:=.SDRAM.Banks }}
{{- if gt (len .Buses) 0 }}
jtframe_{{.MemType}}_{{len .Buses}}slot{{with lt 1 (len .Buses)}}s{{end}} #(
{{- $first := true}}
{{- range $index, $each:=.Buses}}
    {{- if $first}}{{$first = false}}{{else}}, {{end}}
    // {{.Name}}
    {{- if not .Rw }}
    {{- with .Offset }}
    .SLOT{{$index}}_OFFSET({{.}}[21:0]),{{end}}{{end}}
    {{- with .Cache_size }}
    .CACHE{{$index}}_SIZE({{.}}),{{end}}
    .SLOT{{$index}}_AW({{ slot_addr_width . }}),
    .SLOT{{$index}}_DW({{ printf "%2d" .Data_width}})
{{- end}}
`ifdef JTFRAME_BA2_LEN
{{- range $index, $each:=.Buses}}
    {{- if not .Rw}}
    ,.SLOT{{$index}}_DOUBLE(1){{ end }}
{{- end}}
`endif
{{- $is_rom := eq .MemType "rom" }}
) u_bank{{$bank}}(
    .rst         ( rst        ),
    .clk         ( clk        ),
    {{ range $index2, $each:=.Buses }}{{if .Addr}}
    .slot{{$index2}}_addr  ( {{.Addr}} ),{{else}}
    {{- if eq .Data_width 32 }}
    .slot{{$index2}}_addr  ( { {{.Name}}_addr, 1'b0 } ),
    {{- else }}
    .slot{{$index2}}_addr  ( {{.Name}}_addr  ),
    {{- end }}{{end}}
    {{- if .Rw }}{{ if not $holded_slot }}
    .hold_rst    ( hold_rst        ), {{ $holded_slot = true }}{{ $holded = true }}{{end}}
    .slot{{$index2}}_wen   ( {{.Name}}_we    ),
    .slot{{$index2}}_din   ( {{if .Din}}{{.Din}}{{else}}{{.Name}}_din{{end}}   ),
    .slot{{$index2}}_wrmask( {{if .Dsn}}{{.Dsn}}{{else}}{{.Name}}_dsn{{end}}   ),
    .slot{{$index2}}_offset( {{if .Offset }}{{.Offset}}[21:0]{{else}}22'd0{{end}} ),
    {{- else }}
    {{- if not $is_rom }}
    .slot{{$index2}}_clr   ( 1'b0       ), // only 1'b0 supported in mem.yaml
    {{- end }}{{- end}}
    .slot{{$index2}}_dout  ( {{.Name}}_data  ),
    .slot{{$index2}}_cs    ( {{ if .Cs }}{{.Cs}}{{else}}{{.Name}}_cs{{end}}    ),
    .slot{{$index2}}_ok    ( {{.Name}}_ok    ),
    {{end}}
    // SDRAM controller interface
    .sdram_ack   ( ba_ack[{{$bank}}]  ),
    .sdram_rd    ( ba_rd[{{$bank}}]   ),
    .sdram_addr  ( ba{{$bank}}_addr   ),
{{- if not $is_rom }}
    .sdram_wr    ( ba_wr[{{$bank}}]   ),
    .sdram_wrmask( ba{{$bank}}_dsn    ),
    .data_write  ( ba{{$bank}}_din    ),{{end}}
    .data_dst    ( ba_dst[{{$bank}}]  ),
    .data_rdy    ( ba_rdy[{{$bank}}]  ),
    .data_read   ( data_read  )
);
{{- if $is_rom }}
assign ba_wr[{{$bank}}] = 0;
assign ba{{$bank}}_din  = 0;
assign ba{{$bank}}_dsn  = 3;
{{- end}}{{- end }}{{end}}
{{ if not $holded }}assign hold_rst=0;{{end}}
{{ range $index, $each:=.Unused }}
{{- with . -}}
assign ba{{$index}}_addr = 0;
assign ba_rd[{{$index}}] = 0;
assign ba_wr[{{$index}}] = 0;
assign ba{{$index}}_dsn  = 3;
assign ba{{$index}}_din  = 0;
{{ end -}}
{{ end -}}

{{ range $cnt, $bus:=.BRAM -}}
{{- if $bus.Dual_port.Name }}
// Dual port BRAM for {{$bus.Name}} and {{$bus.Dual_port.Name}}
jtframe_dual_ram{{ if eq $bus.Data_width 16 }}16{{end}} #(
    .AW({{$bus.Addr_width}}{{if eq $bus.Data_width 16}}-1{{end}}){{ if $bus.Sim_file }},
    {{ if eq $bus.Data_width 16 }}.SIMFILE_LO("{{$bus.Name}}_lo.bin"),
    .SIMFILE_HI("{{$bus.Name}}_hi.bin"){{else}}.SIMFILE("{{$bus.Name}}.bin"){{end}}{{end}}
) u_bram_{{$bus.Name}}(
    // Port 0 - {{$bus.Name}}
    .clk0   ( clk ),
    .addr0  ( {{$bus.Addr}} ),{{ if $bus.Rw }}
    .data0  ( {{$bus.Name}}_din  ),
    .we0    ( {{ if $bus.We }} {{$bus.We}}{{else}}{{$bus.Name}}_we{{end}} ), {{ else }}
    .data0  ( {{$bus.Data_width}}'h0 ),
    .we0    ( {{ if eq $bus.Data_width 16 }}2'd0{{else}}1'd0{{end}} ),{{end}}
    .q0     ( {{$bus.Name}}_dout ),
    // Port 1 - {{$bus.Dual_port.Name}}
    .clk1   ( clk ),
    .data1  ( {{if $bus.Dual_port.Din}}{{$bus.Dual_port.Din}}{{else}}{{$bus.Dual_port.Name}}_dout{{end}} ),
    .addr1  ( {{$bus.Dual_port.AddrFull}} ),{{ if $bus.Dual_port.Rw }}
    .we1    ( {{if $bus.Dual_port.We}}{{$bus.Dual_port.We}}{{else}}{{$bus.Dual_port.Name}}_we{{end}}  ), {{ else }}
    .we1    ( 2'd0 ),{{end}}
    .q1     ( {{if $bus.Dual_port.Dout}}{{$bus.Dual_port.Dout}}{{else}}{{$bus.Name}}2{{$bus.Dual_port.Name}}_data{{end}} )
);{{else}}{{if $bus.ROM.Offset }}
/* verilator tracing_off */

jtframe_bram_rom #(
    .AW({{$bus.Addr_width}}{{if is_nbits $bus 16 }}-1{{end}}),.DW({{$bus.Data_width}}),
    .OFFSET({{$bus.ROM.Offset}}),{{ if eq $bus.Data_width 16 }}
    .SIMFILE_LO("{{$bus.Name}}_lo.bin"),
    .SIMFILE_HI("{{$bus.Name}}_hi.bin"){{else}}.SIMFILE("{{$bus.Name}}.bin"){{end}}
) u_brom_{{$bus.Name}}(
    .clk    ( clk       ),
    // Read port
    .addr   ( {{if $bus.Addr}}{{$bus.Addr}}{{else}}{{$bus.Name}}_addr{{end}} ),
    .data   ( {{ data_name $bus }} ),
    // Write port
    .prog_addr( {prog_ba,prog_addr} ),
    .prog_mask( prog_mask ),
    .prog_data( prog_data[7:0] ),
    .prog_we  ( prog_we   )
);
/* verilator tracing_off */

{{else}}
// BRAM for {{$bus.Name}}
jtframe_ram{{ if eq $bus.Data_width 16 }}16{{end}} #(
    .AW({{$bus.Addr_width}}{{if eq $bus.Data_width 16}}-1{{end}}){{ if $bus.Sim_file }},
    {{ if eq $bus.Data_width 16 }}.SIMFILE_LO("{{$bus.Name}}_lo.bin"),
    .SIMFILE_HI("{{$bus.Name}}_hi.bin"){{else}}.SIMFILE("{{$bus.Name}}.bin"){{end}}{{end}}
) u_bram_{{$bus.Name}}(
    .clk    ( clk  ),{{ if eq $bus.Data_width 8 }}
    .cen    ( 1'b1 ),{{end}}
    .addr   ( {{$bus.Addr}} ),
    .data   ( {{$bus.Din }} ),
    .we     ( {{$bus.We  }} ),
    .q      ( {{$bus.Name}}_dout )
);{{ end }}
{{ end }}{{end}}

{{- if .Ioctl.Dump }}
/* verilator tracing_off */

jtframe_ioctl_dump #(
    {{- $first := true}}
    {{- range $k, $v := .Ioctl.Buses }}
    {{- if $first}}{{$first = false}}{{else}},{{end}}
    .DW{{$k}}( {{$v.DW}} ), .AW{{$k}}( {{$v.AW}} ){{end}}
) u_dump (
    .clk       ( clk        ),
    {{- range $k, $v := .Ioctl.Buses }}
    // dump {{$k}}
    .dout{{$k}}        ( {{$v.Dout}} ),
    .addr{{$k}}        ( {{$v.A}} ),
    .addr{{$k}}_mx     ( {{$v.Amx}} ),
    // restore
    .din{{$k}}         ( {{$v.Din}} ),
    .din{{$k}}_mx      ( {{with $v.Name}}{{.}}_dimx{{end}} ),
    .we{{$k}}          ( {{if eq $v.DW 8 }}{ 1'b0,{{ $v.We }} }{{else}}{{$v.We}}{{end}}),
    .we{{$k}}_mx       ( {{with $v.Name}}{{.}}_wemx{{end}} ),
    {{end }}
    .ioctl_addr ( ioctl_addr[23:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_aux  ( ioctl_aux ),
    .ioctl_wr   ( ioctl_wr  ),
    .ioctl_din  ( ioctl_din ),
    .ioctl_dout ( ioctl_dout)
);
{{ end }}

{{ if .Clocks }}
// Clock enable generation
{{- range $k, $v := .Clocks }} {{- range $cnt, $val := $v}}
// {{ .Comment }} Hz from {{ .ClkName }}
`ifdef VERILATOR_KEEP_CEN /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
jtframe_gated_cen #(.W({{.W}}),.NUM({{.Mul}}),.DEN({{.Div}}),.MFREQ({{.KHz}})) u_cen{{$cnt}}_{{.ClkName}}(
    .rst    ( rst          ),
    .clk    ( {{.ClkName}} ),
    .busy   ( {{.Busy}}    ),
    .cen    ( { {{ .OutStr }} } ),
    .fave   (              ),
    .fworst (              )
); /* verilator tracing_on */
{{ end }}{{ end }}{{ end }}
{{ if .Audio.Channels }}`ifndef NOSOUND
{{- $ch0 := (index .Audio.Channels 0) -}}
{{- $ch1 := (index .Audio.Channels 1) -}}
{{- $ch2 := (index .Audio.Channels 2) -}}
{{- $ch3 := (index .Audio.Channels 3) -}}
{{- $ch4 := (index .Audio.Channels 4) -}}
{{- $ch5 := (index .Audio.Channels 5) }}{{ if not .Audio.Mute }}
assign mute=0;{{end}}
jtframe_rcmix #(
    {{ if $ch0.Name }}.W0({{$ch0.Data_width}}),{{end}}{{ if $ch1.Name }}
    .W1({{$ch1.Data_width}}),{{end}}{{ if $ch2.Name }}
    .W2({{$ch2.Data_width}}),{{end}}{{ if $ch3.Name }}
    .W3({{$ch3.Data_width}}),{{end}}{{ if $ch4.Name }}
    .W4({{$ch4.Data_width}}),{{end}}{{ if $ch5.Name }}
    .W5({{$ch5.Data_width}}),{{end}}{{ with $ch0.Firhex}}
    .FIR0("{{$ch0.Firhex}}"),{{end}}{{ with $ch1.Firhex}}
    .FIR1("{{$ch1.Firhex}}"),{{end}}{{ with $ch2.Firhex}}
    .FIR2("{{$ch2.Firhex}}"),{{end}}{{ with $ch3.Firhex}}
    .FIR3("{{$ch3.Firhex}}"),{{end}}{{ with $ch4.Firhex}}
    .FIR4("{{$ch4.Firhex}}"),{{end}}{{ with $ch5.Firhex}}
    .FIR5("{{$ch5.Firhex}}"),{{end}}
    .STEREO0( {{if $ch0.Stereo }}1{{else}}0{{end}}),
    .STEREO1( {{if $ch1.Stereo }}1{{else}}0{{end}}),
    .STEREO2( {{if $ch2.Stereo }}1{{else}}0{{end}}),
    .STEREO3( {{if $ch3.Stereo }}1{{else}}0{{end}}),
    .STEREO4( {{if $ch4.Stereo }}1{{else}}0{{end}}),
    .STEREO5( {{if $ch5.Stereo }}1{{else}}0{{end}}),
    .DCRM0  ( {{if $ch0.DCrm   }}1{{else}}0{{end}}),
    .DCRM1  ( {{if $ch1.DCrm   }}1{{else}}0{{end}}),
    .DCRM2  ( {{if $ch2.DCrm   }}1{{else}}0{{end}}),
    .DCRM3  ( {{if $ch3.DCrm   }}1{{else}}0{{end}}),
    .DCRM4  ( {{if $ch4.DCrm   }}1{{else}}0{{end}}),
    .DCRM5  ( {{if $ch5.DCrm   }}1{{else}}0{{end}}),
    .STEREO ( {{if .Stereo}}     1{{else}}0{{end}}),
    // Fractional cen for 192kHz
    .FRACW( {{ .Audio.FracW }}), .FRACN({{.Audio.FracN}}), .FRACM({{.Audio.FracM}})
) u_rcmix(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .mute   ( mute      ),
    .sample ( sample    ),
    .ch_en  ( snd_en    ),
    .gpole  ( {{ .Audio.GlobalPole }} ), {{ if ne .Audio.GlobalFcut 0 }} // {{ .Audio.GlobalFcut }} Hz {{ end }}
    .ch0    ( {{ if $ch0.Name }}{{ if $ch0.Stereo }}{ {{$ch0.Name}}_l,{{$ch0.Name}}_r }{{ else }}{{ $ch0.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch1    ( {{ if $ch1.Name }}{{ if $ch1.Stereo }}{ {{$ch1.Name}}_l,{{$ch1.Name}}_r }{{ else }}{{ $ch1.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch2    ( {{ if $ch2.Name }}{{ if $ch2.Stereo }}{ {{$ch2.Name}}_l,{{$ch2.Name}}_r }{{ else }}{{ $ch2.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch3    ( {{ if $ch3.Name }}{{ if $ch3.Stereo }}{ {{$ch3.Name}}_l,{{$ch3.Name}}_r }{{ else }}{{ $ch3.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch4    ( {{ if $ch4.Name }}{{ if $ch4.Stereo }}{ {{$ch4.Name}}_l,{{$ch4.Name}}_r }{{ else }}{{ $ch4.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch5    ( {{ if $ch5.Name }}{{ if $ch5.Stereo }}{ {{$ch5.Name}}_l,{{$ch5.Name}}_r }{{ else }}{{ $ch5.Name }}{{end}}{{else}}16'd0{{end}} ),
    .p0     ( {{ if $ch0.Pole }}{{$ch0.Pole}}{{else}}16'h0{{end}}), {{if $ch0.Name }}// {{ index $ch0.Fcut 0}} Hz, {{ index $ch0.Fcut 1 }} Hz {{end}}
    .p1     ( {{ if $ch1.Pole }}{{$ch1.Pole}}{{else}}16'h0{{end}}), {{if $ch1.Name }}// {{ index $ch1.Fcut 0}} Hz, {{ index $ch1.Fcut 1 }} Hz {{end}}
    .p2     ( {{ if $ch2.Pole }}{{$ch2.Pole}}{{else}}16'h0{{end}}), {{if $ch2.Name }}// {{ index $ch2.Fcut 0}} Hz, {{ index $ch2.Fcut 1 }} Hz {{end}}
    .p3     ( {{ if $ch3.Pole }}{{$ch3.Pole}}{{else}}16'h0{{end}}), {{if $ch3.Name }}// {{ index $ch3.Fcut 0}} Hz, {{ index $ch3.Fcut 1 }} Hz {{end}}
    .p4     ( {{ if $ch4.Pole }}{{$ch4.Pole}}{{else}}16'h0{{end}}), {{if $ch4.Name }}// {{ index $ch4.Fcut 0}} Hz, {{ index $ch4.Fcut 1 }} Hz {{end}}
    .p5     ( {{ if $ch5.Pole }}{{$ch5.Pole}}{{else}}16'h0{{end}}), {{if $ch5.Name }}// {{ index $ch5.Fcut 0}} Hz, {{ index $ch5.Fcut 1 }} Hz {{end}}
    .g0     ( {{ $ch0.Gain }} ), {{with $ch0.Name}}// {{.}}{{end}}
    .g1     ( {{ $ch1.Gain }} ), {{with $ch1.Name}}// {{.}}{{end}}
    .g2     ( {{ $ch2.Gain }} ), {{with $ch2.Name}}// {{.}}{{end}}
    .g3     ( {{ $ch3.Gain }} ), {{with $ch3.Name}}// {{.}}{{end}}
    .g4     ( {{ $ch4.Gain }} ), {{with $ch4.Name}}// {{.}}{{end}}
    .g5     ( {{ $ch5.Gain }} ), {{with $ch5.Name}}// {{.}}{{end}}
    .gain   ( snd_vol         ),
    .mixed({{ if .Stereo }}{ snd_left, snd_right}{{else}}snd{{end}}),
    .peak ( game_led ),
    .vu   ( snd_vu   )
);
`else
assign {{ if .Stereo }}{ snd_left, snd_right}{{else}}snd{{end}}=0;
assign snd_vu   = 0;
assign game_led = 0;
wire ncs;
jtframe_frac_cen #(.WC({{ .Audio.FracW }})) u_cen192(
    .clk    ( clk       ),
    .n      ( {{.Audio.FracN}} ),
    .m      ( {{.Audio.FracM}} ),
    .cen    ( {  ncs,sample }  ), // sample is always 192 kHz
    .cenb   (                  )
);
`endif{{ else }}
assign snd_vu = 0;
{{ end }}
endmodule
