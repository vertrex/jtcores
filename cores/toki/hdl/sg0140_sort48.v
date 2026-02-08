///////////////////////////////////////////////////
///////////// SG0140 SORT 48///////////////////////
///////////////////////////////////////////////////

// ECRIT ET LIT 
// VA ECRIRE LES INFOSO DANS LES 2er SIS6091B de scndma 
// mais en read va sortir les infos de ses 2 sis6091B 
// qui vont donner CTA pour lire le 6091 u183 
// si ca ne bouge pas on aura tjrs le meme sprite afficher 

// MAD 
// si on change sprite num oa3/oa4/vfind goes down temporariement 
// pareil pour pos x mais temporrairement 
// pos y -> h128 chantemporariemtn o3/o4/vfind aussi puis h256 reste up (pos
// y ++ 0xaa
// offset x -> oa3/o4/vfind change temporairement 
// offset y -> oa3/o4/vfind change temporairement offset y influcen H64
// flip x -> o3/o4/vfind change temporairement 
// flip y -> o3/o4/vfind change temporairement si up -> (flpped) h32 is high
//
// si vfind influcen la sorite ? et change la valewur si non valeur par
// default ? une fois store on touche plus au pixel 
// on store juste quand il y a un change ? 

module sg0140_sort48(
  input   clk,
  input   rst, //pin 40

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


//XSDTS  -> deux coimportemenr differents 
//XSTS low dma ? va ecrire dans les chips de scnddma 
          if (~XSDTS) begin // DMA active 

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
              end 
            else begin
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
         else  begin//XSDTS  begin 
            DMA2_EA <= DMA2_EA + 1; 
            DMA2_OA <= DMA2_OA + 1;
            end 
  end

endmodule



/**
*
// sg0140_sort48 codex 

module sg0140_sort48(
  input   clk,
  input   rst, //pin 40

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

  // H-slot index (0..63) derived from screen H position.
  // If parity looks inverted on alternating lines, flip INV_V1B below.
  localparam INV_V1B = 1'b0;
  wire v1b_sel = INV_V1B ? ~V1B : V1B;
  wire [5:0] hslot = {H[8:7], H2, H[6:4]};

  // The traces show a fixed phase offset between H-slot and list RAM address.
  // Using constants is more plausible than a deep delay chain inside the gate-array.
  localparam [5:0] OFF_A = 6'd33;
  localparam [5:0] OFF_B = 6'd17;

  // Mapping observed: when V1B=0 -> EA = hslot-33 ; when V1B=1 -> EA = hslot-17
  wire [5:0] ea_map = hslot - (v1b_sel ? OFF_B : OFF_A);
  wire [5:0] oa_map = hslot - (v1b_sel ? OFF_A : OFF_B);

  // Over48 is based on the H-slot index (per-line sprite budget).
  wire limit_reached = (hslot >= 6'd48);

  always @(posedge clk) begin
      if (rst) begin
          DMA2_EA <= 6'b0;
          DMA2_OA <= 6'b0;
          OVER48  <= 1'b0;
      end else begin
          DMA2_EA <= ea_map;
          DMA2_OA <= oa_map;
          OVER48  <= limit_reached;
      end
  end

endmodule
*/


/*

old gemini 

module sg0140_sort48(
  input       clk,
  input       rst,      // pin 40

  input       RDCLK,    // main clk ?

  input       VFIND,    // Active LOW (from VCheck), indicates a valid sprite found
  input       XSDTS,    // Active LOW = DMA Mode (Writing), HIGH = Display Mode (Reading)
  input       ILD2,     // Unused in logic but kept for pinout

  input       V1B,      // Ligne LSB (0=Even Line, 1=Odd Line)
  input       NH2,      // Unused
  input       H2,       // Part of raw address
  input       H2_2,     // Unused
  input       [8:4] H,  // Horizontal Position (Part of raw address)

  output reg  OVER48,   // Active High (Flag > 48 sprites)
  output reg  [5:0] DMA2_EA, // Even Address
  output reg  [5:0] DMA2_OA  // Odd Address
);

  // 1. Adresse de Lecture (Display)
  // Basée sur le balayage horizontal (H). C'est l'adresse utilisée pour LIRE les sprites à afficher.
  // On garde ta logique d'origine pour le mapping.
  wire [5:0] raw_addr = {H[8:7], H2, H[6:4]};

  // 2. Compteur d'Ecriture (Stack Pointer)
  // C'est lui qui empile les sprites trouvés (0, 1, 2...) sans trous.
  reg [5:0] stack_ptr;
  
  // Detection de front pour VFIND (car VFIND peut rester bas plusieurs cycles)
  reg vfind_prev;
  wire vfind_falling_edge = (vfind_prev == 1'b1 && VFIND == 1'b0);

  // Logique du Compteur et OVER48
  always @(negedge clk) begin
      if (rst) begin
          stack_ptr <= 6'b0;
          OVER48 <= 1'b0; // Active High reset
          vfind_prev <= 1'b1;
      end
      else begin
          // Gestion du front VFIND
          vfind_prev <= VFIND;

          // Si on n'est PAS en DMA (XSDTS = 1), on reset le compteur pour la prochaine fois
          if (XSDTS) begin
              stack_ptr <= 6'b0;
              OVER48 <= 1'b0;
          end
          // Si on est en DMA (XSDTS = 0)
          else begin
              // Si un sprite est trouvé (Front descendant de VFIND)
              if (vfind_falling_edge) begin
                  if (stack_ptr >= 6'd48) begin
                      OVER48 <= 1'b1; // Flag overflow
                      // On bloque le compteur ou on le laisse tourner (selon hardware original)
                      // Ici on bloque pour ne pas écraser le début
                  end
                  else begin
                      stack_ptr <= stack_ptr + 1'b1;
                  end
              end
          end
      end
  end

  // Logique de Sortie des Adresses (Multiplexage)
  always @(negedge clk) begin
      if (rst) begin
          DMA2_EA <= 6'b0;
          DMA2_OA <= 6'b0;
      end
      else begin
          // ---------------------------------------------------------
          // MODE DMA (H-BLANK) : ECRITURE DU BUFFER
          // ---------------------------------------------------------
          if (!XSDTS) begin 
             // Logique Ping-Pong basée sur V1B
             // Si V1B=1 (Ligne Impaire), on prépare la Ligne Paire (Next Line Even)
             // Donc on ECRIT dans EVEN (avec stack_ptr) et on peut LIRE ODD (avec raw_addr)
             if (V1B) begin
                 DMA2_EA <= stack_ptr; // Ecriture (Stack)
                 DMA2_OA <= raw_addr;  // Lecture (Scan/Debug)
             end
             // Si V1B=0 (Ligne Paire), on prépare la Ligne Impaire (Next Line Odd)
             else begin
                 DMA2_OA <= stack_ptr; // Ecriture (Stack)
                 DMA2_EA <= raw_addr;  // Lecture (Scan/Debug)
             end
          end
          
          // ---------------------------------------------------------
          // MODE DISPLAY (ACTIVE VIDEO) : LECTURE DU BUFFER
          // ---------------------------------------------------------
          else begin
             // Pendant l'affichage, les deux RAMs sont adressées par le scan vidéo
             // pour récupérer les sprites à afficher.
             DMA2_EA <= raw_addr;
             DMA2_OA <= raw_addr;
          end
      end
  end

  endmodule
*/
