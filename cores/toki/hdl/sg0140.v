///////////////////////////////////////////////////
///////////// SG0140 ABSEL ////////////////////////
///////////////////////////////////////////////////

// SG0140
//
//priority / color mixer
// SG 0140 have 4 different mode
// mode is selected with pin 37/36

//        37,36
// MODE == 00 ABSEL (absolut selection or a b / select? )
// MODE == 10 VCHECK  ?
// MODE == 01 SORT4B  ?
// MODE == 11 OHMAX   ?

//sg0140_absel
module sg0140(
  input       clk, //
  //input       rst,// pin 40
  input       cen, // pin 41, 38, 26 clock & enable

  //BK1
  input [3:0] PIC_A, //pin 9-12
  //input     PIC_A_EN //pin 38 6Mhz  enable color  ?
  input [3:0] COL_A, //pin 13-16
  input       COL_A_EN,// pin 39
  input       MASK_A,  // pin 3

  // CHAR
  input [3:0] PIC_B, //pin 28-31
  //input     PIC_B_EN //pin 26 6Mhz enable color  ?
  input [3:0] COL_B, //pin 32-35
  input       COL_B_EN,   // pin 27 enable
  input       MASK_B, // pin 2
  input [1:0] MODE, //pin 36,37

  output reg  [7:0] Q,  //17-20,23-25

  output reg  ON_A, //pin 8  active high
  output reg  ON_B //pin 7 active high
);

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH;

always @(posedge clk) begin
  if (cen) begin
    if (COL_B_EN)
       COL_B_LATCH[3:0] <= COL_B[3:0];

    if (COL_A_EN)
       COL_A_LATCH[3:0] <= COL_A[3:0];

    ON_A <= (PIC_A[3:0] == 4'hf) ? 1'b0 : 1'b1;
    ON_B <= (PIC_B[3:0] == 4'hf) ? 1'b0 : 1'b1;

    Q[7:0] <= PIC_B[3:0] != 'hf ?  {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                   {COL_A_LATCH[3:0], PIC_A[3:0]};
  end
end

endmodule

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

always @(negedge clk) begin
      if (rst) begin
          OH        <= 5'b0;
          ADDR      <= 5'b0;
          NOOBJ_CT2 <= 1'b0;
          end
      else begin
          //???? TEST NOOBJ_CT2 tout le temps a 1 ou a 0 pour voir si ca fait
          //quuqchose
          //NOOBJ_CT2 <= NOOBJ; //?  //NOOBJ CT2 must be low if obj is not on the line or we don't want to make it aappear glitch may apear here we must check on the originla if this come only as a copy of NOOBJ each CT2 or if there is something else XXX

          // Phase 1 : Capture de la position H (ou High Address)
          if (~CTLT1) begin
              if (~HREV)
                OH[8:4] <= OVD[8:4];
              else
                OH[8:4] <= ~OVD[8:4];
            //  NOOBJ_CT2 <= 1'b0; // ?
              end

          // Phase 2 : Capture de l'adresse ROM et du flag Objet
          if (~CTLT2) begin
              if (~HREV)
                //seems to latch at CTL2 but have same value than OH or input
                ADDR[4:0] <= OH[8:4]; //some shift or fix calculation for rom ?
              else
                ADDR[4:0] <= ~OH[8:4]; //some shift or fix calculation for rom ?
              //NOOBJ_CT2 <= 1'b0;
              // strange make other measure,ents ?
              NOOBJ_CT2 <= NOOBJ; //?  //NOOBJ CT2 must be low if obj is not on the line or we don't want to make it aappear glitch may apear here we must check on the originla if this come only as a copy of NOOBJ each CT2 or if there is something else XXX
            //NOOBJ IS CONTROLLED BY SCNDMA PLD24 MATCHV assign MATCHV =  ~(OVER256 & ~VFIND);
            // VFIND
              end
          //else
            //NOOBJ_CT2 <= 1'b0;
        end
end

endmodule

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

///////////////////////////////////////////////////
///////////// SG0140 SORT 40///////////////////////
///////////////////////////////////////////////////

module sg0140_sort48(
  input       clk,
  input       rst, //pin 40

  input   RDCLK, //main clk ?

  // condition ?
  //input   OVER48, //active high
  input   VFIND, //OVER256 active high when dma is counting

  input   XSDTS, //~STARTV prom_26_data[2]
  input   ILD2, // ~SDTS & DLHD (data line horizontal drive, output NHREV by sei10 serializer)

  //clk & enable ?
  input   V1B,  //vpos[0]
  input   NH2,  //~h_pos[1]
  input   H2,   // 38 A_EN ?  //h_pos[1]
  input   H2_2, //h_pos[1] EN ?

  // 5 output signal do DMA2 ????
  input   [8:4] H,  //h_pos[4]

  output reg  OVER48, // Marked as active high on schematics (TRUE=H)
  output reg  [5:0] DMA2_EA, // address 
  output reg  [5:0] DMA2_OA // 
);

// 1. Construction de l'adresse brute (Raw Address)
  // On concatène les bits H pour former l'index du slot (0 à 63)
  // L'ordre est MSB -> LSB
  wire [5:0] raw_addr = {H[8:7] , H2, H[6:4]};

  // 2. Détection de la limite de sprites (Limit 48)
  // 48 en binaire = 110000
  wire limit_reached = (raw_addr >= 6'd48);
  reg  vfind_edge;

  always @(negedge clk) begin
      if (rst) begin
          DMA2_EA <= 6'b0;
          DMA2_OA <= 6'b0;
          OVER48  <= 1'b1; // Active High ? (A vérifier si VCHECK attend 0 ou 1)
          vfind_edge <= 1'b0;
      end else if (~RDCLK) begin
          // Mise à jour du flag OVER48
          // Si VFIND est inactif (pas de DMA), on reset peut-être ?
          // Gardons la logique simple : monitoring constant de l'adresse.
          OVER48 <= limit_reached;

          // Dispatch de l'adresse vers Even ou Odd RAM
          // V1B (Ligne 0, 1, 2...) détermine quelle RAM est en écriture pour la PROCHAINE ligne.
          // Si V1B=1 (Ligne impaire), on prépare le buffer pour la ligne paire suivante (Even) ?
          // Ou l'inverse. Suivons la logique du code précédent pour l'instant.
          if (VFIND == 1'b0)
            vfind_edge <= 1'b1; 
          else 
            vfind_edge <= 1'b0;


          if (V1B == 1) begin //== 1 => ea
              if (VFIND == 1'b0 & vfind_edge == 0) begin  //@posedge VFIND ? si non change tout les h[0]
                DMA2_EA <= raw_addr; //write addr ?
                DMA2_OA <= DMA2_OA + 1;        // read addr ?
                end 
              else begin  
                //DMA2_EA <= DMA2_EA + 1;  //read addr ?
                DMA2_OA <= DMA2_OA + 1;        // read addr ?
              end 
              //reset and do +1 to read data ?
          end else begin
              if (VFIND == 1'b0 & vfind_edge == 0) begin 
                DMA2_OA <= raw_addr;//write addr ?
                DMA2_EA <= DMA2_EA + 1;  //read addr ?
                end
              else begin 
                DMA2_EA <= DMA2_EA + 1;  //read addr ?
                //DMA2_OA <= DMA2_OA + 1;        // read addr ?
              end 
              //at some point from last value to 64 then 0
          end
      end
  end

endmodule
