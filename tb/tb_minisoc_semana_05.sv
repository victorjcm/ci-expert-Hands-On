`timescale 1ns/1ps
`default_nettype none

module tb_minisoc_semana_05;
    localparam logic [31:0] FRONTEND_VERSION = 32'h0001_0000;
    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic spi_sclk = 1'b0, spi_cs_n = 1'b1, spi_mosi = 1'b0;
    wire spi_miso;
    wire [127:0] key_cfg, iv_cfg;
    wire [63:0] counter_cfg;
    wire [31:0] num_blocks;
    wire [2:0] mode_cfg;
    wire decrypt_cfg, start, mem_sel, pll_enable, locked, sys_clk;
    wire [1:0] pll_div_sel;
    logic aes_busy = 1'b0, aes_done = 1'b0, aes_error = 1'b0;
    logic [8:0] blocks_done = 9'd0;
    logic [2:0] expected_start_mode = 3'd0;
    logic expected_start_decrypt = 1'b0, previous_start = 1'b0;
    logic [31:0] expected_words [0:9];
    int unsigned checks = 0, start_events = 0, lock_events = 0;
    realtime spi_half = 20.0;
    realtime enable_time = 0.0, monitor_period = 0.5;
    realtime last_rise = -1.0;

    // Referência de 2 GHz; SPI começa em outra fase.
    always #0.25 clk = ~clk;

    minisoc_spi #(.VERSION(FRONTEND_VERSION)) u_spi (
        .clk(clk), .rst_n(rst_n), .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .o_key(key_cfg), .o_iv(iv_cfg), .o_counter(counter_cfg),
        .o_num_blocks(num_blocks), .o_mode(mode_cfg), .o_decrypt(decrypt_cfg),
        .o_start(start), .i_aes_busy(aes_busy), .i_aes_done(aes_done),
        .i_aes_error(aes_error), .i_blocks_done(blocks_done),
        .o_mem_sel_aes(mem_sel), .o_pll_enable(pll_enable),
        .o_pll_div_sel(pll_div_sel), .i_pll_locked(locked)
    );

    minisoc_pll_mock u_pll (
        .clk(clk), .rst_n(rst_n), .i_enable(pll_enable),
        .i_div_sel(pll_div_sel), .o_sys_clk(sys_clk), .o_locked(locked)
    );

    function automatic realtime period_for(input logic [1:0] selection);
        case (selection)
            2'd0: period_for = 0.5;
            2'd1: period_for = 1.0;
            2'd2: period_for = 2.0;
            2'd3: period_for = 4.0;
            default: period_for = 0.0;
        endcase
    endfunction

    task automatic check_word(
        input string label_text, input logic [31:0] actual, input logic [31:0] expected
    );
        if (actual !== expected)
            $fatal(1, "%s: esperado=%08h obtido=%08h", label_text, expected, actual);
        checks++;
    endtask

    task automatic check_time(
        input string label_text, input realtime actual, input realtime expected
    );
        if ((actual < expected - 0.002) || (actual > expected + 0.002))
            $fatal(1, "%s: esperado=%0.3f ns obtido=%0.3f ns", label_text, expected, actual);
        checks++;
    endtask

    // Deixa CS baixo ao sair para permitir abortos e clocks excedentes dirigidos.
    task automatic shift_bits(
        input logic [39:0] frame, input int count, output logic [39:0] received
    );
        received = 40'd0;
        spi_cs_n = 1'b0;
        for (int bit_index = 39; bit_index >= 40-count; bit_index--) begin
            spi_mosi = frame[bit_index];
            #(spi_half) spi_sclk = 1'b1;
            // MISO já foi lançado na descida anterior; 1 ps evita corridas do TB.
            #0.001 received = {received[38:0], spi_miso};
            #(spi_half - 0.001) spi_sclk = 1'b0;
        end
    endtask

    task automatic end_transfer;
        // Mantém a última descida separada da subida de CS na simulação.
        #0.001 spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #(spi_half);
    endtask

    task automatic transfer(input logic [39:0] frame, output logic [39:0] received);
        shift_bits(frame, 40, received);
        end_transfer();
    endtask

    task automatic write_reg(input logic [5:0] address, input logic [31:0] data);
        logic [39:0] received;
        transfer({1'b0, address, 1'b0, data}, received);
        if (received !== 40'd0)
            $fatal(1, "MISO inesperado durante escrita em %02h: %010h", address, received);
        checks++;
    endtask

    task automatic read_reg(input logic [5:0] address, output logic [31:0] data);
        logic [39:0] received;
        transfer({1'b1, address, 1'b0, 32'd0}, received);
        if (received !== 40'd0)
            $fatal(1, "Resposta antecipada durante READ request");
        transfer(40'hfe00000000, received);
        if (received[39:32] !== 8'd0)
            $fatal(1, "Cabecalho MISO diferente de zero");
        data = received[31:0];
        checks++;
    endtask

    task automatic expect_reg(input logic [5:0] address, input logic [31:0] expected);
        logic [31:0] actual;
        read_reg(address, actual);
        check_word($sformatf("registro %02h", address), actual, expected);
    endtask

    task automatic apply_reset;
        // Produz uma borda de reset real mesmo antes do primeiro clock serial.
        #0.01 rst_n = 1'b0;
        spi_cs_n = 1'b1;
        spi_sclk = 1'b0;
        spi_mosi = 1'b0;
        aes_busy = 1'b0;
        aes_done = 1'b0;
        aes_error = 1'b0;
        blocks_done = 9'd0;
        repeat (4) @(negedge clk);
        #0.05 rst_n = 1'b1;
        #2.1;
        check_word("reset START", {31'd0, start}, 32'd0);
        check_word("reset PLL", {30'd0, locked, sys_clk}, 32'd0);
    endtask

    // Confere duração de START e associação com os campos da mesma escrita.
    always @(posedge clk) begin
        #0.001;
        if (!rst_n) begin
            previous_start = 1'b0;
        end else begin
            if (start) begin
                if (previous_start)
                    $fatal(1, "START durou mais de um ciclo de clk");
                if ({mode_cfg, decrypt_cfg} !== {expected_start_mode, expected_start_decrypt})
                    $fatal(1, "START utilizou configuracao incorreta");
                start_events++;
            end
            previous_start = start;
        end
    end

    always @(posedge pll_enable) begin
        enable_time = $realtime;
        monitor_period = period_for(pll_div_sel);
    end

    always @(posedge locked) begin
        #0.001;
        if (rst_n) begin
            // Inclui aceitação do enable e alinhamento à descida do divisor.
            if (($realtime-enable_time < 4.0) || ($realtime-enable_time > 24.1))
                $fatal(1, "Aquisicao fora da faixa: %0.3f ns", $realtime-enable_time);
            $display("PLL divisor=%0d lock apos %0.3f ns", 1 << pll_div_sel,
                     $realtime-enable_time);
            lock_events++;
        end
    end

    // Examina também o primeiro e o último pulso alto de cada habilitação.
    always @(posedge sys_clk) begin
        last_rise = $realtime;
        #0.001;
        if (rst_n && (locked !== 1'b1))
            $fatal(1, "Clock de sistema ativo sem lock");
    end

    always @(negedge sys_clk) begin
        if (rst_n && (last_rise >= 0.0))
            check_time("largura alta do clock", $realtime-last_rise, monitor_period/2.0);
    end

    always @(negedge pll_enable) begin
        if (rst_n) begin
            // O fechamento do gate aguarda no máximo um período de /8.
            #4.1;
            if (rst_n)
                check_word("disable bloqueia PLL", {30'd0, locked, sys_clk}, 32'd0);
        end
    end

    task automatic measure_clock(input realtime period_ns);
        realtime beginning, falling;
        repeat (6) begin
            @(posedge sys_clk) beginning = $realtime;
            @(negedge sys_clk) falling = $realtime;
            check_time("meio periodo alto", falling-beginning, period_ns/2.0);
            @(posedge sys_clk);
            check_time("periodo do PLL", $realtime-beginning, period_ns);
            check_time("meio periodo baixo", $realtime-falling, period_ns/2.0);
        end
    endtask

    task automatic wait_lock_spi;
        logic [31:0] status;
        bit found;
        found = 1'b0;
        for (int attempt = 0; attempt < 8; attempt++) begin
            read_reg(6'h0f, status);
            if (status === 32'd1) begin
                found = 1'b1;
                break;
            end
        end
        if (!found)
            $fatal(1, "Timeout de PLL_LOCKED via SPI");
        checks++;
    endtask

    initial begin : directed_tests
        logic [39:0] received;
        logic [31:0] control_value;
        int unsigned starts_before;

        apply_reset();
        // Todos os endereços, inclusive status e VERSION, com PLL desligado.
        for (int address = 0; address < 16; address++)
            expect_reg(6'(address), (address == 13) ? FRONTEND_VERSION : 32'd0);

        // Padrões independentes do DUT; testa armazenamento e alias de endereço.
        for (int pattern = 0; pattern < 3; pattern++) begin
            for (int address = 0; address < 10; address++) begin
                case (pattern)
                    0: expected_words[address] = 32'd0;
                    1: expected_words[address] = 32'hffffffff;
                    default: expected_words[address] = 32'ha5c30001 ^ (32'h01020408 * 32'(address));
                endcase
                write_reg(6'(address), expected_words[address]);
            end
            for (int address = 0; address < 10; address++)
                expect_reg(6'(address), expected_words[address]);
        end
        if (key_cfg !== {expected_words[0], expected_words[1], expected_words[2], expected_words[3]})
            $fatal(1, "Ordem incorreta das palavras de KEY");
        if (iv_cfg !== {expected_words[4], expected_words[5], expected_words[6], expected_words[7]})
            $fatal(1, "Ordem incorreta das palavras de IV");
        if (counter_cfg !== {expected_words[8], expected_words[9]})
            $fatal(1, "Ordem incorreta de COUNTER_HI/LO");
        checks += 3;

        write_reg(6'h0a, 32'd1);
        expect_reg(6'h0a, 32'd1);
        write_reg(6'h0a, 32'd256);
        expect_reg(6'h0a, 32'd256);
        check_word("NUM_BLOCKS na interface", num_blocks, 32'd256);

        for (int mode_index = 0; mode_index < 6; mode_index++) begin
            for (int direction = 0; direction < 2; direction++) begin
                control_value = (32'(mode_index) << 2) | (32'(direction) << 1);
                write_reg(6'h0b, control_value);
                expect_reg(6'h0b, control_value);
            end
        end
        check_word("START=0 nao dispara", start_events, 32'd0);
        // Muda MODE/DECRYPT junto com o primeiro START, a partir de ECB/cifra.
        write_reg(6'h0b, 32'd0);
        expected_start_mode = 3'd5;
        expected_start_decrypt = 1'b1;
        write_reg(6'h0b, 32'h00000017);
        write_reg(6'h0b, 32'h00000017);
        expect_reg(6'h0b, 32'h00000016);
        check_word("dois comandos START", start_events, 32'd2);
        write_reg(6'h0b, 32'hffffffe0);
        expect_reg(6'h0b, 32'd0);

        // Somente o testbench fornece status AES nesta etapa, sem engine integrado.
        @(negedge clk);
        aes_busy = 1'b1;
        aes_error = 1'b1;
        blocks_done = 9'd256;
        write_reg(6'h0c, 32'hffffffff);
        expect_reg(6'h0c, 32'h00000805);
        write_reg(6'h0d, 32'hffffffff);
        expect_reg(6'h0d, FRONTEND_VERSION);
        write_reg(6'h0f, 32'hffffffff);
        expect_reg(6'h0f, 32'd0);

        // A resposta deve preservar o instante do READ request.
        transfer(40'h9800000000, received);
        aes_busy = 1'b0;
        aes_error = 1'b0;
        aes_done = 1'b1;
        blocks_done = 9'd0;
        transfer(40'h7e00000000, received); // NOP também com RWb=0.
        check_word("snapshot de AES_STATUS", received[31:0], 32'h00000805);
        expect_reg(6'h0c, 32'd2);
        // CS alto não apaga o snapshot ao abortar NOP antes do fim do cabeçalho.
        transfer(40'h9800000000, received);
        shift_bits(40'hfe00000000, 5, received);
        end_transfer();
        transfer(40'hfe00000000, received);
        check_word("resposta preservada apos NOP parcial", received[31:0], 32'd2);
        transfer(40'hfe00000000, received);
        if (received !== 40'd0)
            $fatal(1, "NOP sem resposta deve retornar zero");
        checks++;

        write_reg(6'h20, 32'hffffffff);
        expect_reg(6'h20, 32'd0);
        transfer({1'b0, 6'h00, 1'b1, 32'hdeadbeef}, received);
        expect_reg(6'h00, expected_words[0]);
        shift_bits(40'h00deadbeef, 17, received);
        end_transfer();
        expect_reg(6'h00, expected_words[0]);

        // Bit menos significativo, bit mais significativo e SCLK mais lento.
        write_reg(6'h00, 32'h80000001);
        #100;
        check_word("frame consumido com SCLK parado", key_cfg[127:96], 32'h80000001);
        expect_reg(6'h00, 32'h80000001);
        spi_half = 50.0;
        write_reg(6'h03, 32'h5555aaaa);
        expect_reg(6'h03, 32'h5555aaaa);
        spi_half = 20.0;

        // Um único frame por CS; clocks excedentes não repetem START.
        starts_before = start_events;
        expected_start_mode = 3'd0;
        expected_start_decrypt = 1'b0;
        shift_bits(40'h1600000001, 40, received);
        repeat (4) begin
            #(spi_half) spi_sclk = 1'b1;
            #(spi_half) spi_sclk = 1'b0;
        end
        end_transfer();
        check_word("START unico em frame longo", start_events, starts_before + 1);
        expect_reg(6'h0b, 32'd0);

        // Reset com resposta pendente e frame parcial, seguido de nova comunicação.
        transfer(40'h8000000000, received);
        shift_bits(40'h0201020304, 5, received);
        apply_reset();
        transfer(40'hfe00000000, received);
        if (received !== 40'd0)
            $fatal(1, "Resposta anterior reapareceu apos reset");
        for (int address = 0; address < 16; address++)
            expect_reg(6'(address), (address == 13) ? FRONTEND_VERSION : 32'd0);
        write_reg(6'h01, 32'h11223344);
        expect_reg(6'h01, 32'h11223344);

        for (int division = 0; division < 4; division++) begin
            control_value = 32'(division) << 2;
            write_reg(6'h0e, control_value);
            expect_reg(6'h0e, control_value);
            expect_reg(6'h0f, 32'd0);
            write_reg(6'h0e, control_value | 32'd2);
            wait_lock_spi();
            expect_reg(6'h0e, control_value | 32'd2);
            measure_clock(period_for(2'(division)));

            // R não pode retirar lock; MEM_SEL_AES é apenas configuração aqui.
            write_reg(6'h0f, 32'd0);
            expect_reg(6'h0f, 32'd1);
            write_reg(6'h0e, control_value | 32'd3);
            expect_reg(6'h0e, control_value | 32'd3);
            check_word("MEM_SEL_AES", {31'd0, mem_sel}, 32'd1);
            if (division == 3) begin
                // Política do mock: divisor ativo permanece até novo enable.
                write_reg(6'h0e, 32'd2);
                expect_reg(6'h0e, 32'd2);
                measure_clock(4.0);
            end
            write_reg(6'h0e, control_value);
            expect_reg(6'h0f, 32'd0);
            check_word("clock parado", {31'd0, sys_clk}, 32'd0);
        end
        check_word("quatro aquisicoes", lock_events, 32'd4);
        write_reg(6'h0e, 32'hfffffff0);
        expect_reg(6'h0e, 32'd0);

        // Nova habilitação após quatro sessões e reset enquanto o PLL está ativo.
        write_reg(6'h0e, 32'd2);
        wait_lock_spi();
        measure_clock(0.5);
        check_word("reabilitacao", lock_events, 32'd5);
        apply_reset();
        expect_reg(6'h0e, 32'd0);
        expect_reg(6'h0f, 32'd0);
        expect_reg(6'h0d, FRONTEND_VERSION);
        $display("SEMANA_05_PASS checks=%0d starts=%0d locks=%0d", checks, start_events, lock_events);
        $finish;
    end

    initial begin : waveform
        if ($test$plusargs("waves")) begin
            $dumpfile("semana_05.vcd");
            $dumpvars(0, tb_minisoc_semana_05);
        end
    end

    initial begin : watchdog
        #2000000 $fatal(1, "Timeout global da semana 5");
    end
endmodule

`default_nettype wire
