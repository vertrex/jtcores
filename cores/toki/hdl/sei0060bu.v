module SEI0060BU(
   input wire clk,      // 48MHz System Clock
   input wire cen,      // Clock Enable (N6M ou P6M selon schéma)

   input wire [8:0] ADDR, // Adresse venant du 74LS273 (U1716)
   input wire ODD_LD,     // Load Odd Address
   input wire EVN_LD,     // Load Even Address
   
   input wire HBLB,       // Horizontal Blanking (Active Low ?)
   input wire OBJT2_7,    // Timing specific
   input wire V1B,        // Ligne paire/impaire
   input wire T8H,
   input wire HREV,

   output reg [8:0] OA,   // Odd Address Output
   output reg [8:0] EA,   // Even Address Output

   output reg EVNCLR,     // Line Buffer Clear/Reset (Active Low?)
   output reg ODDCLR
);

  always @(posedge clk) begin 
      if (cen) begin 
         // --- Gestion du Compteur ODD (OA) ---
         if (!ODD_LD) begin
            // Chargement de la position X de départ
            OA <= ADDR;
         end 
         else if (T8H) begin
            // Incrément/Décrément pour écrire les 16 pixels du sprite
            if (HREV) OA <= OA - 1'b1;
            else      OA <= OA + 1'b1;
         end

         // --- Gestion du Compteur EVEN (EA) ---
         if (!EVN_LD) begin
            EA <= ADDR;
         end 
         else if (T8H) begin
            if (HREV) EA <= EA - 1'b1;
            else      EA <= EA + 1'b1;
         end

         if (!HBLB) begin 
            if (V1B == 1'b0) //OBJT2_7 ?  
               EVNCLR <= 1'b0; // Clear next line ?  
            else 
               ODDCLR <= 1'b0;
         end else begin
            EVNCLR <= 1'b1; // Normal operation
            ODDCLR <= 1'b1;
         end
         
         // Note : OBJT2_7 et V1B ne semblent pas modifier l'adresse directement ici,
         // mais servent probablement à sélectionner quel compteur est chargé via les équations de PLD22 
         // qui génèrent ODD_LD / EVN_LD.
      end 
   end 
endmodule
