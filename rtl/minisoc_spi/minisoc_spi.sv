`timescale 1ns/1ps
`default_nettype none

// SPI Mode 0, MSB-first. Banco e comando START pertencem ao clk always-on.
// Leitura: READ request e depois NOP; MISO devolve {8'h00, dado[31:0]}.
// Status AES deve chegar coerente e síncrono a clk, pelo futuro bridge do engine.
module minisoc_spi #(
    parameter logic [31:0] VERSION = 32'h0001_0000
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         spi_sclk,
    input  wire         spi_cs_n,
    input  wire         spi_mosi,
    output wire         spi_miso,
    output logic [127:0] o_key,
    output logic [127:0] o_iv,
    output logic [63:0]  o_counter,
    output logic [31:0]  o_num_blocks,
    output logic [2:0]   o_mode,
    output logic        o_decrypt,
    output logic        o_start,
    input  wire         i_aes_busy,
    input  wire         i_aes_done,
    input  wire         i_aes_error,
    input  wire [8:0]   i_blocks_done,
    output logic        o_mem_sel_aes,
    output logic        o_pll_enable,
    output logic [1:0]  o_pll_div_sel,
    input  wire         i_pll_locked
);
    logic [39:0] rx_shift, frame_hold;
    logic [5:0] rx_count;
    logic frame_req, frame_ack, frame_pending;
    (* ASYNC_REG = "TRUE" *) logic frame_req_meta, frame_req_sync;
    (* ASYNC_REG = "TRUE" *) logic frame_ack_meta, frame_ack_sync;

    logic [31:0] response_hold, response_local, tx_shift;
    logic response_req, response_ack, response_seen;
    logic response_pending, response_valid, miso_q;
    (* ASYNC_REG = "TRUE" *) logic response_req_meta, response_req_sync;
    (* ASYNC_REG = "TRUE" *) logic response_ack_meta, response_ack_sync;
    (* ASYNC_REG = "TRUE" *) logic locked_meta, locked_sync;

    // Após oito subidas, os sete bits inferiores são {ADDR, RSV}.
    // NOP aceita qualquer RWb; RSV deve continuar em zero.
    wire return_slot = !spi_cs_n && (rx_count == 6'd8)
                     && (rx_shift[6:0] == 7'h7e);
    assign spi_miso = spi_cs_n ? 1'b0 : miso_q;

    // CS limpa somente a transação serial. O contador satura após um frame.
    always_ff @(posedge spi_sclk or posedge spi_cs_n or negedge rst_n) begin
        if (!rst_n || spi_cs_n) begin
            rx_shift <= 40'd0;
            rx_count <= 6'd0;
        end else if (rx_count < 6'd40) begin
            rx_shift <= {rx_shift[38:0], spi_mosi};
            rx_count <= rx_count + 6'd1;
        end
    end

    // Mailbox e toggles sobrevivem à subida de CS e à parada de SCLK.
    always_ff @(posedge spi_sclk or negedge rst_n) begin
        if (!rst_n) begin
            frame_hold     <= 40'd0;
            frame_req      <= 1'b0;
            frame_ack_meta <= 1'b0;
            frame_ack_sync <= 1'b0;
        end else begin
            frame_ack_meta <= frame_ack;
            frame_ack_sync <= frame_ack_meta;
            if (!spi_cs_n && (rx_count == 6'd39)) begin
                if (frame_req == frame_ack_sync) begin
                    // Inclui o MOSI atual: rx_shift ainda não contém o 40º bit.
                    frame_hold <= {rx_shift[38:0], spi_mosi};
                    frame_req  <= ~frame_req;
                end else begin
`ifndef SYNTHESIS
                    $fatal(1, "SPI: frame recebido com mailbox ocupado");
`endif
                end
            end
        end
    end

    // Sincronizadores de controle no domínio always-on.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_req_meta    <= 1'b0;
            frame_req_sync    <= 1'b0;
            response_ack_meta <= 1'b0;
            response_ack_sync <= 1'b0;
            locked_meta       <= 1'b0;
            locked_sync       <= 1'b0;
        end else begin
            frame_req_meta    <= frame_req;
            frame_req_sync    <= frame_req_meta;
            response_ack_meta <= response_ack;
            response_ack_sync <= response_ack_meta;
            locked_meta       <= i_pll_locked;
            locked_sync       <= locked_meta;
        end
    end

    function automatic logic [31:0] read_register(input logic [5:0] address);
        case (address)
            6'h00: read_register = o_key[127:96];
            6'h01: read_register = o_key[95:64];
            6'h02: read_register = o_key[63:32];
            6'h03: read_register = o_key[31:0];
            6'h04: read_register = o_iv[127:96];
            6'h05: read_register = o_iv[95:64];
            6'h06: read_register = o_iv[63:32];
            6'h07: read_register = o_iv[31:0];
            6'h08: read_register = o_counter[63:32];
            6'h09: read_register = o_counter[31:0];
            6'h0a: read_register = o_num_blocks;
            6'h0b: read_register = {27'd0, o_mode, o_decrypt, 1'b0};
            6'h0c: read_register = {20'd0, i_blocks_done, i_aes_error,
                                   i_aes_done, i_aes_busy};
            6'h0d: read_register = VERSION;
            6'h0e: read_register = {28'd0, o_pll_div_sel, o_pll_enable,
                                   o_mem_sel_aes};
            6'h0f: read_register = {31'd0, locked_sync};
            default: read_register = 32'd0;
        endcase
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_key          <= 128'd0;
            o_iv           <= 128'd0;
            o_counter      <= 64'd0;
            o_num_blocks   <= 32'd0;
            o_mode         <= 3'd0;
            o_decrypt      <= 1'b0;
            o_start        <= 1'b0;
            o_mem_sel_aes  <= 1'b0;
            o_pll_enable   <= 1'b0;
            o_pll_div_sel  <= 2'd0;
            frame_ack      <= 1'b0;
            frame_pending  <= 1'b0;
            response_hold  <= 32'd0;
            response_req   <= 1'b0;
        end else begin
            o_start <= 1'b0;
            if (!frame_pending) begin
                if (frame_req_sync != frame_ack)
                    frame_pending <= 1'b1;
            end else if (!frame_hold[32] && frame_hold[39]
                         && (frame_hold[38:33] != 6'h3f)
                         && (response_req != response_ack_sync)) begin
                // Mantém o frame pendente até a cópia da resposta anterior.
                frame_pending <= 1'b1;
            end else begin
                frame_pending <= 1'b0;
                frame_ack <= frame_req_sync;
                // RSV inválido e NOP não acessam o banco.
                if (!frame_hold[32] && (frame_hold[38:33] != 6'h3f)) begin
                    if (frame_hold[39]) begin
                        response_hold <= read_register(frame_hold[38:33]);
                        response_req <= ~response_req;
                    end else begin
                        case (frame_hold[38:33])
                            6'h00: o_key[127:96] <= frame_hold[31:0];
                            6'h01: o_key[95:64]  <= frame_hold[31:0];
                            6'h02: o_key[63:32]  <= frame_hold[31:0];
                            6'h03: o_key[31:0]   <= frame_hold[31:0];
                            6'h04: o_iv[127:96]  <= frame_hold[31:0];
                            6'h05: o_iv[95:64]   <= frame_hold[31:0];
                            6'h06: o_iv[63:32]   <= frame_hold[31:0];
                            6'h07: o_iv[31:0]    <= frame_hold[31:0];
                            6'h08: o_counter[63:32] <= frame_hold[31:0];
                            6'h09: o_counter[31:0]  <= frame_hold[31:0];
                            6'h0a: o_num_blocks <= frame_hold[31:0];
                            6'h0b: begin
                                o_mode    <= frame_hold[4:2];
                                o_decrypt <= frame_hold[1];
                                o_start   <= frame_hold[0];
                            end
                            6'h0e: begin
                                o_pll_div_sel <= frame_hold[3:2];
                                o_pll_enable  <= frame_hold[1];
                                o_mem_sel_aes <= frame_hold[0];
                            end
                            default: begin end // Escritas em R/desconhecidos ignoradas.
                        endcase
                    end
                end
            end
        end
    end

    // As primeiras descidas do cabeçalho dão tempo ao CDC da resposta.
    // CS não apaga um snapshot ainda não consumido por NOP.
    always_ff @(negedge spi_sclk or negedge rst_n) begin
        if (!rst_n) begin
            response_req_meta <= 1'b0;
            response_req_sync <= 1'b0;
            response_seen     <= 1'b0;
            response_pending  <= 1'b0;
            response_local    <= 32'd0;
            response_valid    <= 1'b0;
            response_ack      <= 1'b0;
        end else begin
            response_req_meta <= response_req;
            response_req_sync <= response_req_meta;
            if (response_pending) begin
                response_local   <= response_hold;
                response_seen    <= response_req_sync;
                response_ack     <= response_req_sync;
                response_valid   <= 1'b1;
                response_pending <= 1'b0;
            end else if (!response_valid && (response_req_sync != response_seen)) begin
                response_pending <= 1'b1;
            end
            if (return_slot && response_valid)
                response_valid <= 1'b0;
        end
    end

    // Oito zeros de cabeçalho, seguidos pelo snapshot nos clocks 9..40.
    always_ff @(negedge spi_sclk or posedge spi_cs_n or negedge rst_n) begin
        if (!rst_n || spi_cs_n) begin
            tx_shift <= 32'd0;
            miso_q   <= 1'b0;
        end else if (rx_count == 6'd8) begin
            if (return_slot && response_valid) begin
                miso_q   <= response_local[31];
                tx_shift <= {response_local[30:0], 1'b0};
            end else begin
                miso_q   <= 1'b0;
                tx_shift <= 32'd0;
            end
        end else if ((rx_count > 6'd8) && (rx_count < 6'd40)) begin
            miso_q   <= tx_shift[31];
            tx_shift <= {tx_shift[30:0], 1'b0};
        end else begin
            miso_q <= 1'b0;
        end
    end
endmodule

`default_nettype wire
