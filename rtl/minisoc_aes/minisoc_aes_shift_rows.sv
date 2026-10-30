`timescale 1ns/1ps
`default_nettype none

// Forward ShiftRows: s_out[r][c] = s_in[r][(c+r) % 4].
// Column-major serialization; only static wiring, no shifter or storage.
module minisoc_aes_shift_rows (
    input  wire [127:0] i_state,
    output wire [127:0] o_state
);
    // Output byte order: 0,5,10,15, 4,9,14,3, 8,13,2,7, 12,1,6,11.
    assign o_state = {
        i_state[127:120], i_state[87:80], i_state[47:40], i_state[7:0],
        i_state[95:88], i_state[55:48], i_state[15:8], i_state[103:96],
        i_state[63:56], i_state[23:16], i_state[111:104], i_state[71:64],
        i_state[31:24], i_state[119:112], i_state[79:72], i_state[39:32]
    };
endmodule

`default_nettype wire
