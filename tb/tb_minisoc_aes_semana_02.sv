`timescale 1ns/1ps
`default_nettype none

module tb_minisoc_aes_semana_02;
    logic [7:0] byte_in;
    wire [7:0] byte_out;
    logic [127:0] state_in;
    wire [127:0] sub_out;
    wire [127:0] chain_out;
    logic [127:0] shift_in;
    wire [127:0] shift_out;
    int unsigned checks = 0;

    // Independent reference: FIPS-197 (2001), Figure 7, rows 0..f.
    // RTL uses GF arithmetic and does not import this lookup table.
    localparam logic [2047:0] SBOX_REFERENCE = {
        128'h637c777bf26b6fc53001672bfed7ab76,
        128'hca82c97dfa5947f0add4a2af9ca472c0,
        128'hb7fd9326363ff7cc34a5e5f171d83115,
        128'h04c723c31896059a071280e2eb27b275,
        128'h09832c1a1b6e5aa0523bd6b329e32f84,
        128'h53d100ed20fcb15b6acbbe394a4c58cf,
        128'hd0efaafb434d338545f9027f503c9fa8,
        128'h51a3408f929d38f5bcb6da2110fff3d2,
        128'hcd0c13ec5f974417c4a77e3d645d1973,
        128'h60814fdc222a908846eeb814de5e0bdb,
        128'he0323a0a4906245cc2d3ac629195e479,
        128'he7c8376d8dd54ea96c56f4ea657aae08,
        128'hba78252e1ca6b4c6e8dd741f4bbd8b8a,
        128'h703eb5664803f60e613557b986c11d9e,
        128'he1f8981169d98e949b1e87e9ce5528df,
        128'h8ca1890dbfe6426841992d0fb054bb16
    };

    minisoc_aes_sbox u_sbox (.i_byte(byte_in), .o_byte(byte_out));
    minisoc_aes_sub_bytes u_sub_bytes (.i_state(state_in), .o_state(sub_out));
    minisoc_aes_shift_rows u_shift_rows (.i_state(shift_in), .o_state(shift_out));
    minisoc_aes_shift_rows u_chain (.i_state(sub_out), .o_state(chain_out));

    function automatic logic [7:0] ref_sbox(input logic [7:0] value);
        ref_sbox = SBOX_REFERENCE[2047 - 8*int'(value) -: 8];
    endfunction

    function automatic logic [127:0] ref_sub_bytes(input logic [127:0] value);
        for (int n = 0; n < 16; n++) begin
            ref_sub_bytes[127 - 8*n -: 8] = ref_sbox(value[127 - 8*n -: 8]);
        end
    endfunction

    // Matrix-based reference, separate from the explicit RTL concatenation.
    function automatic logic [127:0] ref_shift_rows(input logic [127:0] value);
        for (int row = 0; row < 4; row++) begin
            for (int col = 0; col < 4; col++) begin
                ref_shift_rows[127 - 8*(4*col + row) -: 8] =
                    value[127 - 8*(4*((col + row) % 4) + row) -: 8];
            end
        end
    endfunction

    task automatic check_state(
        input string label_text,
        input logic [127:0] actual,
        input logic [127:0] expected
    );
        if (actual !== expected) begin
            $fatal(1, "FAIL %s: expected=%032h actual=%032h", label_text, expected, actual);
        end
        checks++;
    endtask

    task automatic check_round(
        input int round_number,
        input logic [127:0] start_state,
        input logic [127:0] after_sub_bytes,
        input logic [127:0] after_shift_rows
    );
        state_in = start_state;
        // Isolated ShiftRows uses the published state, not the DUT SubBytes.
        shift_in = after_sub_bytes;
        #1;
        check_state($sformatf("round %0d SubBytes", round_number), sub_out, after_sub_bytes);
        check_state($sformatf("round %0d ShiftRows", round_number), shift_out, after_shift_rows);
        check_state($sformatf("round %0d chain", round_number), chain_out, after_shift_rows);
        $display("PASS FIPS-197 Appendix B round %0d", round_number);
    endtask

    initial begin : stimulus
        logic [127:0] expected_sub;
        byte_in = '0;
        state_in = '0;
        shift_in = '0;

        for (int value = 0; value < 256; value++) begin
            byte_in = 8'(value);
            #1;
            if (byte_out !== ref_sbox(byte_in)) begin
                $fatal(1, "FAIL S-box[%02h]: expected=%02h actual=%02h",
                       byte_in, ref_sbox(byte_in), byte_out);
            end
            checks++;
        end
        $display("PASS S-box: 256/256 inputs (includes 00->63 and 53->ed)");

        // Every lane receives every byte value, with unequal adjacent lanes.
        // This also detects duplicated, swapped or unconnected S-box lanes.
        for (int value = 0; value < 256; value++) begin
            for (int lane = 0; lane < 16; lane++) begin
                state_in[127 - 8*lane -: 8] = 8'(value + lane);
            end
            expected_sub = ref_sub_bytes(state_in);
            #1;
            check_state($sformatf("SubBytes sweep %0d", value), sub_out, expected_sub);
            check_state($sformatf("chain sweep %0d", value), chain_out,
                        ref_shift_rows(expected_sub));
        end
        $display("PASS SubBytes: 256 states, all 256 values in each of 16 lanes");
        $display("PASS SubBytes -> ShiftRows: 256 states");

        shift_in = 128'h000102030405060708090a0b0c0d0e0f;
        #1;
        check_state("ShiftRows tagged bytes", shift_out,
                    128'h00050a0f04090e03080d02070c01060b);
        // Every input bit is exercised independently to check the wiring.
        for (int bit_index = 0; bit_index < 128; bit_index++) begin
            shift_in = 128'h1 << bit_index;
            #1;
            check_state($sformatf("ShiftRows one-hot %0d", bit_index), shift_out,
                        ref_shift_rows(shift_in));
        end
        $display("PASS ShiftRows: tagged bytes and 128 one-hot inputs");

        // FIPS-197 (2001), Appendix B, printed pages 33-34.
        // Plaintext 3243f6a8885a308d313198a2e0370734;
        // key       2b7e151628aed2a6abf7158809cf4f3c.
        check_round(1,
            128'h193de3bea0f4e22b9ac68d2ae9f84808,
            128'hd42711aee0bf98f1b8b45de51e415230,
            128'hd4bf5d30e0b452aeb84111f11e2798e5);
        check_round(10,
            128'heb40f21e592e38848ba113e71bc342d2,
            128'he9098972cb31075f3d327d94af2e2cb5,
            128'he9317db5cb322c723d2e895faf090794);

        if (checks != 903) $fatal(1, "FAIL incomplete test: %0d/903 checks", checks);
        $display("SEMANA_02_PASS checks=%0d", checks);
        $finish;
    end

    initial begin : watchdog
        #10000;
        $fatal(1, "FAIL testbench timeout");
    end
endmodule

`default_nettype wire
