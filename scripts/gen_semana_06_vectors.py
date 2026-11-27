#!/usr/bin/env python3
"""Gera os vetores da semana 6 usando somente a biblioteca padrão do Python.

Executar manualmente a partir da raiz: python3 scripts/gen_semana_06_vectors.py
O modelo trabalha com bytes e não lê tabelas, resultados ou código do RTL.
"""

from pathlib import Path


def gf_mul(a, b):
    """Multiplicação no corpo GF(2^8), com polinômio AES 0x11b."""
    result = 0
    for _ in range(8):
        if b & 1:
            result ^= a
        a = ((a << 1) ^ (0x11B if a & 0x80 else 0)) & 0xFF
        b >>= 1
    return result


def gf_pow(value, exponent):
    result = 1
    while exponent:
        if exponent & 1:
            result = gf_mul(result, value)
        value = gf_mul(value, value)
        exponent >>= 1
    return result


def rotate_byte(value, count):
    return ((value << count) | (value >> (8 - count))) & 0xFF


def make_sboxes():
    # A S-box vem da inversão multiplicativa e da transformação afim.
    direct = []
    inverse = [0] * 256
    for value in range(256):
        reciprocal = gf_pow(value, 254) if value else 0
        mapped = reciprocal ^ 0x63
        for shift in range(1, 5):
            mapped ^= rotate_byte(reciprocal, shift)
        direct.append(mapped)
        inverse[mapped] = value
    return direct, inverse


SBOX, INV_SBOX = make_sboxes()


def xor_bytes(left, right):
    if len(left) != len(right):
        raise ValueError("XOR exige operandos do mesmo tamanho")
    return bytes(a ^ b for a, b in zip(left, right))


def expand_key(key):
    if len(key) != 16:
        raise ValueError("A chave AES-128 precisa de 16 bytes")
    words = [list(key[index:index + 4]) for index in range(0, 16, 4)]
    rcon = 1
    for index in range(4, 44):
        temp = words[index - 1][:]
        if index % 4 == 0:
            temp = [SBOX[value] for value in temp[1:] + temp[:1]]
            temp[0] ^= rcon
            rcon = gf_mul(rcon, 2)
        words.append([a ^ b for a, b in zip(words[index - 4], temp)])
    return [bytes(sum(words[index:index + 4], [])) for index in range(0, 44, 4)]


def shift_rows(state, inverse=False):
    direction = -1 if inverse else 1
    return bytes(state[4 * ((column + direction * row) % 4) + row]
                 for column in range(4) for row in range(4))


def mix_columns(state, inverse=False):
    matrix = ((14, 11, 13, 9), (9, 14, 11, 13),
              (13, 9, 14, 11), (11, 13, 9, 14)) if inverse else (
                  (2, 3, 1, 1), (1, 2, 3, 1), (1, 1, 2, 3), (3, 1, 1, 2))
    result = []
    for column in range(4):
        values = state[column * 4:column * 4 + 4]
        for row in matrix:
            mixed = 0
            for coefficient, value in zip(row, values):
                mixed ^= gf_mul(coefficient, value)
            result.append(mixed)
    return bytes(result)


def aes_block(block, round_keys, decrypt=False):
    if len(block) != 16:
        raise ValueError("O bloco AES precisa de 16 bytes")
    state = xor_bytes(block, round_keys[10 if decrypt else 0])
    if decrypt:
        for index in range(9, -1, -1):
            state = shift_rows(state, inverse=True)
            state = bytes(INV_SBOX[value] for value in state)
            state = xor_bytes(state, round_keys[index])
            if index:
                state = mix_columns(state, inverse=True)
    else:
        for index in range(1, 11):
            state = bytes(SBOX[value] for value in state)
            state = shift_rows(state)
            if index != 10:
                state = mix_columns(state)
            state = xor_bytes(state, round_keys[index])
    return state


def process(blocks, key, iv, counter, mode, decrypt=False):
    if mode not in (0, 1, 5) or not 1 <= len(blocks) <= 256:
        raise ValueError("Configuração fora do escopo da semana 6")
    if len(iv) != 16 or not 0 <= counter < (1 << 64):
        raise ValueError("IV ou contador com largura inválida")
    keys = expand_key(key)
    chain = iv
    result = []
    for block in blocks:
        if mode == 0:
            output = aes_block(block, keys, decrypt)
        elif mode == 1:
            if decrypt:
                output = xor_bytes(aes_block(block, keys, True), chain)
                chain = block
            else:
                output = aes_block(xor_bytes(block, chain), keys)
                chain = output
        else:
            # O guia exige XOR, inclusive quando o IV tem bits baixos não nulos.
            stream_input = xor_bytes(iv, counter.to_bytes(16, "big"))
            output = xor_bytes(block, aes_block(stream_input, keys))
            counter = (counter + 1) & ((1 << 64) - 1)
        result.append(output)
    return result


