`timescale 1ns/1ps
`default_nettype none

// S-box direta do AES: tabela da FIPS-197 (2001), seção 5.1.1, Figura 7.
// O nibble alto seleciona a linha; o nibble baixo seleciona a coluna.
// Consulta combinacional, sem clock, reset ou armazenamento de estado.
module minisoc_aes_sbox (
    input  wire [7:0] i_byte,
    output wire [7:0] o_byte
);
    function automatic logic [7:0] lookup_sbox(input logic [7:0] value);
        case (value)
            // Linha 0 da tabela: entradas 00 a 0f.
            8'h00: lookup_sbox = 8'h63;
            8'h01: lookup_sbox = 8'h7c;
            8'h02: lookup_sbox = 8'h77;
            8'h03: lookup_sbox = 8'h7b;
            8'h04: lookup_sbox = 8'hf2;
            8'h05: lookup_sbox = 8'h6b;
            8'h06: lookup_sbox = 8'h6f;
            8'h07: lookup_sbox = 8'hc5;
            8'h08: lookup_sbox = 8'h30;
            8'h09: lookup_sbox = 8'h01;
            8'h0a: lookup_sbox = 8'h67;
            8'h0b: lookup_sbox = 8'h2b;
            8'h0c: lookup_sbox = 8'hfe;
            8'h0d: lookup_sbox = 8'hd7;
            8'h0e: lookup_sbox = 8'hab;
            8'h0f: lookup_sbox = 8'h76;

            // Linha 1 da tabela: entradas 10 a 1f.
            8'h10: lookup_sbox = 8'hca;
            8'h11: lookup_sbox = 8'h82;
            8'h12: lookup_sbox = 8'hc9;
            8'h13: lookup_sbox = 8'h7d;
            8'h14: lookup_sbox = 8'hfa;
            8'h15: lookup_sbox = 8'h59;
            8'h16: lookup_sbox = 8'h47;
            8'h17: lookup_sbox = 8'hf0;
            8'h18: lookup_sbox = 8'had;
            8'h19: lookup_sbox = 8'hd4;
            8'h1a: lookup_sbox = 8'ha2;
            8'h1b: lookup_sbox = 8'haf;
            8'h1c: lookup_sbox = 8'h9c;
            8'h1d: lookup_sbox = 8'ha4;
            8'h1e: lookup_sbox = 8'h72;
            8'h1f: lookup_sbox = 8'hc0;

            // Linha 2 da tabela: entradas 20 a 2f.
            8'h20: lookup_sbox = 8'hb7;
            8'h21: lookup_sbox = 8'hfd;
            8'h22: lookup_sbox = 8'h93;
            8'h23: lookup_sbox = 8'h26;
            8'h24: lookup_sbox = 8'h36;
            8'h25: lookup_sbox = 8'h3f;
            8'h26: lookup_sbox = 8'hf7;
            8'h27: lookup_sbox = 8'hcc;
            8'h28: lookup_sbox = 8'h34;
            8'h29: lookup_sbox = 8'ha5;
            8'h2a: lookup_sbox = 8'he5;
            8'h2b: lookup_sbox = 8'hf1;
            8'h2c: lookup_sbox = 8'h71;
            8'h2d: lookup_sbox = 8'hd8;
            8'h2e: lookup_sbox = 8'h31;
            8'h2f: lookup_sbox = 8'h15;

            // Linha 3 da tabela: entradas 30 a 3f.
            8'h30: lookup_sbox = 8'h04;
            8'h31: lookup_sbox = 8'hc7;
            8'h32: lookup_sbox = 8'h23;
            8'h33: lookup_sbox = 8'hc3;
            8'h34: lookup_sbox = 8'h18;
            8'h35: lookup_sbox = 8'h96;
            8'h36: lookup_sbox = 8'h05;
            8'h37: lookup_sbox = 8'h9a;
            8'h38: lookup_sbox = 8'h07;
            8'h39: lookup_sbox = 8'h12;
            8'h3a: lookup_sbox = 8'h80;
            8'h3b: lookup_sbox = 8'he2;
            8'h3c: lookup_sbox = 8'heb;
            8'h3d: lookup_sbox = 8'h27;
            8'h3e: lookup_sbox = 8'hb2;
            8'h3f: lookup_sbox = 8'h75;

            // Linha 4 da tabela: entradas 40 a 4f.
            8'h40: lookup_sbox = 8'h09;
            8'h41: lookup_sbox = 8'h83;
            8'h42: lookup_sbox = 8'h2c;
            8'h43: lookup_sbox = 8'h1a;
            8'h44: lookup_sbox = 8'h1b;
            8'h45: lookup_sbox = 8'h6e;
            8'h46: lookup_sbox = 8'h5a;
            8'h47: lookup_sbox = 8'ha0;
            8'h48: lookup_sbox = 8'h52;
            8'h49: lookup_sbox = 8'h3b;
            8'h4a: lookup_sbox = 8'hd6;
            8'h4b: lookup_sbox = 8'hb3;
            8'h4c: lookup_sbox = 8'h29;
            8'h4d: lookup_sbox = 8'he3;
            8'h4e: lookup_sbox = 8'h2f;
            8'h4f: lookup_sbox = 8'h84;

            // Linha 5 da tabela: entradas 50 a 5f.
            8'h50: lookup_sbox = 8'h53;
            8'h51: lookup_sbox = 8'hd1;
            8'h52: lookup_sbox = 8'h00;
            8'h53: lookup_sbox = 8'hed;
            8'h54: lookup_sbox = 8'h20;
            8'h55: lookup_sbox = 8'hfc;
            8'h56: lookup_sbox = 8'hb1;
            8'h57: lookup_sbox = 8'h5b;
            8'h58: lookup_sbox = 8'h6a;
            8'h59: lookup_sbox = 8'hcb;
            8'h5a: lookup_sbox = 8'hbe;
            8'h5b: lookup_sbox = 8'h39;
            8'h5c: lookup_sbox = 8'h4a;
            8'h5d: lookup_sbox = 8'h4c;
            8'h5e: lookup_sbox = 8'h58;
            8'h5f: lookup_sbox = 8'hcf;

            // Linha 6 da tabela: entradas 60 a 6f.
            8'h60: lookup_sbox = 8'hd0;
            8'h61: lookup_sbox = 8'hef;
            8'h62: lookup_sbox = 8'haa;
            8'h63: lookup_sbox = 8'hfb;
            8'h64: lookup_sbox = 8'h43;
            8'h65: lookup_sbox = 8'h4d;
            8'h66: lookup_sbox = 8'h33;
            8'h67: lookup_sbox = 8'h85;
            8'h68: lookup_sbox = 8'h45;
            8'h69: lookup_sbox = 8'hf9;
            8'h6a: lookup_sbox = 8'h02;
            8'h6b: lookup_sbox = 8'h7f;
            8'h6c: lookup_sbox = 8'h50;
            8'h6d: lookup_sbox = 8'h3c;
            8'h6e: lookup_sbox = 8'h9f;
            8'h6f: lookup_sbox = 8'ha8;

            // Linha 7 da tabela: entradas 70 a 7f.
            8'h70: lookup_sbox = 8'h51;
            8'h71: lookup_sbox = 8'ha3;
            8'h72: lookup_sbox = 8'h40;
            8'h73: lookup_sbox = 8'h8f;
            8'h74: lookup_sbox = 8'h92;
            8'h75: lookup_sbox = 8'h9d;
            8'h76: lookup_sbox = 8'h38;
            8'h77: lookup_sbox = 8'hf5;
            8'h78: lookup_sbox = 8'hbc;
            8'h79: lookup_sbox = 8'hb6;
            8'h7a: lookup_sbox = 8'hda;
            8'h7b: lookup_sbox = 8'h21;
            8'h7c: lookup_sbox = 8'h10;
            8'h7d: lookup_sbox = 8'hff;
            8'h7e: lookup_sbox = 8'hf3;
            8'h7f: lookup_sbox = 8'hd2;

            // Linha 8 da tabela: entradas 80 a 8f.
            8'h80: lookup_sbox = 8'hcd;
            8'h81: lookup_sbox = 8'h0c;
            8'h82: lookup_sbox = 8'h13;
            8'h83: lookup_sbox = 8'hec;
            8'h84: lookup_sbox = 8'h5f;
            8'h85: lookup_sbox = 8'h97;
            8'h86: lookup_sbox = 8'h44;
            8'h87: lookup_sbox = 8'h17;
            8'h88: lookup_sbox = 8'hc4;
            8'h89: lookup_sbox = 8'ha7;
            8'h8a: lookup_sbox = 8'h7e;
            8'h8b: lookup_sbox = 8'h3d;
            8'h8c: lookup_sbox = 8'h64;
            8'h8d: lookup_sbox = 8'h5d;
            8'h8e: lookup_sbox = 8'h19;
            8'h8f: lookup_sbox = 8'h73;

            // Linha 9 da tabela: entradas 90 a 9f.
            8'h90: lookup_sbox = 8'h60;
            8'h91: lookup_sbox = 8'h81;
            8'h92: lookup_sbox = 8'h4f;
            8'h93: lookup_sbox = 8'hdc;
            8'h94: lookup_sbox = 8'h22;
            8'h95: lookup_sbox = 8'h2a;
            8'h96: lookup_sbox = 8'h90;
            8'h97: lookup_sbox = 8'h88;
            8'h98: lookup_sbox = 8'h46;
            8'h99: lookup_sbox = 8'hee;
            8'h9a: lookup_sbox = 8'hb8;
            8'h9b: lookup_sbox = 8'h14;
            8'h9c: lookup_sbox = 8'hde;
            8'h9d: lookup_sbox = 8'h5e;
            8'h9e: lookup_sbox = 8'h0b;
            8'h9f: lookup_sbox = 8'hdb;

            // Linha a da tabela: entradas a0 a af.
            8'ha0: lookup_sbox = 8'he0;
            8'ha1: lookup_sbox = 8'h32;
            8'ha2: lookup_sbox = 8'h3a;
            8'ha3: lookup_sbox = 8'h0a;
            8'ha4: lookup_sbox = 8'h49;
            8'ha5: lookup_sbox = 8'h06;
            8'ha6: lookup_sbox = 8'h24;
            8'ha7: lookup_sbox = 8'h5c;
            8'ha8: lookup_sbox = 8'hc2;
            8'ha9: lookup_sbox = 8'hd3;
            8'haa: lookup_sbox = 8'hac;
            8'hab: lookup_sbox = 8'h62;
            8'hac: lookup_sbox = 8'h91;
            8'had: lookup_sbox = 8'h95;
            8'hae: lookup_sbox = 8'he4;
            8'haf: lookup_sbox = 8'h79;

            // Linha b da tabela: entradas b0 a bf.
            8'hb0: lookup_sbox = 8'he7;
            8'hb1: lookup_sbox = 8'hc8;
            8'hb2: lookup_sbox = 8'h37;
            8'hb3: lookup_sbox = 8'h6d;
            8'hb4: lookup_sbox = 8'h8d;
            8'hb5: lookup_sbox = 8'hd5;
            8'hb6: lookup_sbox = 8'h4e;
            8'hb7: lookup_sbox = 8'ha9;
            8'hb8: lookup_sbox = 8'h6c;
            8'hb9: lookup_sbox = 8'h56;
            8'hba: lookup_sbox = 8'hf4;
            8'hbb: lookup_sbox = 8'hea;
            8'hbc: lookup_sbox = 8'h65;
            8'hbd: lookup_sbox = 8'h7a;
            8'hbe: lookup_sbox = 8'hae;
            8'hbf: lookup_sbox = 8'h08;

            // Linha c da tabela: entradas c0 a cf.
            8'hc0: lookup_sbox = 8'hba;
            8'hc1: lookup_sbox = 8'h78;
            8'hc2: lookup_sbox = 8'h25;
            8'hc3: lookup_sbox = 8'h2e;
            8'hc4: lookup_sbox = 8'h1c;
            8'hc5: lookup_sbox = 8'ha6;
            8'hc6: lookup_sbox = 8'hb4;
            8'hc7: lookup_sbox = 8'hc6;
            8'hc8: lookup_sbox = 8'he8;
            8'hc9: lookup_sbox = 8'hdd;
            8'hca: lookup_sbox = 8'h74;
            8'hcb: lookup_sbox = 8'h1f;
            8'hcc: lookup_sbox = 8'h4b;
            8'hcd: lookup_sbox = 8'hbd;
            8'hce: lookup_sbox = 8'h8b;
            8'hcf: lookup_sbox = 8'h8a;

            // Linha d da tabela: entradas d0 a df.
            8'hd0: lookup_sbox = 8'h70;
            8'hd1: lookup_sbox = 8'h3e;
            8'hd2: lookup_sbox = 8'hb5;
            8'hd3: lookup_sbox = 8'h66;
            8'hd4: lookup_sbox = 8'h48;
            8'hd5: lookup_sbox = 8'h03;
            8'hd6: lookup_sbox = 8'hf6;
            8'hd7: lookup_sbox = 8'h0e;
            8'hd8: lookup_sbox = 8'h61;
            8'hd9: lookup_sbox = 8'h35;
            8'hda: lookup_sbox = 8'h57;
            8'hdb: lookup_sbox = 8'hb9;
            8'hdc: lookup_sbox = 8'h86;
            8'hdd: lookup_sbox = 8'hc1;
            8'hde: lookup_sbox = 8'h1d;
            8'hdf: lookup_sbox = 8'h9e;

            // Linha e da tabela: entradas e0 a ef.
            8'he0: lookup_sbox = 8'he1;
            8'he1: lookup_sbox = 8'hf8;
            8'he2: lookup_sbox = 8'h98;
            8'he3: lookup_sbox = 8'h11;
            8'he4: lookup_sbox = 8'h69;
            8'he5: lookup_sbox = 8'hd9;
            8'he6: lookup_sbox = 8'h8e;
            8'he7: lookup_sbox = 8'h94;
            8'he8: lookup_sbox = 8'h9b;
            8'he9: lookup_sbox = 8'h1e;
            8'hea: lookup_sbox = 8'h87;
            8'heb: lookup_sbox = 8'he9;
            8'hec: lookup_sbox = 8'hce;
            8'hed: lookup_sbox = 8'h55;
            8'hee: lookup_sbox = 8'h28;
            8'hef: lookup_sbox = 8'hdf;

            // Linha f da tabela: entradas f0 a ff.
            8'hf0: lookup_sbox = 8'h8c;
            8'hf1: lookup_sbox = 8'ha1;
            8'hf2: lookup_sbox = 8'h89;
            8'hf3: lookup_sbox = 8'h0d;
            8'hf4: lookup_sbox = 8'hbf;
            8'hf5: lookup_sbox = 8'he6;
            8'hf6: lookup_sbox = 8'h42;
            8'hf7: lookup_sbox = 8'h68;
            8'hf8: lookup_sbox = 8'h41;
            8'hf9: lookup_sbox = 8'h99;
            8'hfa: lookup_sbox = 8'h2d;
            8'hfb: lookup_sbox = 8'h0f;
            8'hfc: lookup_sbox = 8'hb0;
            8'hfd: lookup_sbox = 8'h54;
            8'hfe: lookup_sbox = 8'hbb;
            8'hff: lookup_sbox = 8'h16;

            // Preserva a indicação de entrada desconhecida durante a simulação.
            default: lookup_sbox = 8'hxx;
        endcase
    endfunction

    assign o_byte = lookup_sbox(i_byte);
endmodule

`default_nettype wire
