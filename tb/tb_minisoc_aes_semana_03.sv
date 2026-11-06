`timescale 1ns/1ps
`default_nettype none

module tb_minisoc_aes_semana_03;
    // Semana 3: transformações isoladas contra valores intermediários fixos
    // da FIPS-197 (2001). Todas as referências ficam neste testbench.
    logic [127:0] state_in, key_in;
    wire [127:0] sub_out, inv_sub_out, shift_out, inv_shift_out;
    wire [127:0] mix_out, inv_mix_out, add_out;
    int unsigned checks = 0;
    // Apêndice B: 1 + 4 + 3 = 8; Apêndice C.1: 1 + 9*4 + 3 = 40.
    localparam int EXPECTED_CHECKS = 48;

    minisoc_aes_sub_bytes u_sub (.i_state(state_in), .o_state(sub_out));
    minisoc_aes_inv_sub_bytes u_inv_sub (.i_state(state_in), .o_state(inv_sub_out));
    minisoc_aes_shift_rows u_shift (.i_state(state_in), .o_state(shift_out));
    minisoc_aes_inv_shift_rows u_inv_shift (.i_state(state_in), .o_state(inv_shift_out));
    minisoc_aes_mix_columns u_mix (.i_state(state_in), .o_state(mix_out));
    minisoc_aes_inv_mix_columns u_inv_mix (.i_state(state_in), .o_state(inv_mix_out));
    minisoc_aes_add_round_key u_add (
        .i_state(state_in), .i_round_key(key_in), .o_state(add_out));

    task automatic check_state(
        input string label_text,
        input logic [127:0] actual,
        input logic [127:0] expected
    );
        if (actual !== expected)
            $fatal(1, "FAIL %s: expected=%032h actual=%032h", label_text, expected, actual);
        checks++;
    endtask

    task automatic check_b_round(
        input int round_number,
        input logic [127:0] start_value,
        input logic [127:0] sub_value,
        input logic [127:0] shift_value,
        input logic [127:0] mix_value,
        input logic [127:0] key_value,
        input logic [127:0] end_value
    );
        state_in = start_value;
        #1;
        check_state("B SubBytes", sub_out, sub_value);
        state_in = sub_value;
        #1;
        check_state("B ShiftRows", shift_out, shift_value);
        if (round_number != 10) begin
            state_in = shift_value;
            #1;
            check_state("B MixColumns", mix_out, mix_value);
        end
        state_in = (round_number == 10) ? shift_value : mix_value;
        key_in = key_value;
        #1;
        check_state("B AddRoundKey", add_out, end_value);
        $display("PASS FIPS-197 Appendix B round %0d", round_number);
    endtask

    // Cifra inversa convencional de C.1, conforme a seção INVERSE CIPHER.
    // Usa K9..K0 sem transformação, com AddRoundKey antes de InvMixColumns.
    task automatic check_c_inverse_round(
        input int round_number,
        input logic [127:0] start_value,
        input logic [127:0] shift_value,
        input logic [127:0] sub_value,
        input logic [127:0] key_value,
        input logic [127:0] add_value,
        input logic [127:0] end_value
    );
        state_in = start_value;
        #1;
        check_state("C.1 InvShiftRows", inv_shift_out, shift_value);
        state_in = shift_value;
        #1;
        check_state("C.1 InvSubBytes", inv_sub_out, sub_value);
        state_in = sub_value;
        key_in = key_value;
        #1;
        check_state("C.1 AddRoundKey", add_out, add_value);
        if (round_number != 10) begin
            state_in = add_value;
            #1;
            // O istart da rodada seguinte é a saída publicada de InvMixColumns.
            check_state("C.1 InvMixColumns", inv_mix_out, end_value);
        end
        $display("PASS FIPS-197 Appendix C.1 inverse round %0d", round_number);
    endtask

    initial begin : stimulus
        state_in = '0;
        key_in = '0;

        // FIPS-197 (2001), Apêndice B, páginas impressas 33-34.
        state_in = 128'h3243f6a8885a308d313198a2e0370734;
        key_in = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        #1;
        check_state("B initial AddRoundKey", add_out,
                    128'h193de3bea0f4e22b9ac68d2ae9f84808);
        check_b_round(1,
            128'h193de3bea0f4e22b9ac68d2ae9f84808,
            128'hd42711aee0bf98f1b8b45de51e415230,
            128'hd4bf5d30e0b452aeb84111f11e2798e5,
            128'h046681e5e0cb199a48f8d37a2806264c,
            128'ha0fafe1788542cb123a339392a6c7605,
            128'ha49c7ff2689f352b6b5bea43026a5049);
        check_b_round(10,
            128'heb40f21e592e38848ba113e71bc342d2,
            128'he9098972cb31075f3d327d94af2e2cb5,
            128'he9317db5cb322c723d2e895faf090794,
            128'h0, // MixColumns não é aplicado na última rodada; valor ignorado.
            128'hd014f9a8c9ee2589e13f0cc8b6630ca6,
            128'h3925841d02dc09fbdc118597196a0b32);

        // Apêndice C.1: AES-128, chave 000102...0f, texto claro 001122...ff.
        state_in = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        key_in = 128'h13111d7fe3944a17f307a78b4d2b30c5;
        #1;
        check_state("C.1 initial AddRoundKey K10", add_out,
                    128'h7ad5fda789ef4e272bca100b3d9ff59f);
        check_c_inverse_round(1,
            128'h7ad5fda789ef4e272bca100b3d9ff59f,
            128'h7a9f102789d5f50b2beffd9f3dca4ea7,
            128'hbd6e7c3df2b5779e0b61216e8b10b689,
            128'h549932d1f08557681093ed9cbe2c974e,
            128'he9f74eec023020f61bf2ccf2353c21c7,
            128'h54d990a16ba09ab596bbf40ea111702f);
        check_c_inverse_round(2,
            128'h54d990a16ba09ab596bbf40ea111702f,
            128'h5411f4b56bd9700e96a0902fa1bb9aa1,
            128'hfde3bad205e5d0d73547964ef1fe37f1,
            128'h47438735a41c65b9e016baf4aebf7ad2,
            128'hbaa03de7a1f9b56ed5512cba5f414d23,
            128'h3e1c22c0b6fcbf768da85067f6170495);
        check_c_inverse_round(3,
            128'h3e1c22c0b6fcbf768da85067f6170495,
            128'h3e175076b61c04678dfc2295f6a8bfc0,
            128'hd1876c0f79c4300ab45594add66ff41f,
            128'h14f9701ae35fe28c440adf4d4ea9c026,
            128'hc57e1c159a9bd286f05f4be098c63439,
            128'hb458124c68b68a014b99f82e5f15554c);
        check_c_inverse_round(4,
            128'hb458124c68b68a014b99f82e5f15554c,
            128'hb415f8016858552e4bb6124c5f998a4c,
            128'hc62fe109f75eedc3cc79395d84f9cf5d,
            128'h5e390f7df7a69296a7553dc10aa31f6b,
            128'h9816ee7400f87f556b2c049c8e5ad036,
            128'he8dab6901477d4653ff7f5e2e747dd4f);
        check_c_inverse_round(5,
            128'he8dab6901477d4653ff7f5e2e747dd4f,
            128'he847f56514dadde23f77b64fe7f7d490,
            128'hc81677bc9b7ac93b25027992b0261996,
            128'h3caaa3e8a99f9deb50f3af57adf622aa,
            128'hf4bcd45432e554d075f1d6c51dd03b3c,
            128'h36339d50f9b539269f2c092dc4406d23);
        check_c_inverse_round(6,
            128'h36339d50f9b539269f2c092dc4406d23,
            128'h36400926f9336d2d9fb59d23c42c3950,
            128'h247240236966b3fa6ed2753288425b6c,
            128'h47f7f7bc95353e03f96c32bcfd058dfd,
            128'h6385b79ffc538df997be478e7547d691,
            128'h2d6d7ef03f33e334093602dd5bfb12c7);
        check_c_inverse_round(7,
            128'h2d6d7ef03f33e334093602dd5bfb12c7,
            128'h2dfb02343f6d12dd09337ec75b36e3f0,
            128'hfa636a2825b339c940668a3157244d17,
            128'hb6ff744ed2c2c9bf6c590cbf0469bf41,
            128'h4c9c1e66f771f0762c3f868e534df256,
            128'h3bd92268fc74fb735767cbe0c0590e2d);
        check_c_inverse_round(8,
            128'h3bd92268fc74fb735767cbe0c0590e2d,
            128'h3b59cb73fcd90ee05774222dc067fb68,
            128'h4915598f55e5d7a0daca94fa1f0a63f7,
            128'hb692cf0b643dbdf1be9bc5006830b3fe,
            128'hff87968431d86a51645151fa773ad009,
            128'ha7be1a6997ad739bd8c9ca451f618b61);
        check_c_inverse_round(9,
            128'ha7be1a6997ad739bd8c9ca451f618b61,
            128'ha761ca9b97be8b45d8ad1a611fc97369,
            128'h89d810e8855ace682d1843d8cb128fe4,
            128'hd6aa74fdd2af72fadaa678f1d6ab76fe,
            128'h5f72641557f5bc92f7be3b291db9f91a,
            128'h6353e08c0960e104cd70b751bacad0e7);
        check_c_inverse_round(10,
            128'h6353e08c0960e104cd70b751bacad0e7,
            128'h63cab7040953d051cd60e0e7ba70e18c,
            128'h00102030405060708090a0b0c0d0e0f0,
            128'h000102030405060708090a0b0c0d0e0f,
            128'h00112233445566778899aabbccddeeff,
            128'h00112233445566778899aabbccddeeff);

        if (checks != EXPECTED_CHECKS)
            $fatal(1, "FAIL incomplete test: %0d/%0d checks", checks, EXPECTED_CHECKS);
        $display("SEMANA_03_PASS checks=%0d", checks);
        $finish;
    end

    initial begin : watchdog
        #10000;
        $fatal(1, "FAIL testbench timeout");
    end
endmodule

`default_nettype wire
