`timescale 1ns/1ps
`default_nettype none

// Modelo de integracao: NAO implementa AES nem oferece seguranca criptografica.
// Pulso start e aceito na subida do clock quando busy == 0.
// A saida aparece LATENCY ciclos APOS a borda de aceitacao (LATENCY >= 1).
// Pedidos durante busy sao ignorados, inclusive na borda de conclusao.
// done dura um ciclo; data_out permanece valido ate nova conclusao ou reset.
module aes_teste #(
    parameter int unsigned LATENCY = 4
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] data_in,
    input  logic [127:0] key,
    output logic         busy,
    output logic         done,
    output logic [127:0] data_out
);
    localparam int unsigned COUNT_WIDTH = (LATENCY < 2) ? 1 : $clog2(LATENCY + 1);

    logic [COUNT_WIDTH-1:0] cycles_left;
    logic [127:0] data_q;
    logic [127:0] key_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycles_left <= '0;
            data_q      <= '0;
            key_q       <= '0;
            data_out    <= '0;
            busy        <= 1'b0;
            done        <= 1'b0;
        end else begin
            done <= 1'b0;

            if (busy) begin
                if (cycles_left == COUNT_WIDTH'(1)) begin
                    // Transformacao previsivel apenas para testar a integracao.
                    data_out    <= data_q ^ key_q;
                    cycles_left <= '0;
                    busy        <= 1'b0;
                    done        <= 1'b1;
                end else begin
                    cycles_left <= cycles_left - COUNT_WIDTH'(1);
                end
            end else if (start) begin
                data_q      <= data_in;
                key_q       <= key;
                cycles_left <= COUNT_WIDTH'(LATENCY);
                busy        <= 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
