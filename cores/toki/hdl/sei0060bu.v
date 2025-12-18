module SEI0060BU(
   input wire clk,      // 48MHz System Clock
   input wire cen,      // Clock Enable (N6M ou P6M selon schéma)

   input wire [8:0] ADDR, // Adresse venant du 74LS273 (U1716)
   input wire ODD_LD,     // Load Odd Address (happen only when V1B == 1)
   input wire EVN_LD,     // Load Even Address (happen only when V1B == 0)
   
   input wire HBLB,       // when low oa ea are 0 
   input wire OBJT2_7,    // Timing specific
   input wire V1B,        // Ligne paire/impaire
   input wire T8H,        // every 16 pixel (16 after load ? to stop and reset counter?) 
   input wire HREV,

   output reg [8:0] OA,   // Odd Address Output
   output reg [8:0] EA,   // Even Address Output

   output reg EVNCLR,     // Line Buffer Clear/Reset (Active Low?)
   output reg ODDCLR
);

// on dirait que ca fait uniquement  + 16 des fois 
// si non ca fait un counter normal, peut etre que c'est aussi utiliser en
// counter nromal en mode clear et si non en mode normal il count que par
// tranche de 16 ?
// mais qui lance clear ? 
  reg [8:0] video_counter;

   always @(posedge clk) begin
       if (cen) begin
           // Reset du compteur vidéo au début de la ligne active
           // Note: Ajuster la condition selon si HBLB est le début ou la fin
           // Sur Toki, la lecture commence quand HBLB passe à 1 (Active)
           if (!HBLB) begin 
               video_counter <= 9'd0;
           end
           else begin
               video_counter <= video_counter + 1'b1;
           end
       end
   end

//we need to use that because HBLB is longer than a line it stop after 16
//pixels so if we don't do that it will start clearing a line then continue on
//the next line because hblb will be down when V1B change value 
reg hblb_start;

always @(posedge clk) begin 
   if (cen) begin 

      //else begin
         //clear one line on the other in RAM 
         //
         if (~HBLB) begin 
            if (V1B == 0 & ~hblb_start) begin 
               hblb_start <= 1'b1; 
               ODDCLR <= 1'b0;
               OA <= 9'b0;
               end 
            else if (V1B == 1 & ~hblb_start) begin
               hblb_start <= 1'b1; 
               EVNCLR <= 1'b0;
               EA <= 9'b0;
               end 
            end
         else begin  
            hblb_start <= 1'b0;
            EVNCLR <= 1'b1; 
            ODDCLR <= 1'b1; 
            end

         if (OBJT2_7) begin 
               //start a 0 to clr ? 
               OA <= OA + 1'b1;  // ? 
               EA <= EA + 1'b1;  // ? 
               end 
         else begin 
            if (!ODD_LD) begin
               OA <= ADDR;
               end
            else if (!EVN_LD) begin 
               EA <= ADDR;
               end
               //if T8H reset ? or continue if  OBJT2_7 ? 
            //else if (T8H) begin //?  
               //OA <= ADDR; 
               //EA <= ADDR;
               //end 
            else begin
               OA <= OA + 1'b1;
               EA <= EA + 1'b1;
               end 
         end
      end 
   //end 
end 

endmodule
