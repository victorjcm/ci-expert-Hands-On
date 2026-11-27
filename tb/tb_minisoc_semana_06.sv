`timescale 1ns/1ps
`default_nettype none

module tb_minisoc_semana_06;
    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic start = 1'b0;
    logic [127:0] key_cfg = 128'd0, iv_cfg = 128'd0;
    logic [63:0] counter_cfg = 64'd0;
    logic [2:0] mode_cfg = 3'd0;
    logic decrypt_cfg = 1'b0;
    logic [31:0] num_blocks_cfg = 32'd0;
    logic mem_sel_request = 1'b0;
    wire mem_owned;
    wire busy, done, error;
    wire [8:0] blocks_done;
    wire [9:0] aes_addr;
    wire [31:0] aes_write_data, aes_read_data;
    wire aes_wr_en;
    logic mem_clk = 1'b0;
    logic [9:0] mem_addr = 10'd0;
    logic [31:0] mem_write_data = 32'd0;
    logic mem_wr_en = 1'b0;
    wire [31:0] mem_read_data;

    logic [127:0] inputs [0:255];
    logic [127:0] expected [0:255];
    logic [127:0] case_key, case_iv;
    logic [63:0] case_counter;
    int case_id, case_mode, case_decrypt, case_blocks;
    int unsigned checks = 0, completed_cases = 0, rejected_cases = 0;
    int unsigned write_count = 0, key_starts = 0, dp_starts = 0;
    logic [8:0] previous_blocks_done = 9'd0;
    bit monitor_active = 1'b0;
    string vectors_path = "tb/vectors/semana_06/vectors.txt";

    // Clock local de bloco; esta semana não integra SPI/PLL/CDC.
    always #2 clk = ~clk;

    minisoc_aes_top u_engine (
        .clk(clk), .rst_n(rst_n), .i_start(start), .i_key(key_cfg),
        .i_iv(iv_cfg), .i_counter(counter_cfg), .i_mode(mode_cfg),
        .i_decrypt(decrypt_cfg), .i_num_blocks(num_blocks_cfg),
        .i_mem_owned(mem_owned), .o_busy(busy), .o_done(done), .o_error(error),
        .o_blocks_done(blocks_done), .o_mem_addr(aes_addr),
        .o_mem_data(aes_write_data), .o_mem_wr_en(aes_wr_en), .i_mem_data(aes_read_data)
    );
    minisoc_memory u_memory (
        .i_mem_sel_aes(mem_sel_request), .i_aes_busy(busy), .o_mem_sel_aes(mem_owned),
        .mem_clk(mem_clk), .mem_i_data(mem_write_data), .mem_i_wr_en(mem_wr_en),
        .mem_i_addr(mem_addr), .mem_o_data(mem_read_data), .aes_clk(clk),
        .aes_i_data(aes_write_data), .aes_i_wr_en(aes_wr_en), .aes_i_addr(aes_addr),
        .aes_o_data(aes_read_data)
    );

    task automatic check(input logic condition, input string label_text);
        if (condition !== 1'b1)
            $fatal(1, "%s (caso=%0d)", label_text, case_id);
        checks++;
    endtask

    task automatic check_word(input string label_text,
                              input logic [31:0] actual, input logic [31:0] wanted);
        if (actual !== wanted)
            $fatal(1, "%s: esperado=%08h obtido=%08h (caso=%0d)",
                   label_text, wanted, actual, case_id);
        checks++;
    endtask

    function automatic logic [31:0] guard_word(input int address);
        guard_word = 32'ha53c0000 ^ (32'h01020409 * 32'(address));
    endfunction

    task automatic external_write(input int address, input logic [31:0] value);
        check(mem_owned === 1'b0, "Escrita externa sem ownership");
        mem_addr = 10'(address);
        mem_write_data = value;
        mem_wr_en = 1'b1;
        #5 mem_clk = 1'b1;
        #5 mem_clk = 1'b0;
        mem_wr_en = 1'b0;
    endtask

    task automatic external_read(input int address, output logic [31:0] value);
        check(mem_owned === 1'b0, "Leitura externa sem ownership");
        mem_addr = 10'(address);
        mem_wr_en = 1'b0;
        #5 mem_clk = 1'b1;
        #0.001 value = mem_read_data;
        #4.999 mem_clk = 1'b0;
    endtask

    task automatic select_owner(input bit aes_owner);
        bit found;
        check(!busy && !mem_clk && !mem_wr_en, "Troca fora da janela ociosa");
        // A solicitação pode chegar com clk alto; o latch aguarda a fase baixa.
        @(posedge clk);
        #0.1 mem_sel_request = aes_owner;
        #0.1;
        check(mem_owned !== aes_owner, "Owner mudou durante fase alta");
        found = 1'b0;
        for (int attempt = 0; attempt < 8; attempt++) begin
            @(negedge clk);
            #0.001;
            if (mem_owned === aes_owner) begin
                found = 1'b1;
                break;
            end
        end
        check(found, "Timeout de ownership efetivo");
    endtask

    task automatic apply_reset;
        #0.1 rst_n = 1'b0;
        start = 1'b0;
        repeat (3) @(negedge clk);
        check({busy, done, error, blocks_done} === 12'd0, "Status no reset");
        check(aes_wr_en === 1'b0, "Write-enable ativo no reset");
        #0.1 rst_n = 1'b1;
        @(negedge clk);
    endtask

    task automatic load_case_memory;
        for (int address = 0; address < 1024; address++) begin
            if (address < 4 * case_blocks)
                external_write(address, inputs[address / 4][127 - 32*(address % 4) -: 32]);
            else
                external_write(address, guard_word(address));
        end
    endtask

    task automatic check_case_memory;
        logic [31:0] value, wanted;
        for (int address = 0; address < 1024; address++) begin
            external_read(address, value);
            wanted = (address < 4 * case_blocks)
                   ? expected[address / 4][127 - 32*(address % 4) -: 32] : guard_word(address);
            check_word($sformatf("readback palavra %0d", address), value, wanted);
        end
    endtask

    task automatic configure_case;
        key_cfg = case_key;
        iv_cfg = case_iv;
        counter_cfg = case_counter;
        mode_cfg = 3'(case_mode);
        decrypt_cfg = 1'(case_decrypt);
        num_blocks_cfg = 32'(case_blocks);
    endtask

    task automatic start_case;
        @(negedge clk);
        configure_case();
        write_count = 0;
        key_starts = 0;
        dp_starts = 0;
        previous_blocks_done = 9'd0;
        start = 1'b1;
        @(posedge clk);
        #0.001;
        check(busy && !done && !error && (blocks_done == 9'd0),
              "START valido nao limpou status/iniciou BUSY");
        monitor_active = 1'b1;
        @(negedge clk) start = 1'b0;
    endtask

    // Observa as escritas reais e os pulsos internos sem produzir o esperado.
    always @(posedge clk) begin
        if (monitor_active && rst_n) begin
            if (u_engine.key_start) key_starts++;
            if (u_engine.dp_start) dp_starts++;
            if (aes_wr_en) begin
                check(busy && mem_owned, "Escrita AES sem BUSY/ownership");
                check(write_count < 4 * case_blocks, "Escrita alem da regiao solicitada");
                check(aes_addr === 10'(write_count), "Endereco fora da ordem in-place");
                check_word("dado no porto AES", aes_write_data,
                           expected[write_count / 4][127 - 32*(write_count % 4) -: 32]);
                write_count++;
            end
            #0.001;
            if (rst_n) begin
                check(!error, "ERROR durante operacao valida");
                check((blocks_done == previous_blocks_done)
                      || (blocks_done == previous_blocks_done + 9'd1),
                      "BLOCKS_DONE saltou ou regrediu");
                check(int'(blocks_done) <= write_count / 4,
                      "Bloco contabilizado antes das quatro escritas");
                previous_blocks_done = blocks_done;
                if (done)
                    check(!busy && (write_count == 4 * case_blocks)
                          && (blocks_done == 9'(case_blocks)), "DONE prematuro");
                else
                    check(busy, "BUSY caiu antes de DONE");
            end
        end
    end

    task automatic disturb_live_configuration;
        // Todos os campos externos mudam; o snapshot deve continuar intacto.
        key_cfg = ~case_key;
        iv_cfg = ~case_iv;
        counter_cfg = ~case_counter;
        mode_cfg = 3'd7;
        decrypt_cfg = !case_decrypt;
        num_blocks_cfg = 32'hffffffff;
        // Separar os comandos por um ciclo em zero, ainda durante BUSY.
        @(negedge clk) start = 1'b1;
        @(negedge clk) start = 1'b0;
        // Uma solicitação de devolução durante BUSY não pode retirar o porto.
        mem_sel_request = 1'b0;
        repeat (2) @(negedge clk);
        #0.001;
        check(mem_owned && busy, "Owner retirado durante BUSY");
        // Pulsos do mestre não selecionado não podem escrever nem comandar read.
        mem_addr = 10'd1023;
        mem_write_data = 32'hbad00bad;
        mem_wr_en = 1'b1;
        #5 mem_clk = 1'b1;
        #5 mem_clk = 1'b0;
        mem_wr_en = 1'b0;
        mem_sel_request = 1'b1;
    endtask

    task automatic wait_completion;
        bit finished;
        finished = 1'b0;
        for (int cycle = 0; cycle < 100 + 40 * case_blocks; cycle++) begin
            @(negedge clk);
            if (done === 1'b1) begin
                finished = 1'b1;
                break;
            end
        end
        check(finished, "Timeout do engine");
        check(blocks_done === 9'(case_blocks), "Contagem final incorreta");
        check(write_count == 4 * case_blocks, "Quantidade incorreta de escritas");
        check(key_starts == 1, "Expansao deve ocorrer uma vez por operacao");
        check(dp_starts == case_blocks, "Quantidade incorreta de blocos no datapath");
        repeat (4) begin
            @(negedge clk);
            check(done && !busy && !error, "DONE nao permaneceu sticky");
        end
        monitor_active = 1'b0;
    endtask

    task automatic run_case;
        load_case_memory();
        select_owner(1'b1);
        start_case();
        disturb_live_configuration();
        wait_completion();
        select_owner(1'b0);
        check_case_memory();
        completed_cases++;
        $display("CASO_OK id=%0d mode=%0d decrypt=%0d blocks=%0d",
                 case_id, case_mode, case_decrypt, case_blocks);
    endtask

    task automatic reject_configuration(input logic [2:0] invalid_mode,
                                         input logic [31:0] invalid_count);
        logic saved_done;
        logic [8:0] saved_blocks;
        logic [31:0] value;
        // Preencher permite provar que não houve corrupção, mesmo após rejeição.
        for (int address = 0; address < 1024; address++)
            external_write(address, guard_word(address));
        select_owner(1'b1);
        saved_done = done;
        saved_blocks = blocks_done;
        @(negedge clk);
        mode_cfg = invalid_mode;
        num_blocks_cfg = invalid_count;
        start = 1'b1;
        @(posedge clk);
        #0.001;
        check(error && !busy && (done === saved_done) && (blocks_done === saved_blocks),
              "Rejeicao deve indicar ERROR e preservar conclusao anterior");
        @(negedge clk) start = 1'b0;
        repeat (20) begin
            @(negedge clk);
            check(error && !busy && !aes_wr_en && !u_engine.key_start && !u_engine.dp_start,
                  "Configuracao invalida iniciou processamento");
            check((done === saved_done) && (blocks_done === saved_blocks),
                  "Rejeicao alterou DONE/BLOCKS_DONE");
        end
        select_owner(1'b0);
        for (int address = 0; address < 1024; address++) begin
            external_read(address, value);
            check_word("memoria apos rejeicao", value, guard_word(address));
        end
        rejected_cases++;
    endtask

    task automatic reset_during_write;
        bit first_word;
        logic [31:0] value, wanted;
        load_case_memory();
        select_owner(1'b1);
        start_case();
        first_word = 1'b0;
        for (int cycle = 0; cycle < 100; cycle++) begin
            @(negedge clk);
            if (write_count == 1) begin
                first_word = 1'b1;
                break;
            end
        end
        check(first_word, "Timeout antes do reset durante escrita");
        monitor_active = 1'b0;
        apply_reset();
        check(write_count == 1, "Mais de uma escrita antes do aborto");
        select_owner(1'b0);
        // Reset não oferece rollback: somente o Word 0 já foi substituído.
        for (int address = 0; address < 1024; address++) begin
            external_read(address, value);
            if (address == 0)
                wanted = expected[0][127:96];
            else if (address < 4 * case_blocks)
                wanted = inputs[address / 4][127 - 32*(address % 4) -: 32];
            else
                wanted = guard_word(address);
            check_word("memoria preservada apos aborto", value, wanted);
        end
        repeat (4) @(negedge clk);
        check({busy, done, error, blocks_done} === 12'd0, "Operacao reapareceu apos reset");
    endtask

    initial begin : directed_tests
        integer file_handle, scan_count, total_cases;
        int wanted_mode, wanted_count;
        logic [31:0] value;
        string extra_token;

        if ($value$plusargs("vectors=%s", vectors_path)) begin end
        file_handle = $fopen(vectors_path, "r");
        if (file_handle == 0)
            $fatal(1, "Vetores ausentes: execute python3 scripts/gen_semana_06_vectors.py; arquivo=%s",
                   vectors_path);
        scan_count = $fscanf(file_handle, "%d", total_cases);
        check((scan_count == 1) && (total_cases == 22), "Arquivo precisa dos 22 casos previstos");
        apply_reset();
        check(mem_owned === 1'b0, "Ownership inicial nao definido");

        for (int address = 0; address < 1024; address++)
            external_write(address, guard_word(address));
        external_read(1023, value);
        check_word("ultimo endereco fisico", value, guard_word(1023));
        mem_addr = 10'd0;
        repeat (3) @(negedge clk);
        check_word("sem borda externa, read retido apesar de clock AES", mem_read_data, value);
        external_read(0, value);
        check_word("leitura sincrona do endereco zero", value, guard_word(0));
        apply_reset();
        external_read(1023, value);
        check_word("reset nao apaga memoria", value, guard_word(1023));

        // START sem ownership, ainda que a configuração seja válida, é ignorado.
        @(negedge clk);
        mode_cfg = 3'd0;
        num_blocks_cfg = 32'd1;
        start = 1'b1;
        @(negedge clk) start = 1'b0;
        repeat (4) @(negedge clk);
        check({busy, done, error, blocks_done} === 12'd0, "START aceito sem ownership");

        reject_configuration(3'd0, 32'd0);
        reject_configuration(3'd0, 32'd257);
        reject_configuration(3'd0, 32'd512);
        reject_configuration(3'd0, 32'h00010001);
        reject_configuration(3'd0, 32'hffffffff);
        for (int mode_index = 2; mode_index < 8; mode_index++) begin
            if (mode_index != 5)
                reject_configuration(3'(mode_index), 32'd1);
        end

        for (int vector_index = 0; vector_index < total_cases; vector_index++) begin
            scan_count = $fscanf(file_handle, "%d %d %d %d %h %h %h",
                                 case_id, case_mode, case_decrypt, case_blocks,
                                 case_key, case_iv, case_counter);
            check((scan_count == 7) && (case_id == vector_index), "Cabecalho de vetor invalido");
            if (vector_index < 18) begin
                case (vector_index / 6)
                    0: wanted_mode = 0;
                    1: wanted_mode = 1;
                    default: wanted_mode = 5;
                endcase
                case ((vector_index / 2) % 3)
                    0: wanted_count = 1;
                    1: wanted_count = 2;
                    default: wanted_count = 256;
                endcase
            end else begin
                wanted_mode = (vector_index < 20) ? 5 : 0;
                wanted_count = (vector_index < 20) ? 2 : 1;
            end
            check((case_mode == wanted_mode) && (case_blocks == wanted_count)
                  && (case_decrypt == vector_index % 2), "Matriz de cenarios incompleta");
            check((^{case_key, case_iv, case_counter}) !== 1'bx, "Configuracao contem X/Z");
            for (int block_number = 0; block_number < case_blocks; block_number++) begin
                scan_count = $fscanf(file_handle, "%h %h", inputs[block_number], expected[block_number]);
                check(scan_count == 2, "Par entrada/esperado ausente");
                check((^{inputs[block_number], expected[block_number]}) !== 1'bx,
                      "Vetor contem X/Z");
            end
            run_case();
        end
        scan_count = $fscanf(file_handle, "%s", extra_token);
        check(scan_count == -1, "Dados excedentes no arquivo de vetores");
        $fclose(file_handle);

        // DONE=1 e contagem anterior também precisam sobreviver a um START inválido.
        reject_configuration(3'd7, 32'd1);
        reject_configuration(3'd1, 32'd0);
        run_case(); // Um novo START válido limpa ERROR/DONE e reexpande a chave.
        reset_during_write();
        run_case(); // Recuperação funcional após o aborto, com nova carga externa.
        check(completed_cases == 24 && rejected_cases == 12, "Cobertura dirigida incompleta");
        $display("SEMANA_06_PASS checks=%0d operations=%0d rejected=%0d vectors=%0d",
                 checks, completed_cases, rejected_cases, total_cases);
        $finish;
    end

    initial begin : waveform
        if ($test$plusargs("waves")) begin
            $dumpfile("semana_06.vcd");
            $dumpvars(0, tb_minisoc_semana_06);
        end
    end

    initial begin : watchdog
        #5000000 $fatal(1, "Timeout global da semana 6");
    end
endmodule

`default_nettype wire
