`timescale 1ns/1ps
`default_nettype none

// Modelo de integração: referência de 2 GHz, sem modelo analógico de PLL.
// Aguarda 8..39 ciclos após aceitar enable e alinha a liberação à descida.
module minisoc_pll_mock #(
    parameter logic [7:0] LOCK_SEED = 8'ha5
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       i_enable,
    input  wire [1:0] i_div_sel,
    output wire      o_sys_clk,
    output wire      o_locked
);
    logic [2:0] divider;
    logic [1:0] div_sel_q;
    logic [7:0] lfsr;
    logic [5:0] cycles_left;
    logic acquiring, lock_request, gate_q, selected_clk;

    // O divisor continua funcionando com a saída bloqueada. Isso permite
    // fechar o gate na próxima descida, sem depender de um clock já parado.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divider      <= 3'd0;
            div_sel_q    <= 2'd0;
            lfsr         <= (LOCK_SEED == 8'd0) ? 8'h01 : LOCK_SEED;
            cycles_left  <= 6'd0;
            acquiring    <= 1'b0;
            lock_request <= 1'b0;
        end else begin
            divider <= divider + 3'd1;
            if (!i_enable) begin
                acquiring    <= 1'b0;
                cycles_left  <= 6'd0;
                lock_request <= 1'b0;
            end else if (!acquiring && !gate_q) begin
                // Divisor capturado apenas no começo da aquisição.
                div_sel_q    <= i_div_sel;
                cycles_left  <= 6'd8 + {1'b0, lfsr[4:0]};
                lfsr         <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                acquiring    <= 1'b1;
                lock_request <= 1'b0;
            end else if (acquiring && !lock_request) begin
                if (cycles_left == 6'd1) begin
                    cycles_left  <= 6'd0;
                    lock_request <= 1'b1;
                end else begin
                    cycles_left <= cycles_left - 6'd1;
                end
            end
        end
    end

    always_comb begin
        case (div_sel_q)
            2'b00: selected_clk = clk;
            2'b01: selected_clk = divider[0];
            2'b10: selected_clk = divider[1];
            2'b11: selected_clk = divider[2];
            default: selected_clk = 1'b0;
        endcase
    end

    // Mudanças do gate somente na descida preservam pulsos altos completos.
    // Disable tem latência até essa borda; reset global força zero imediatamente.
    always_ff @(negedge selected_clk or negedge rst_n) begin
        if (!rst_n)
            gate_q <= 1'b0;
        else
            gate_q <= lock_request && i_enable;
    end

    assign o_sys_clk = selected_clk & gate_q;
    assign o_locked = gate_q;
endmodule

`default_nettype wire
