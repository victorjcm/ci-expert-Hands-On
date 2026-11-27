`timescale 1ns/1ps
`default_nettype none

// Memória single-port: o conteúdo e a saída de leitura não possuem reset.
// Na transferência, o mestre externo deve estar quiescente, com mem_clk=0
// e mem_i_wr_en=0. A seleção solicitada deve permanecer estável até o ack.
module minisoc_memory (
    input  wire        i_mem_sel_aes,
    input  wire        i_aes_busy,
    output logic       o_mem_sel_aes,
    input  wire        mem_clk,
    input  wire [31:0] mem_i_data,
    input  wire        mem_i_wr_en,
    input  wire [9:0]  mem_i_addr,
    output wire [31:0] mem_o_data,
    input  wire        aes_clk,
    input  wire [31:0] aes_i_data,
    input  wire        aes_i_wr_en,
    input  wire [9:0]  aes_i_addr,
    output wire [31:0] aes_o_data
);
    logic [31:0] memory [0:1023];
    logic [31:0] read_data_q;
    wire port_clk;
    wire [9:0] port_addr;
    wire [31:0] port_data;
    wire port_wr_en;

    // Latch intencional: o owner efetivo só muda com os dois clocks baixos.
    // Assim, trocar a solicitação com aes_clk alto não cria uma borda falsa.
    // BUSY retém o owner durante toda a operação, inclusive as quatro escritas.
    // Na inicialização, manter ambos os clocks baixos e solicitar owner externo.
    always_latch begin
        if (!mem_clk && !aes_clk && !i_aes_busy)
            o_mem_sel_aes <= i_mem_sel_aes;
    end

    assign port_clk   = o_mem_sel_aes ? aes_clk       : mem_clk;
    assign port_addr  = o_mem_sel_aes ? aes_i_addr    : mem_i_addr;
    assign port_data  = o_mem_sel_aes ? aes_i_data    : mem_i_data;
    assign port_wr_en = o_mem_sel_aes ? aes_i_wr_en   : mem_i_wr_en;
    assign mem_o_data = read_data_q;
    assign aes_o_data = read_data_q;

    // Um único processo e um único porto. Durante write, a saída retém
    // a última leitura; o consumidor só deve utilizá-la após uma leitura.
    always_ff @(posedge port_clk) begin
        if (port_wr_en)
            memory[port_addr] <= port_data;
        else
            read_data_q <= memory[port_addr];
    end
endmodule

`default_nettype wire
