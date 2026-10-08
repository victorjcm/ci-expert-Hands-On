`timescale 1ns/1ps
`default_nettype none

module tb_aes_teste;
    // Pode ser alterado para exercitar outras latencias positivas, inclusive 1.
    localparam int unsigned LATENCY = 4;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [127:0] data_in = '0;
    logic [127:0] key = '0;
    wire busy;
    wire done;
    wire [127:0] data_out;

    logic [127:0] last_result = '0;
    int unsigned tests_passed = 0;

    aes_teste #(.LATENCY(LATENCY)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .key(key),
        .busy(busy),
        .done(done),
        .data_out(data_out)
    );

    always #5 clk = ~clk; // Clock de 100 MHz.

    // Amostra depois das atualizacoes nao bloqueantes do DUT.
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check_outputs(
        input logic expected_busy,
        input logic expected_done,
        input logic [127:0] expected_data,
        input string context_name
    );
        if ((busy !== expected_busy) || (done !== expected_done) ||
            (data_out !== expected_data)) begin
            $fatal(1, "%s: busy=%b done=%b data=%032h; esperado %b %b %032h",
                   context_name, busy, done, data_out,
                   expected_busy, expected_done, expected_data);
        end
    endtask

    task automatic run_case(
        input logic [127:0] payload,
        input logic [127:0] cipher_key,
        input bit inject_busy_start,
        input string case_name
    );
        logic [127:0] expected;
        expected = payload ^ cipher_key;

        // Dirige na descida para evitar disputa com a captura do DUT.
        @(negedge clk);
        data_in = payload;
        key = cipher_key;
        start = 1'b1;
        tick();
        check_outputs(1'b1, 1'b0, last_result, {case_name, ": aceitacao"});

        for (int unsigned cycle = 1; cycle <= LATENCY; cycle++) begin
            @(negedge clk);
            // Altera entradas para comprovar que o DUT usa os valores capturados.
            data_in = ~payload;
            key = cipher_key ^ 128'h1;
            // Solicita outro trabalho durante busy; nao deve ser enfileirado.
            start = inject_busy_start && (cycle == 1);
            tick();
            if (cycle < LATENCY)
                check_outputs(1'b1, 1'b0, last_result, {case_name, ": processamento"});
            else
                check_outputs(1'b0, 1'b1, expected, {case_name, ": conclusao"});
        end

        // Sem tick adicional: o proximo caso pode iniciar na borda seguinte.
        last_result = expected;
        tests_passed++;
        $display("PASS: %s", case_name);
    endtask

    initial begin : stimulus
        if (LATENCY < 1)
            $fatal(1, "LATENCY deve ser maior ou igual a 1");

        repeat (2) tick();
        check_outputs(1'b0, 1'b0, '0, "reset inicial");
        @(negedge clk);
        rst_n = 1'b1;
        tick();
        check_outputs(1'b0, 1'b0, '0, "ocioso apos reset");

        run_case('0, '0, 1'b0, "entrada e chave zero");
        run_case('1, '0, 1'b0, "todos os bits da entrada em um");
        run_case('0, '1, 1'b0, "todos os bits da chave em um");
        run_case(128'h00112233445566778899aabbccddeeff,
                 128'h000102030405060708090a0b0c0d0e0f,
                 1'b1, "captura de entradas e start ignorado durante busy");
        run_case(128'h0123456789abcdeffedcba9876543210,
                 128'h0123456789abcdeffedcba9876543210,
                 1'b0, "operandos iguais e nova operacao apos done");

        @(negedge clk);
        start = 1'b0;
        repeat (LATENCY + 2) begin
            tick();
            check_outputs(1'b0, 1'b0, last_result, "done de um ciclo e saida retida");
        end
        tests_passed++;
        $display("PASS: done de um ciclo, saida retida e nenhuma operacao pendente");

        // Aborta uma operacao entre bordas para verificar o reset assincrono.
        @(negedge clk);
        data_in = '1;
        key = '0;
        start = 1'b1;
        tick();
        check_outputs(1'b1, 1'b0, last_result, "aceitacao antes do abort");
        #1;
        rst_n = 1'b0;
        #1;
        check_outputs(1'b0, 1'b0, '0, "reset assincrono durante busy");
        @(negedge clk);
        start = 1'b0;
        repeat (2) tick();
        @(negedge clk);
        rst_n = 1'b1;
        last_result = '0;
        repeat (LATENCY + 2) begin
            tick();
            check_outputs(1'b0, 1'b0, '0, "nenhuma conclusao atrasada apos reset");
        end
        tests_passed++;
        $display("PASS: reset aborta operacao e limpa a saida");

        run_case(128'hfedcba98765432100123456789abcdef,
                 128'h0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f,
                 1'b0, "recuperacao apos reset");
        @(negedge clk);
        start = 1'b0;
        tick();
        check_outputs(1'b0, 1'b0, last_result, "estado final");
        $display("PASS: tb_aes_teste - %0d testes concluidos", tests_passed);
        $finish;
    end

    // Encerra com falha se algum evento esperado nunca ocorrer.
    initial begin : watchdog
        #10000;
        $fatal(1, "TIMEOUT: testbench nao terminou em 10 us");
    end

    // Forma de onda opcional: ./simv +DUMP_VCD
    initial begin : waves
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, tb_aes_teste);
        end
    end
endmodule

`default_nettype wire
