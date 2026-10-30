`timescale 1ns/1ps
`default_nettype none

// Byte n = state[127 - 8*n -: 8] = s[n % 4][n / 4].
// Sixteen independent forward S-box instances; no state or handshake.
module minisoc_aes_sub_bytes (
    input  wire [127:0] i_state,
    output wire [127:0] o_state
);
    for (genvar byte_index = 0; byte_index < 16; byte_index++) begin : g_sbox
        minisoc_aes_sbox u_sbox (
            .i_byte (i_state[127 - 8*byte_index -: 8]),
            .o_byte (o_state[127 - 8*byte_index -: 8])
        );
    end
endmodule

`default_nettype wire
