module ttl_74F269 (
    input  wire        CP,       // Horloge (front montant)
    input  wire        PE_n,     // Parallel Enable (actif bas) -> charge les entrées P
    input  wire        CEP_n,    // Count Enable Parallel (actif bas)
    input  wire        CET_n,    // Count Enable Trickle (actif bas)
    input  wire        U_D,      // 1 = Up, 0 = Down
    input  wire [7:0]  P,        // Entrées parallèles P0..P7
    output reg  [7:0]  Q,        // Sorties Q0..Q7
    output wire        TC_n      // Terminal Count (actif bas)
);

    // --- Processus principal : clear asynchrone, comptage synchrone ---
    always @(posedge CP) begin
        if (!PE_n)
            Q <= P;                            // Chargement parallèle (synchrone)
        else if ((!CEP_n) && (!CET_n)) begin
            if (U_D)
                Q <= Q + 8'd1;                 // Compte vers le haut
            else
                Q <= Q - 8'd1;                 // Compte vers le bas
        end
        else
            Q <= Q;                            // Maintien
    end

    // --- Terminal Count (actif bas) ---
    // Produit un niveau bas lorsque le compteur atteint 0xFF (UP)
    // ou 0x00 (DOWN), si le comptage est activé.
    assign TC_n = ( (!CEP_n) && (!CET_n) &&
                    ((U_D && (Q == 8'hFF)) ||
                     (!U_D && (Q == 8'h00))) )
                    ? 1'b0 : 1'b1;

endmodule

