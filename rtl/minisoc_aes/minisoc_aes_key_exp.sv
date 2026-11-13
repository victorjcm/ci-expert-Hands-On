`timescale 1ns/1ps
`default_nettype none

// AES-128: K0 na aceitação e K1..K10 nas dez bordas seguintes.
// Banco pré-computado para permitir leitura direta ou inversa das round keys.
module minisoc_aes_key_exp (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         i_start,
    input  wire [127:0] i_key,
    input  wire [3:0]   i_round_index,
    output logic        o_busy,
    output logic        o_done,
    output logic        o_keys_ready,
    output wire [127:0] o_round_key
);
    logic [127:0] round_keys_q [0:10];
    // Durante busy, round_q seleciona a chave anterior à que será escrita.
    logic [3:0] round_q;
    logic [7:0] rcon_q;
    wire [127:0] previous_key;
    wire [31:0] rotated_word, substituted_word;
    wire [31:0] next_w0, next_w1, next_w2, next_w3;

    function automatic logic [7:0] xtime(input logic [7:0] value);
        xtime = {value[6:0], 1'b0} ^ (8'h1b & {8{value[7]}});
    endfunction

    assign previous_key = round_keys_q[round_q];
    // RotWord de w3: {b0,b1,b2,b3} passa a {b1,b2,b3,b0}.
    assign rotated_word = {previous_key[23:0], previous_key[31:24]};
    for (genvar byte_index = 0; byte_index < 4; byte_index++) begin : g_sub_word
        minisoc_aes_sbox u_sbox (
            .i_byte (rotated_word[31 - 8*byte_index -: 8]),
            .o_byte (substituted_word[31 - 8*byte_index -: 8])
        );
    end

    assign next_w0 = previous_key[127:96] ^ substituted_word ^ {rcon_q, 24'h0};
    assign next_w1 = previous_key[95:64] ^ next_w0;
    assign next_w2 = previous_key[63:32] ^ next_w1;
    assign next_w3 = previous_key[31:0] ^ next_w2;

    // Não expor um banco parcial como chave válida. Índices 11..15 retornam zero.
    assign o_round_key = (o_keys_ready && (i_round_index <= 4'd10))
                       ? round_keys_q[i_round_index] : 128'h0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int key_index = 0; key_index < 11; key_index++) begin
                round_keys_q[key_index] <= 128'h0;
            end
            round_q      <= 4'd0;
            rcon_q       <= 8'h01;
            o_busy       <= 1'b0;
            o_done       <= 1'b0;
            o_keys_ready <= 1'b0;
        end else begin
            o_done <= 1'b0;
            if (o_busy) begin
                // i_start durante busy é ignorado, inclusive nesta última borda.
                round_keys_q[round_q + 4'd1] <= {next_w0, next_w1, next_w2, next_w3};
                if (round_q == 4'd9) begin
                    o_busy       <= 1'b0;
                    o_done       <= 1'b1;
                    o_keys_ready <= 1'b1;
                end else begin
                    round_q <= round_q + 4'd1;
                    rcon_q  <= xtime(rcon_q);
                end
            end else if (i_start) begin
                round_keys_q[0] <= i_key;
                round_q        <= 4'd0;
                rcon_q         <= 8'h01;
                o_busy         <= 1'b1;
                o_keys_ready   <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
