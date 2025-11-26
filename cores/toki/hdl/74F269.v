module ttl_74F269 (
    input wire clk,
    input wire CP,   
    
    input wire PE_n,     // Parallel Enable (Active Low) -> LOAD
    input wire CEP_n,    // Count Enable Parallel (Active Low)
    input wire CET_n,    // Count Enable Trickle (Active Low)
    input wire U_D,      // Up/Down (1=Up)
    
    input wire [7:0] P,  // Parallel Input
    output reg [7:0] Q,  // Output
    output wire TC_n     // Terminal Count Output
);

    // Terminal Count Logic (Asynchronous in spec, but synchronous here is safer)
    assign TC_n = (CET_n == 1'b0) && (
                  (U_D == 1'b1 && Q == 8'hFF) || 
                  (U_D == 1'b0 && Q == 8'h00)
                  ) ? 1'b0 : 1'b1; // Active Low

    always @(posedge clk) begin
        if (CP) begin
            if (!PE_n) begin
                // Load Synchrone
                Q <= P;
            end else if (!CEP_n && !CET_n) begin
                // Count Synchrone
                if (U_D) Q <= Q + 8'b1;
                else     Q <= Q - 8'b1;
            end
        end
    end
endmodule
