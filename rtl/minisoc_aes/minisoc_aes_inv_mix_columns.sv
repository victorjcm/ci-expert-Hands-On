`timescale 1ns/1ps
`default_nettype none

// FIPS-197, seção 5.3.3: matriz com coeficientes 0e/0b/0d/09.
// Fatoração: corrigir pares de linhas opostas e aplicar MixColumns direto.
// A transformação inversa é aplicada ao estado, sem modificar a chave da rodada.
module minisoc_aes_inv_mix_columns (
    input  wire [127:0] i_state,
    output wire [127:0] o_state
);
    wire [127:0] preconditioned;

    function automatic logic [7:0] xtime(input logic [7:0] value);
        xtime = {value[6:0], 1'b0} ^ (8'h1b & {8{value[7]}});
    endfunction

    for (genvar col = 0; col < 4; col++) begin : g_column
        wire [7:0] a0, a1, a2, a3;
        wire [7:0] even_correction, odd_correction;
        assign {a0, a1, a2, a3} = i_state[127 - 32*col -: 32];
        assign even_correction = xtime(xtime(a0 ^ a2));
        assign odd_correction  = xtime(xtime(a1 ^ a3));
        assign preconditioned[127 - 32*col -: 32] = {
            a0 ^ even_correction, a1 ^ odd_correction,
            a2 ^ even_correction, a3 ^ odd_correction
        };
    end

    minisoc_aes_mix_columns u_mix_columns (
        .i_state (preconditioned),
        .o_state (o_state)
    );
endmodule

`default_nettype wire
