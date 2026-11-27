`timescale 1ns/1ps
`default_nettype none

// Engine de bloco da semana 6. Comando e snapshot já pertencem a clk.
// O bridge SPI/PLL será conectado na integração; i_mem_owned é o owner efetivo.
module minisoc_aes_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         i_start,
    input  wire [127:0] i_key,
    input  wire [127:0] i_iv,
    input  wire [63:0]  i_counter,
    input  wire [2:0]   i_mode,
    input  wire         i_decrypt,
    input  wire [31:0]  i_num_blocks,
    input  wire         i_mem_owned,
    output logic        o_busy,
    output logic        o_done,
    output logic        o_error,
    output logic [8:0]  o_blocks_done,
    output wire [9:0]   o_mem_addr,
    output wire [31:0]  o_mem_data,
    output wire         o_mem_wr_en,
    input  wire [31:0]  i_mem_data
);
    localparam logic [2:0] MODE_ECB = 3'd0;
    localparam logic [2:0] MODE_CBC = 3'd1;
    localparam logic [2:0] MODE_CTR = 3'd5;

    typedef enum logic [3:0] {
        IDLE, KEY_START, KEY_WAIT, READ_REQ, READ_CAPTURE,
        PREPARE, AES_START, AES_WAIT, POSTPROCESS, WRITE_WORD, NEXT_BLOCK
    } state_t;
    state_t state_q;

    logic [127:0] key_q, iv_q, chain_q;
    logic [63:0] counter_q;
    logic [2:0] mode_q;
    logic decrypt_q;
    logic [8:0] num_blocks_q;
    logic [7:0] block_index_q;
    logic [1:0] word_index_q;
    logic [127:0] input_q, output_q, primitive_input_q;
    wire config_valid;
    wire key_start, key_busy, key_done, keys_ready;
    wire dp_start, dp_busy, dp_done, decrypt_primitive;
    wire [127:0] round_key, dp_result;
    wire [3:0] round_index;
    wire [8:0] next_done;

    // Validar os 32 bits antes de reduzir a quantidade a nove bits.
    // PCBC/CFB/OFB também são rejeitados nesta entrega parcial da v1.0.
    assign config_valid = (i_num_blocks >= 32'd1) && (i_num_blocks <= 32'd256)
                       && ((i_mode == MODE_ECB) || (i_mode == MODE_CBC)
                           || (i_mode == MODE_CTR));
    assign next_done = o_blocks_done + 9'd1;
    assign o_mem_addr = {block_index_q, word_index_q};
    assign o_mem_data = output_q[127 - 32*word_index_q -: 32];
    assign o_mem_wr_en = rst_n && i_mem_owned && (state_q == WRITE_WORD);
    assign key_start = rst_n && (state_q == KEY_START) && !key_busy;
    assign dp_start = rst_n && (state_q == AES_START) && !dp_busy && keys_ready;
    assign decrypt_primitive = decrypt_q && (mode_q != MODE_CTR);

    minisoc_aes_key_exp u_key_exp (
        .clk(clk), .rst_n(rst_n), .i_start(key_start), .i_key(key_q),
        .i_round_index(round_index), .o_busy(key_busy), .o_done(key_done),
        .o_keys_ready(keys_ready), .o_round_key(round_key)
    );
    minisoc_aes_dp u_dp (
        .clk(clk), .rst_n(rst_n), .i_start(dp_start), .i_block(primitive_input_q),
        .i_decrypt_primitive(decrypt_primitive), .i_keys_ready(keys_ready),
        .i_round_key(round_key), .o_busy(dp_busy), .o_done(dp_done),
        .o_result(dp_result), .o_round_index(round_index)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q           <= IDLE;
            key_q             <= 128'd0;
            iv_q              <= 128'd0;
            chain_q           <= 128'd0;
            counter_q         <= 64'd0;
            mode_q            <= MODE_ECB;
            decrypt_q         <= 1'b0;
            num_blocks_q      <= 9'd0;
            block_index_q     <= 8'd0;
            word_index_q      <= 2'd0;
            input_q           <= 128'd0;
            output_q          <= 128'd0;
            primitive_input_q <= 128'd0;
            o_busy            <= 1'b0;
            o_done            <= 1'b0;
            o_error           <= 1'b0;
            o_blocks_done     <= 9'd0;
        end else begin
            case (state_q)
                IDLE: begin
                    // START sem ownership é ignorado, sem enfileiramento.
                    if (i_start && i_mem_owned) begin
                        if (!config_valid) begin
                            // Preservar DONE e BLOCKS_DONE da última operação.
                            o_error <= 1'b1;
                        end else begin
                            key_q         <= i_key;
                            iv_q          <= i_iv;
                            chain_q       <= i_iv;
                            counter_q     <= i_counter;
                            mode_q        <= i_mode;
                            decrypt_q     <= i_decrypt;
                            num_blocks_q  <= i_num_blocks[8:0];
                            block_index_q <= 8'd0;
                            word_index_q  <= 2'd0;
                            input_q       <= 128'd0;
                            o_blocks_done <= 9'd0;
                            o_busy        <= 1'b1;
                            o_done        <= 1'b0;
                            o_error       <= 1'b0;
                            state_q       <= KEY_START;
                        end
                    end
                end
                KEY_START: begin
                    if (!key_busy)
                        state_q <= KEY_WAIT;
                end
                KEY_WAIT: begin
                    if (key_done)
                        state_q <= READ_REQ;
                end
                READ_REQ: begin
                    // A memória registra a palavra na borda que encerra este estado.
                    state_q <= READ_CAPTURE;
                end
                READ_CAPTURE: begin
                    // Capturar na borda seguinte evita usar o dado anterior ao NBA.
                    input_q[127 - 32*word_index_q -: 32] <= i_mem_data;
                    if (word_index_q == 2'd3) begin
                        word_index_q <= 2'd0;
                        state_q <= PREPARE;
                    end else begin
                        word_index_q <= word_index_q + 2'd1;
                        state_q <= READ_REQ;
                    end
                end
                PREPARE: begin
                    case (mode_q)
                        MODE_CBC: primitive_input_q <= decrypt_q ? input_q : (input_q ^ chain_q);
                        MODE_CTR: primitive_input_q <= iv_q ^ {64'd0, counter_q};
                        default:  primitive_input_q <= input_q;
                    endcase
                    state_q <= AES_START;
                end
                AES_START: begin
                    if (!dp_busy && keys_ready)
                        state_q <= AES_WAIT;
                end
                AES_WAIT: begin
                    if (dp_done)
                        state_q <= POSTPROCESS;
                end
                POSTPROCESS: begin
                    case (mode_q)
                        MODE_CBC: begin
                            output_q <= decrypt_q ? (dp_result ^ chain_q) : dp_result;
                            // Na decriptação in-place, input_q ainda contém C anterior.
                            chain_q <= decrypt_q ? input_q : dp_result;
                        end
                        MODE_CTR: begin
                            output_q <= input_q ^ dp_result;
                            // Soma módulo 2^64, sem writeback no banco de configuração.
                            counter_q <= counter_q + 64'd1;
                        end
                        default: output_q <= dp_result;
                    endcase
                    word_index_q <= 2'd0;
                    state_q <= WRITE_WORD;
                end
                WRITE_WORD: begin
                    // O porto grava a palavra na mesma borda que avança o índice.
                    if (word_index_q == 2'd3) begin
                        word_index_q <= 2'd0;
                        state_q <= NEXT_BLOCK;
                    end else begin
                        word_index_q <= word_index_q + 2'd1;
                    end
                end
                NEXT_BLOCK: begin
                    // O bloco só conta depois de suas quatro escritas concluídas.
                    o_blocks_done <= next_done;
                    if (next_done == num_blocks_q) begin
                        o_busy  <= 1'b0;
                        o_done  <= 1'b1;
                        state_q <= IDLE;
                    end else begin
                        block_index_q <= block_index_q + 8'd1;
                        state_q <= READ_REQ;
                    end
                end
                default: begin
                    state_q <= IDLE;
                    o_busy  <= 1'b0;
                    o_error <= 1'b1;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