def from_hex_blocks(text):
    return [bytes.fromhex(value) for value in text.split()]


NIST_PLAIN = from_hex_blocks("""
    6bc1bee22e409f96e93d7e117393172a ae2d8a571e03ac9c9eb76fac45af8e51
    30c81c46a35ce411e5fbc1191a0a52ef f69f2445df4f9b17ad2b417be66c3710
""")
NIST_KEY = bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
NIST_IV = bytes.fromhex("000102030405060708090a0b0c0d0e0f")


def check_equal(label, actual, expected):
    # Não usar assert: os testes conhecidos também devem rodar com python -O.
    if actual != expected:
        raise ValueError(f"Modelo de referência divergiu em {label}")


def known_answer_checks():
    """Âncoras independentes: FIPS-197 e NIST SP 800-38A, apêndice F."""
    fips_key = bytes.fromhex("000102030405060708090a0b0c0d0e0f")
    fips_plain = bytes.fromhex("00112233445566778899aabbccddeeff")
    fips_cipher = bytes.fromhex("69c4e0d86a7b0430d8cdb78070b4c55a")
    keys = expand_key(fips_key)
    check_equal("FIPS cifra", aes_block(fips_plain, keys), fips_cipher)
    check_equal("FIPS decriptação", aes_block(fips_cipher, keys, True), fips_plain)
    known = {
        0: from_hex_blocks("""
            3ad77bb40d7a3660a89ecaf32466ef97 f5d3d58503b9699de785895a96fdbaaf
            43b1cd7f598ece23881b00e3ed030688 7b0c785e27e8ad3f8223207104725dd4
        """),
        1: from_hex_blocks("""
            7649abac8119b246cee98e9b12e9197d 5086cb9b507219ee95db113a917678b2
            73bed6b8e3c1743b7116e69e22229516 3ff1caa1681fac09120eca307586e1a7
        """),
        5: from_hex_blocks("""
            874d6191b620e3261bef6864990db6ce 9806f66b7970fdff8617187bb9fffdff
            5ae4df3edbd5d35e5b4f09020db03eab 1e031dda2fbe03d1792170a0f3009cee
        """),
    }
    for mode, expected in known.items():
        # Este IV e contador reproduzem exatamente os quatro inputs do NIST.
        iv = bytes.fromhex("f0f1f2f3f4f5f6f70000000000000000") if mode == 5 else NIST_IV
        counter = 0xF8F9FAFBFCFDFEFF if mode == 5 else 0
        check_equal(f"NIST modo {mode} cifra",
                    process(NIST_PLAIN, NIST_KEY, iv, counter, mode), expected)
        check_equal(f"NIST modo {mode} decriptação",
                    process(expected, NIST_KEY, iv, counter, mode, True), NIST_PLAIN)


def make_cases():
    cases = []

    def add_pair(mode, plain, key, iv, counter):
        cipher = process(plain, key, iv, counter, mode)
        recovered = process(cipher, key, iv, counter, mode, True)
        check_equal("round-trip dos vetores", recovered, plain)
        cases.append((mode, 0, key, iv, counter, plain, cipher))
        cases.append((mode, 1, key, iv, counter, cipher, recovered))

    for mode in (0, 1, 5):
        for count in (1, 2, 256):
            plain = [NIST_PLAIN[index] if index < 4 else
                     bytes((17 * index + 29 * byte + (index >> 3)) & 0xFF
                           for byte in range(16)) for index in range(count)]
            # A capacidade máxima usa outra chave para conferir nova expansão.
            key = NIST_KEY if count < 256 else bytes(range(16))
            add_pair(mode, plain, key, NIST_IV, 0x0123456789ABCDFE)

    # Overflow de 64 bits e IV com metade baixa não nula, nos dois sentidos.
    add_pair(5, NIST_PLAIN[:2], NIST_KEY, NIST_IV, 0xFFFFFFFFFFFFFFFF)
    # Um caso FIPS explícito também chega ao DUT, além das âncoras do modelo.
    add_pair(0, [bytes.fromhex("00112233445566778899aabbccddeeff")],
             bytes(range(16)), bytes(16), 0)
    return cases


def main():
    known_answer_checks()
    cases = make_cases()
    lines = [str(len(cases))]
    for case_id, (mode, decrypt, key, iv, counter, inputs, outputs) in enumerate(cases):
        lines.append(f"{case_id} {mode} {decrypt} {len(inputs)} "
                     f"{key.hex()} {iv.hex()} {counter:016x}")
        lines.extend(f"{source.hex()} {expected.hex()}"
                     for source, expected in zip(inputs, outputs))
    destination = Path(__file__).resolve().parents[1] / "tb/vectors/semana_06/vectors.txt"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Vetores gerados: {destination} ({len(cases)} casos)")
    print("Âncoras FIPS/NIST conferidas pelo modelo; isso não executa nem aprova o RTL.")


if __name__ == "__main__":
    main()
