`timescale 1ns/1ps
`default_nettype none

module tb_minisoc_aes_semana_04;
    // Referências fixas da FIPS-197 (2001). Nenhum modelo AES calcula o esperado.
    localparam logic [127:0] C_PLAINTEXT  = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] C_CIPHERTEXT = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    localparam logic [127:0] B_PLAINTEXT  = 128'h3243f6a8885a308d313198a2e0370734;
    localparam logic [127:0] B_CIPHERTEXT = 128'h3925841d02dc09fbdc118597196a0b32;

    // Apêndice C.1, K0..K10.
    localparam logic [127:0] C_ROUND_KEYS [0:10] = '{
        128'h000102030405060708090a0b0c0d0e0f,
        128'hd6aa74fdd2af72fadaa678f1d6ab76fe,
        128'hb692cf0b643dbdf1be9bc5006830b3fe,
        128'hb6ff744ed2c2c9bf6c590cbf0469bf41,
        128'h47f7f7bc95353e03f96c32bcfd058dfd,
        128'h3caaa3e8a99f9deb50f3af57adf622aa,
        128'h5e390f7df7a69296a7553dc10aa31f6b,
        128'h14f9701ae35fe28c440adf4d4ea9c026,
        128'h47438735a41c65b9e016baf4aebf7ad2,
        128'h549932d1f08557681093ed9cbe2c974e,
        128'h13111d7fe3944a17f307a78b4d2b30c5
    };
    // Apêndice A.1: expansão da chave utilizada pelo Apêndice B.
    localparam logic [127:0] B_ROUND_KEYS [0:10] = '{
        128'h2b7e151628aed2a6abf7158809cf4f3c,
        128'ha0fafe1788542cb123a339392a6c7605,
        128'hf2c295f27a96b9435935807a7359f67f,
        128'h3d80477d4716fe3e1e237e446d7a883b,
        128'hef44a541a8525b7fb671253bdb0bad00,
        128'hd4d1c6f87c839d87caf2b8bc11f915bc,
        128'h6d88a37a110b3efddbf98641ca0093fd,
        128'h4e54f70e5f5fc9f384a64fb24ea6dc4f,
        128'head27321b58dbad2312bf5607f8d292f,
        128'hac7766f319fadc2128d12941575c006e,
        128'hd014f9a8c9ee2589e13f0cc8b6630ca6
    };

    logic clk = 1'b0;
    logic rst_n, key_start, dp_start, decrypt_primitive;
    logic [127:0] key_in, block_in;
    logic inspect_keys;
    logic [3:0] inspect_index;
    wire [3:0] key_index, dp_index;
    wire [127:0] round_key, result;
    wire key_busy, key_done, keys_ready, dp_busy, dp_done;
    int unsigned checks = 0;
    int unsigned expansions_completed = 0;
    int unsigned blocks_completed = 0;

    // O mux pertence apenas ao testbench, para inspecionar o banco ocioso.
    assign key_index = inspect_keys ? inspect_index : dp_index;
    always #5 clk = ~clk;

    minisoc_aes_key_exp u_key_exp (
        .clk(clk), .rst_n(rst_n), .i_start(key_start), .i_key(key_in),
        .i_round_index(key_index), .o_busy(key_busy), .o_done(key_done),
        .o_keys_ready(keys_ready), .o_round_key(round_key)
    );
    minisoc_aes_dp u_dp (
        .clk(clk), .rst_n(rst_n), .i_start(dp_start), .i_block(block_in),
        .i_decrypt_primitive(decrypt_primitive), .i_keys_ready(keys_ready),
        .i_round_key(round_key), .o_busy(dp_busy), .o_done(dp_done),
        .o_result(result), .o_round_index(dp_index)
    );

    function automatic logic [127:0] expected_key(input bit vector_b, input int index);
        expected_key = vector_b ? B_ROUND_KEYS[index] : C_ROUND_KEYS[index];
    endfunction

    task automatic check_bit(input string label_text, input logic actual, input logic expected);
        if (actual !== expected)
            $fatal(1, "FAIL %s: esperado=%b obtido=%b", label_text, expected, actual);
        checks++;
    endtask

    task automatic check_state(
        input string label_text, input logic [127:0] actual, input logic [127:0] expected
    );
        if (actual !== expected)
            $fatal(1, "FAIL %s: esperado=%032h obtido=%032h", label_text, expected, actual);
        checks++;
    endtask

    task automatic check_index(input logic [3:0] expected);
        if (dp_index !== expected)
            $fatal(1, "FAIL indice: esperado=%0d obtido=%0d", expected, dp_index);
        checks++;
    endtask

    task automatic check_reset_outputs;
        check_bit("reset key busy", key_busy, 1'b0);
        check_bit("reset key done", key_done, 1'b0);
        check_bit("reset keys ready", keys_ready, 1'b0);
        check_bit("reset dp busy", dp_busy, 1'b0);
        check_bit("reset dp done", dp_done, 1'b0);
        check_state("reset resultado", result, 128'h0);
        check_state("reset leitura de chave", round_key, 128'h0);
    endtask

    task automatic apply_reset;
        // Assertar na descida permite observar o reset antes da próxima subida.
        @(negedge clk) begin
            rst_n = 1'b0;
            key_start = 1'b0;
            dp_start = 1'b0;
            #1 check_reset_outputs();
        end
        repeat (2) @(posedge clk) begin
            #1 check_reset_outputs();
        end
        @(negedge clk) rst_n = 1'b1;
        @(posedge clk) begin
            #1 check_reset_outputs();
        end
    endtask

    task automatic reject_without_keys;
        for (int direction = 0; direction < 2; direction++) begin
            @(negedge clk) begin
                dp_start = 1'b1;
                block_in = C_PLAINTEXT;
                decrypt_primitive = (direction == 1);
            end
            @(posedge clk) begin
                #1 check_bit("start sem chave: busy", dp_busy, 1'b0);
                check_bit("start sem chave: done", dp_done, 1'b0);
                check_bit("start sem chave: ready", keys_ready, 1'b0);
                check_state("start sem chave: resultado", result, 128'h0);
            end
            @(negedge clk) dp_start = 1'b0;
            @(posedge clk) begin
                #1 check_bit("start sem chave nao enfileirado", dp_busy, 1'b0);
            end
        end
    endtask

    task automatic expand_key(input bit vector_b);
        @(negedge clk) begin
            inspect_keys = 1'b1;
            inspect_index = 4'd0;
            key_in = expected_key(vector_b, 0);
            key_start = 1'b1;
        end
        @(posedge clk) begin
            #1 check_bit("expansao E0 busy", key_busy, 1'b1);
            check_bit("expansao E0 done", key_done, 1'b0);
            check_bit("expansao E0 invalida banco", keys_ready, 1'b0);
            check_state("expansao E0 leitura bloqueada", round_key, 128'h0);
        end
        for (int cycle = 1; cycle <= 10; cycle++) begin
            @(negedge clk) begin
                // A chave externa muda; pulsos em E3/E10 não podem reiniciar a expansão.
                key_in = ~expected_key(vector_b, 0);
                key_start = (cycle == 3 || cycle == 10);
                // Em E10, ready ainda era zero antes da borda; também deve rejeitar.
                dp_start = (cycle == 4 || cycle == 10);
            end
            @(posedge clk) begin
                #1 check_bit("expansao busy", key_busy, (cycle < 10));
                check_bit("expansao done", key_done, (cycle == 10));
                check_bit("expansao ready", keys_ready, (cycle == 10));
                check_bit("dp rejeita start durante expansao", dp_busy, 1'b0);
                check_bit("dp sem conclusao espuria", dp_done, 1'b0);
                if (cycle < 10)
                    check_state("banco parcial bloqueado", round_key, 128'h0);
            end
        end
        @(negedge clk) begin
            key_start = 1'b0;
            dp_start = 1'b0;
        end
        @(posedge clk) begin
            #1 check_bit("key done dura um ciclo", key_done, 1'b0);
            check_bit("key start ocupado nao enfileirado", key_busy, 1'b0);
            check_bit("ready persistente", keys_ready, 1'b1);
            check_bit("dp start rejeitado nao enfileirado", dp_busy, 1'b0);
        end
        expansions_completed++;
    endtask

    task automatic check_key_bank(input bit vector_b);
        for (int index = 0; index < 11; index++) begin
            @(negedge clk) begin
                inspect_index = 4'(index);
                #1 check_state($sformatf("FIPS %s K%0d", vector_b ? "A.1/B" : "C.1", index),
                               round_key, expected_key(vector_b, index));
                check_bit("banco estavel ready", keys_ready, 1'b1);
                check_bit("banco estavel busy", key_busy, 1'b0);
                check_bit("banco estavel done", key_done, 1'b0);
            end
        end
        for (int index = 11; index < 16; index++) begin
            @(negedge clk) begin
                inspect_index = 4'(index);
                #1 check_state("indice de chave fora da faixa", round_key, 128'h0);
            end
        end
        @(negedge clk) inspect_keys = 1'b0;
    endtask

    task automatic run_block(input bit vector_b, input bit decrypt);
        logic [127:0] input_value, expected_value;
        logic [3:0] expected_index;
        input_value = decrypt ? (vector_b ? B_CIPHERTEXT : C_CIPHERTEXT)
                              : (vector_b ? B_PLAINTEXT : C_PLAINTEXT);
        expected_value = decrypt ? (vector_b ? B_PLAINTEXT : C_PLAINTEXT)
                                 : (vector_b ? B_CIPHERTEXT : C_CIPHERTEXT);
        @(negedge clk) begin
            inspect_keys = 1'b0;
            dp_start = 1'b1;
            block_in = input_value;
            decrypt_primitive = decrypt;
            expected_index = decrypt ? 4'd10 : 4'd0;
            #1 check_index(expected_index);
            check_state("chave inicial", round_key, expected_key(vector_b, int'(expected_index)));
        end
        @(posedge clk) begin
            #1 check_bit("dp E0 busy", dp_busy, 1'b1);
            check_bit("dp E0 done", dp_done, 1'b0);
            check_state("start aceito limpa resultado", result, 128'h0);
        end
        for (int cycle = 1; cycle <= 10; cycle++) begin
            @(negedge clk) begin
                // Mudar entradas e pedir novos starts não pode alterar o snapshot.
                block_in = ~input_value;
                decrypt_primitive = !decrypt;
                dp_start = (cycle == 3 || cycle == 10);
                expected_index = decrypt ? 4'(10 - cycle) : 4'(cycle);
                #1 check_index(expected_index);
                check_state("chave selecionada na rodada", round_key,
                            expected_key(vector_b, int'(expected_index)));
            end
            @(posedge clk) begin
                #1 check_bit("dp busy", dp_busy, (cycle < 10));
                check_bit("dp done", dp_done, (cycle == 10));
                check_bit("chaves continuam prontas", keys_ready, 1'b1);
                check_bit("sem nova expansao", key_busy, 1'b0);
                if (cycle == 10)
                    check_state($sformatf("FIPS %s %s", vector_b ? "B" : "C.1",
                                         decrypt ? "inversa" : "cifra"), result, expected_value);
                else
                    check_state("resultado nao publicado antes de done", result, 128'h0);
            end
        end
        $display("FIPS %s %s: entrada=%032h resultado=%032h esperado=%032h",
                 vector_b ? "B" : "C.1", decrypt ? "inversa" : "cifra",
                 input_value, result, expected_value);
        @(negedge clk) dp_start = 1'b0;
        repeat (3) @(posedge clk) begin
            #1 check_bit("dp done dura um ciclo", dp_done, 1'b0);
            check_bit("dp start ocupado nao enfileirado", dp_busy, 1'b0);
            check_state("resultado mantido em IDLE", result, expected_value);
        end
        blocks_completed++;
    endtask

    task automatic abort_key_expansion;
        @(negedge clk) begin
            key_in = C_ROUND_KEYS[0];
            key_start = 1'b1;
        end
        @(posedge clk) begin
            #1 check_bit("antes do aborto: key busy", key_busy, 1'b1);
            check_bit("antes do aborto: ready", keys_ready, 1'b0);
        end
        @(negedge clk) key_start = 1'b0;
        repeat (3) @(posedge clk) begin
            #1 check_bit("expansao em curso antes do reset", key_busy, 1'b1);
            check_bit("expansao ainda sem done", key_done, 1'b0);
        end
        apply_reset();
        // Esperar além da conclusão antiga verifica que o reset abortou o pedido.
        repeat (12) @(posedge clk) begin
            #1 check_reset_outputs();
        end
    endtask

    task automatic abort_datapath;
        @(negedge clk) begin
            dp_start = 1'b1;
            block_in = C_CIPHERTEXT;
            decrypt_primitive = 1'b1;
        end
        @(posedge clk) begin
            #1 check_bit("antes do aborto: dp busy", dp_busy, 1'b1);
        end
        @(negedge clk) dp_start = 1'b0;
        repeat (3) @(posedge clk) begin
            #1 check_bit("datapath em curso antes do reset", dp_busy, 1'b1);
            check_bit("datapath ainda sem done", dp_done, 1'b0);
        end
        apply_reset();
        repeat (12) @(posedge clk) begin
            #1 check_reset_outputs();
        end
    endtask

    initial begin : stimulus
        rst_n = 1'b1;
        key_start = 1'b0;
        dp_start = 1'b0;
        decrypt_primitive = 1'b0;
        key_in = 128'h0;
        block_in = 128'h0;
        inspect_keys = 1'b0;
        inspect_index = 4'd0;

        apply_reset();
        reject_without_keys();

        expand_key(1'b0);
        check_key_bank(1'b0);
        run_block(1'b0, 1'b0);
        run_block(1'b0, 1'b1);

        // Trocar a chave sem reset; decriptar primeiro também exige K10 correta.
        expand_key(1'b1);
        check_key_bank(1'b1);
        run_block(1'b1, 1'b1);
        run_block(1'b1, 1'b0);

        abort_key_expansion();
        reject_without_keys();
        expand_key(1'b0);
        check_key_bank(1'b0);
        abort_datapath();
        reject_without_keys();

        // Recuperação após o reset do datapath: nova expansão e os dois sentidos.
        expand_key(1'b0);
        check_key_bank(1'b0);
        run_block(1'b0, 1'b0);
        run_block(1'b0, 1'b1);

        if (expansions_completed != 4 || blocks_completed != 6)
            $fatal(1, "FAIL fluxo incompleto: expansoes=%0d blocos=%0d",
                   expansions_completed, blocks_completed);
        $display("SEMANA_04_PASS checks=%0d expansoes=%0d blocos=%0d",
                 checks, expansions_completed, blocks_completed);
        $finish;
    end

    initial begin : watchdog
        #100000 $fatal(1, "FAIL timeout do testbench da semana 4");
    end
endmodule

`default_nettype wire
