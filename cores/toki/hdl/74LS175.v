module LS175(
    input  wire       CLK,     // Horloge (front montant)
    input  wire       CLR_n,   // Clear asynchrone actif bas
    input  wire       CEN,     // Clock Enable (actif haut)
    input  wire [3:0] D,       // Entrées de données
    output reg  [3:0] Q,       // Sorties directes
    output wire [3:0] Qn       // Sorties inversées
);

    // Clear asynchrone actif bas
    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n)
            Q <= 4'b0000;         // Reset asynchrone
        else if (CEN)
            Q <= D;               // Capture sur front montant si CEN=1
        // sinon (CEN=0) -> Q inchangé
    end

    // Sorties complémentaires
    assign Qn = ~Q;

endmodule

