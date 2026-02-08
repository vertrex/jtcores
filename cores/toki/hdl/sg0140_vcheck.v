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
  //VORIGIN START ONE cycle BEFORE NV256 at 255 and just keep high for one cycle
  //it can be used to launch something nv256 is used to stay until end of line

  // ACTIVE HIGH when DMA is counting
  // it's the inverse of the DMA counter activation Q_148
  // which is high when DMA counter compute address
  // so we certainly need to get OBUSRQ LOW UNTIL OVER256 i high
  input             OVER256,// active low 15.61khz, high during DMA start, the dma counter is then active, and the sg0140 write with EVNWR2 / ODDWR2 the tile info to the memory

  input             OVER48, // Over sprite limit ? Active high
  input             VREVD_2,// OBJ_DB[9] active low (active during attract when there is the magician), generally active when there is sprite but not during cave stuff  is that  that the 8 bit if > 256 or in other screen like {VREV, VPD} % 16
  input             OBJEN_3,// it seem to only appear when there is a new object on the screen like toki, a fireball
  // or a new ennemy then it doesn't appear if it's already in memory ?
  input             H2,     //
  input             RDCLK,  // 6mhz
  input             VCLK,   // 15.61khz
  input             VREV,   //
  input             NV256,  // 59.61 high at half period when over256, active high when vpos > 256

  //output
  output reg  [3:0] VMT,    // output y pos - current line % 16 /address is 19:1
  output reg        EVNWR2, // use DMA2_EA of other sg0140 ?    @6mhz
  output reg        ODDWR2, // use DMA2_OA of other sg0140 in scndma  @6mhz
  output reg        OIBDIR,  //ACTIVE LOW, becore low avec OBUSRQ change to become high again
  output reg        OBUSRQ, // ACTIVE LOW, low one cycle before OIBDIR CHANGE
  output reg        VFIND   // If ODDWR2 or EVNWR2 is low vfind is low so it inform something was found ? when over256 is low vfind is always low too
);
    //assign VFIND = OVER256; //SURE THAT CONTROL NOOBJ
    //NOOBJ = MATCHV = VFIND
    //and matchv in PLD24V is
    // ~(OVER256 & ~VFIND) donc ca ne peux pas marcher comme ca !!! il faut
    // generer cidn parfoid pour dautre raison XXX XXX XXX


    // Internal line counter
    reg [8:0] current_y;
    reg old_vclk;
    reg old_nv256;

    always @(posedge clk) begin
        if (rst) begin
            current_y <= 0;
            old_vclk  <= 0;
            old_nv256 <= 0;
        end else begin
            old_vclk <= VCLK;
            old_nv256 <= NV256;

            // Reset au début de la frame (VORIGIN)
            if (~NV256 && old_nv256)
                current_y <= 0;
            // Incrément à chaque ligne (VCLK Rising Edge)
            else if (VCLK && !old_vclk)
                current_y <= current_y + 8'b1;
            end
        end

    // DMA bus request handling
    always @(posedge clk) begin
        if (rst) begin
            OBUSRQ <= 1'b1; // Active Low
            OIBDIR <= 1'b1; // Active Low
            end
        else begin
            // Demande le bus si ODMARQ arrive
            if (!ODMARQ)
              OBUSRQ <= 1'b0;

            // Si le CPU donne le bus (ACK), on prend la main
            if (!OBUSAK && !OBUSRQ) begin
                OIBDIR <= 1'b0; // Enable Drivers
                OBUSRQ <= 1'b1;
                end

            if (OVER256 == 1'b0) begin
                OIBDIR <= 1'b1;
                end
            end
       end

    // --- 3. VCHECK Logic (Comparaison Y) ---
    // Calcul de la ligne du sprite.
    // TODO: Vérifier si VREVD_2 est le bit 8 de la position ou un flip.
    // En général sur ces hardwares: {VREVD_2, VPD} forme la position 9 bits.
    //wire [8:0] sprite_pos_y = {VREVD_2, VPD};
    wire [8:0] sprite_pos_y = {1'b0, VPD};

    // Différence non-signée (attention au wrapping)
    wire [8:0] diff_y = current_y - sprite_pos_y;

    // Sprite Visible ? (Si on est entre la ligne Y et Y+15)
    // OVER256=0 signifie que le DMA est actif, on checke alors les sprites.
    // OBJEN_3 doit être actif (sprite non vide/activé).

    //OBJEN_2 == OBJEN_1 == OBJ_DB[15] == SPRITE WORDS[0][15] == sprite disable on mame (unused)
    //INSCRN == ND2[8] set if carry_m > 256 in hvpos by pld25.v
    //OBJEN_3 == ~INSCRN & ~OBJEN_2

    wire check_en = OVER256 & ~OBJEN_3;
   //if (visible && !OVER48) begin
    // Note: Si VREV (Flip Screen) est actif, la logique s'inverse (15 - diff)
    wire is_visible = (diff_y < 16);

    //XXX -> if during OIBIDIR it mean it's not during DMA 
    //so the inverse of what we did until now ! 
  //it can be durting DMA because dma is occuring during frame 260-262 so that no meaning 
  //if it's to detect collision ... 
    //VFIND must be active low because it determine screen cleaning so if it's not low 
    //we will overwrite the screen that's why before we always add bug  and overwriting whole screen ... 
  //now how can we have objen 3 enable ???? as it's onluy enable during OIBIDR 
  //maybe there is two funcitonement un pendant OIBIDIR pour ecrire et checker vfind et un autre 
  //pendant l'affichahge ?? 
  //reverifier la trace

//******* TEST SUR MAD ** //
//seulement pos y et y offset influe 
//vpd c'est bien pos + offset 
//flip y change (ca fait plein de vfind si non nan ???) 
//mais flip x ne change pas 
//sprite num de change rien non plus 
//


// XXX modify this code make change the pixel drawing X start (if take codex
// code it stat at > 160)
    always @(negedge clk) begin
        if (rst) begin
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VMT    <= 4'b0;
            VFIND  <= 1'b1; 
        end else if (OIBDIR) begin //not during DMA  
           if (~RDCLK) begin 
            //if (check_en)
              //$display("OBJ ENABLE");

              //if (check_en && is_visible) begin //XXX & !OVER48
              //KEEP VIND HIGH FOR 16 PIXEL EACH TIME IT'S FOUND ?

              if (is_visible) begin //XXX ??? why objen is never there ?// & ~OBJEN_3) begin //&OVER@56 //XXX & !OVER48
                  //$display("OBJ IS VISLBE");
                  VFIND <= 1'b0; // XXX HIGH OR LOW ?
                  if (~VREV)
                     VMT <= diff_y[3:0];
                  else
                     VMT <= ~diff_y[3:0]; // Flip Vertical (Top-Down vs Bottom-Up)

                  // write DMA to the inactive line
                  // the other is being read
                  if (current_y[0]) begin
                      ODDWR2 <= 1'b1;
                      EVNWR2 <= 1'b0; // Active Low
                      end 
                  else begin
                      ODDWR2 <= 1'b0; // Active Low
                      EVNWR2 <= 1'b1; // Active Low
                      end
                  end
              else begin
                EVNWR2 <= 1'b1;
                ODDWR2 <= 1'b1;
                VFIND <= 1'b1;
                end
            end 
        else begin 
            VMT    <= 4'b0;
            //VFIND     <= OBJEN_3; //forward objen 3 for later when OIBIDIR ?
            VFIND     <= 1'b1;
            EVNWR2    <= 1'b1; // Inactif (High)
            ODDWR2    <= 1'b1; // Inactif (High)
            end 
        end


    end
endmodule

/*
// sg0140_vheck codex 
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
  //VORIGIN START ONE cycle BEFORE NV256 at 255 and just keep high for one cycle
  //it can be used to launch something nv256 is used to stay until end of line

  // ACTIVE HIGH when DMA is counting
  // it's the inverse of the DMA counter activation Q_148
  // which is high when DMA counter compute address
  // so we certainly need to get OBUSRQ LOW UNTIL OVER256 i high
  input             OVER256,// active low 15.61khz, high during DMA start, the dma counter is then active, and the sg0140 write with EVNWR2 / ODDWR2 the tile info to the memory

  input             OVER48, // Over sprite limit ? Active high
  input             VREVD_2,// OBJ_DB[9] active low (active during attract when there is the magician), generally active when there is sprite but not during cave stuff  is that  that the 8 bit if > 256 or in other screen like {VREV, VPD} % 16
  input             OBJEN_3,// it seem to only appear when there is a new object on the screen like toki, a fireball
  // or a new ennemy then it doesn't appear if it's already in memory ?
  input             H2,     //
  input             RDCLK,  // 6mhz
  input             VCLK,   // 15.61khz
  input             VREV,   //
  input             NV256,  // 59.61 high at half period when over256, active high when vpos > 256

  //output
  output reg  [3:0] VMT,    // output y pos - current line % 16 /address is 19:1
  output reg        EVNWR2, // use DMA2_EA of other sg0140 ?    @6mhz
  output reg        ODDWR2, // use DMA2_OA of other sg0140 in scndma  @6mhz
  output reg        OIBDIR,  //ACTIVE LOW, becore low avec OBUSRQ change to become high again
  output reg        OBUSRQ, // ACTIVE LOW, low one cycle before OIBDIR CHANGE
  output reg        VFIND   // If ODDWR2 or EVNWR2 is low vfind is low so it inform something was found ? when over256 is low vfind is always low too
);
    //assign VFIND = OVER256; //SURE THAT CONTROL NOOBJ
    //NOOBJ = MATCHV = VFIND
    //and matchv in PLD24V is
    // ~(OVER256 & ~VFIND) donc ca ne peux pas marcher comme ca !!! il faut
    // generer cidn parfoid pour dautre raison XXX XXX XXX


    // Internal line counter
    reg [8:0] current_y;
    reg old_vclk;
    reg old_nv256;
    wire vclk_s;
    wire nv256_s;
    wire rdclk_s;

    // Synchronize external strobes into clk domain.
    sync_2ff u_sync_vclk(.clk(clk), .d(VCLK), .q(vclk_s));
    sync_2ff u_sync_nv256(.clk(clk), .d(NV256), .q(nv256_s));
    sync_2ff u_sync_rdclk(.clk(clk), .d(RDCLK), .q(rdclk_s));

    always @(posedge clk) begin
        if (rst) begin
            current_y <= 0;
            old_vclk  <= 0;
            old_nv256 <= 0;
        end else begin
            old_vclk <= vclk_s;
            old_nv256 <= nv256_s;

            // Reset au début de la frame (VORIGIN)
            if (~nv256_s && old_nv256)
                current_y <= 0;
            // Incrément à chaque ligne (VCLK Rising Edge)
            else if (vclk_s && !old_vclk)
                current_y <= current_y + 8'b1;
            end
        end

    // DMA bus request handling
    always @(posedge clk) begin
        if (rst) begin
            OBUSRQ <= 1'b1; // Active Low
            OIBDIR <= 1'b1; // Active Low
            end
        else begin
            // Demande le bus si ODMARQ arrive
            if (!ODMARQ)
              OBUSRQ <= 1'b0;

            // Si le CPU donne le bus (ACK), on prend la main
            if (!OBUSAK && !OBUSRQ) begin
                OIBDIR <= 1'b0; // Enable Drivers
                OBUSRQ <= 1'b1;
                end

            if (OVER256 == 1'b0) begin
                OIBDIR <= 1'b1;
                end
            end
       end

    wire [8:0] sprite_pos_y = {1'b0, VPD};

    // Différence non-signée (attention au wrapping)
    wire [8:0] diff_y = current_y - sprite_pos_y;


    wire check_en = OVER256 & ~OBJEN_3;
   //if (visible && !OVER48) begin
    // Note: Si VREV (Flip Screen) est actif, la logique s'inverse (15 - diff)
    wire is_visible = (diff_y < 16);

    reg rdclk_d;

    always @(posedge clk) begin
        if (rst) begin
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VMT    <= 4'b0;
            VFIND  <= 1'b1;
            rdclk_d <= 1'b0;
        end else begin
            rdclk_d <= rdclk_s;
            // Default inactive between RDCLK edges.
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VFIND  <= 1'b1;

            // Evaluate once per RDCLK falling edge, only when ILD2 is high.
            // Hardware traces show EVN/ODD writes only when ILD2=1.
            if (OIBDIR && rdclk_d && !rdclk_s) begin
                if (is_visible) begin
                    VFIND <= 1'b0; // Active low pulse (match)
                    if (~VREV)
                        VMT <= diff_y[3:0];
                    else
                        VMT <= ~diff_y[3:0]; // Flip Vertical
                end else begin
                    VFIND <= 1'b1;
                    VMT   <= 4'b0;
                end

                // Always write one entry per ILD2 tick to clear stale slots.
                if (current_y[0]) begin
                    ODDWR2 <= 1'b1;
                    EVNWR2 <= 1'b0;
                end else begin
                    ODDWR2 <= 1'b0;
                    EVNWR2 <= 1'b1;
                end
            end
        end
    end
endmodule
*/
