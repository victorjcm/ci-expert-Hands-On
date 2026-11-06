`timescale 1ns/1ps
`default_nettype none

// AddRoundKey é sua própria inversa. Os dois barramentos ordenam bytes por coluna.
module minisoc_aes_add_round_key (
    input  wire [127:0] i_state,
    input  wire [127:0] i_round_key,
    output wire [127:0] o_state
);
    assign o_state = i_state ^ i_round_key;
endmodule

`default_nettype wire
