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

    // Terminal-count output is combinational, as on the physical device.
    assign TC_n = (CET_n == 1'b0) && (
                  (U_D == 1'b1 && Q == 8'hFF) || 
                  (U_D == 1'b0 && Q == 8'h00)
                  ) ? 1'b0 : 1'b1; // Active Low

    // The physical counter samples its enables only on the rising CP edge.
    // Sheet-14 U147 advances once per RDCLK edge, so CEP_n becomes active while
    // FDA=11 and is sampled on the following RDCLK edge that wraps FDA to 00.
    // Treating CP as a level either counts early or increments more than once
    // during the several 48 MHz clocks for which RDCLK remains high.
    reg cp_d = 1'b0;
    wire cp_rise = CP && !cp_d;

    always @(posedge clk) begin
        cp_d <= CP;
        if (cp_rise) begin
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
