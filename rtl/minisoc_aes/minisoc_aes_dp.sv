`timescale 1ns/1ps
`default_nettype none

// Datapath AES-128 iterativo: AddRoundKey inicial e dez rodadas.
// O controlador deve manter o banco de chaves válido e estável durante busy.
module minisoc_aes_dp (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         i_start,
    input  wire [127:0] i_block,
    input  wire         i_decrypt_primitive,
    input  wire         i_keys_ready,
    input  wire [127:0] i_round_key,
    output logic        o_busy,
    output logic        o_done,
    output logic [127:0] o_result,
    output wire [3:0]   o_round_index
);
    logic [127:0] state_q;
    logic [3:0] round_q;
    logic decrypt_q;
    wire [127:0] sub_state, shift_state, mix_state;
    wire [127:0] inv_shift_state, inv_sub_state, inv_mix_state;
    wire [127:0] add_input, add_state, round_state;

    // Em IDLE, a chave inicial precisa estar disponível antes da aceitação.
    assign o_round_index = o_busy
                         ? (decrypt_q ? (4'd10 - round_q) : round_q)
                         : (i_decrypt_primitive ? 4'd10 : 4'd0);

    minisoc_aes_sub_bytes u_sub (
        .i_state(state_q), .o_state(sub_state));
    minisoc_aes_shift_rows u_shift (
        .i_state(sub_state), .o_state(shift_state));
    minisoc_aes_mix_columns u_mix (
        .i_state(shift_state), .o_state(mix_state));

    minisoc_aes_inv_shift_rows u_inv_shift (
        .i_state(state_q), .o_state(inv_shift_state));
    minisoc_aes_inv_sub_bytes u_inv_sub (
        .i_state(inv_shift_state), .o_state(inv_sub_state));

    // Uma única instância de AddRoundKey atende à inicialização e às rodadas.
    assign add_input = !o_busy ? i_block
                     : decrypt_q ? inv_sub_state
                     : (round_q == 4'd10) ? shift_state : mix_state;
    minisoc_aes_add_round_key u_add (
        .i_state(add_input), .i_round_key(i_round_key), .o_state(add_state));
    minisoc_aes_inv_mix_columns u_inv_mix (
        .i_state(add_state), .o_state(inv_mix_state));

    // Inversa convencional: XOR da chave antes de InvMixColumns.
    // Na rodada 10, as duas direções desviam MixColumns/InvMixColumns.
    assign round_state = (decrypt_q && (round_q != 4'd10))
                       ? inv_mix_state : add_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q   <= 128'h0;
            round_q   <= 4'd0;
            decrypt_q <= 1'b0;
            o_busy    <= 1'b0;
            o_done    <= 1'b0;
            o_result  <= 128'h0;
        end else begin
            o_done <= 1'b0;
            if (o_busy) begin
                // Entrada, direção e starts posteriores não alteram o bloco em curso.
                state_q <= round_state;
                if (round_q == 4'd10) begin
                    o_result <= round_state;
                    o_busy   <= 1'b0;
                    o_done   <= 1'b1;
                end else begin
                    round_q <= round_q + 4'd1;
                end
            end else if (i_start && i_keys_ready) begin
                state_q   <= add_state;
                round_q   <= 4'd1;
                decrypt_q <= i_decrypt_primitive;
                o_busy    <= 1'b1;
                o_result  <= 128'h0;
            end
        end
    end
endmodule

`default_nettype wire
