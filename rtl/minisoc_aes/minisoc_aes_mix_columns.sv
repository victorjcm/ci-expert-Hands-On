`timescale 1ns/1ps
`default_nettype none

// FIPS-197, seção 5.1.3: multiplicação independente de cada coluna do estado
// pela matriz {02,03,01,01; 01,02,03,01; 01,01,02,03; 03,01,01,02} em GF(2^8).
module minisoc_aes_mix_columns (
    input  wire [127:0] i_state,
    output wire [127:0] o_state
);
    function automatic logic [7:0] xtime(input logic [7:0] value);
        xtime = {value[6:0], 1'b0} ^ (8'h1b & {8{value[7]}});
    endfunction

    for (genvar col = 0; col < 4; col++) begin : g_column
        wire [7:0] a0, a1, a2, a3;
        wire [7:0] x0, x1, x2, x3;

        assign {a0, a1, a2, a3} = i_state[127 - 32*col -: 32];
        assign x0 = xtime(a0);
        assign x1 = xtime(a1);
        assign x2 = xtime(a2);
        assign x3 = xtime(a3);

        // Multiplicação por 03: 03*a = xtime(a) XOR a.
        assign o_state[127 - 32*col -: 32] = {
            x0 ^ x1 ^ a1 ^ a2 ^ a3,
            a0 ^ x1 ^ x2 ^ a2 ^ a3,
            a0 ^ a1 ^ x2 ^ x3 ^ a3,
            x0 ^ a0 ^ a1 ^ a2 ^ x3
        };
    end
endmodule

`default_nettype wire
