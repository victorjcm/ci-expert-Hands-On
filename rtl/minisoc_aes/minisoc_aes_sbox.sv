`timescale 1ns/1ps
`default_nettype none

// AES forward S-box: inverse in GF(2^8), then affine transformation.
// FIPS-197, sections 4.2 and 5.1.1. No clock, reset or storage.
module minisoc_aes_sbox (
    input  wire [7:0] i_byte,
    output wire [7:0] o_byte
);
    // Reduction polynomial: x^8 + x^4 + x^3 + x + 1 (0x11b).
    // Fixed loop bounds allow synthesis into combinational logic.
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

    wire [7:0] x2, x4, x8, x16, x32, x64, x128;
    wire [7:0] inverse;

    assign x2   = gf_multiply(i_byte, i_byte);
    assign x4   = gf_multiply(x2, x2);
    assign x8   = gf_multiply(x4, x4);
    assign x16  = gf_multiply(x8, x8);
    assign x32  = gf_multiply(x16, x16);
    assign x64  = gf_multiply(x32, x32);
    assign x128 = gf_multiply(x64, x64);

    // a^-1 = a^254 for a != 0; this expression also maps 0 to 0.
    assign inverse = gf_multiply(
        gf_multiply(gf_multiply(x2, x4), gf_multiply(x8, x16)),
        gf_multiply(x32, gf_multiply(x64, x128))
    );

    // b = a ^ rotl(a,1) ^ rotl(a,2) ^ rotl(a,3) ^ rotl(a,4) ^ 0x63.
    assign o_byte = inverse
                  ^ {inverse[6:0], inverse[7]}
                  ^ {inverse[5:0], inverse[7:6]}
                  ^ {inverse[4:0], inverse[7:5]}
                  ^ {inverse[3:0], inverse[7:4]}
                  ^ 8'h63;
endmodule

`default_nettype wire
