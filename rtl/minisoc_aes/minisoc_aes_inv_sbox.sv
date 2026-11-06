`timescale 1ns/1ps
`default_nettype none

// S-box inversa do AES: transformação afim inversa e inversão em GF(2^8).
// FIPS-197, seção 5.3.2. Usa o mesmo polinômio (0x11b) da S-box direta.
module minisoc_aes_inv_sbox (
    input  wire [7:0] i_byte,
    output wire [7:0] o_byte
);
    function automatic logic [7:0] gf_multiply (
        input logic [7:0] a,
        input logic [7:0] b
    );
        logic [7:0] multiplicand;
        logic [7:0] multiplier;
        logic [7:0] product;
        begin
            multiplicand = a;
            multiplier = b;
            product = 8'h00;
            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                product = product ^ (multiplicand & {8{multiplier[0]}});
                multiplicand = {multiplicand[6:0], 1'b0}
                             ^ (8'h1b & {8{multiplicand[7]}});
                multiplier = {1'b0, multiplier[7:1]};
            end
            gf_multiply = product;
        end
    endfunction

    wire [7:0] affine_inverse;
    wire [7:0] x2, x4, x8, x16, x32, x64, x128;

    // Transformação afim inversa; rotl indica rotação de bits para a esquerda.
    // A^-1(y) = rotl(y,1) XOR rotl(y,3) XOR rotl(y,6) XOR 05.
    assign affine_inverse = {i_byte[6:0], i_byte[7]}
                          ^ {i_byte[4:0], i_byte[7:5]}
                          ^ {i_byte[1:0], i_byte[7:2]}
                          ^ 8'h05;
    assign x2   = gf_multiply(affine_inverse, affine_inverse);
    assign x4   = gf_multiply(x2, x2);
    assign x8   = gf_multiply(x4, x4);
    assign x16  = gf_multiply(x8, x8);
    assign x32  = gf_multiply(x16, x16);
    assign x64  = gf_multiply(x32, x32);
    assign x128 = gf_multiply(x64, x64);

    // a^254 mapeia zero em zero; em particular, InvSbox(63) = 00.
    assign o_byte = gf_multiply(
        gf_multiply(gf_multiply(x2, x4), gf_multiply(x8, x16)),
        gf_multiply(x32, gf_multiply(x64, x128))
    );
endmodule

`default_nettype wire
