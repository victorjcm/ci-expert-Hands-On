# Semana 3 — Microarquitetura e transformações de rodada

**Entrega:** 06/11/2026.

**Branch:** `w03-rtl-v1.0`

**Estado:** simulação executada pelo usuário, com 48 comparações aprovadas;
lint executado com 11 avisos no testbench; aceite do instrutor pendente.

## Material elaborado

A [microarquitetura v1.0](../architecture/microarquitetura_v1.0.md) descreve
blocos internos, rodada iterativa, expansão proposta, FSM, seis modos,
CDC por toggle e reset após lock do PLL. 

| Módulo em `rtl/minisoc_aes/` | Estado nesta semana |
| --- | --- |
| `minisoc_aes_sbox`, `minisoc_aes_sub_bytes`, `minisoc_aes_shift_rows` | Mantidos da semana 2 |
| `minisoc_aes_mix_columns` | Novo: quatro colunas em paralelo, multiplicações por 02/03 |
| `minisoc_aes_add_round_key` | Novo: XOR de estado e chave de 128 bits |
| `minisoc_aes_inv_sbox` | Novo: transformação afim inversa e inversão algébrica em GF(2⁸) |
| `minisoc_aes_inv_sub_bytes` | Novo: 16 InvSbox independentes |
| `minisoc_aes_inv_shift_rows` | Novo: permutação estática inversa |
| `minisoc_aes_inv_mix_columns` | Novo: pré-correção seguida de MixColumns |

Todos são combinacionais. As transformações de estado usam `i_state[127:0]`
e `o_state[127:0]`; AddRoundKey acrescenta `i_round_key[127:0]`.
Os módulos S-box de um byte usam `i_byte[7:0]`/`o_byte[7:0]`.

Mantém-se a serialização por colunas:
byte `n` em `[127-8*n -: 8]`.

## Cobertura de testes

Testbench: `tb/tb_minisoc_aes_semana_03.sv`. Os valores de entrada, chaves
de rodada e saídas esperadas estão declarados no próprio testbench.

| Grupo | Comparações executadas | Situação |
| --- | ---: | --- |
| B: AddRoundKey inicial e transformações isoladas das rodadas 1 e 10 | 8 | PASS |
| C.1: AddRoundKey inicial e transformações isoladas das dez rodadas inversas | 40 | PASS |
| **Total** | **48** | **PASS** |

Os vetores seguem a **FIPS-197 de 2001**. Em B, comparam-se SubBytes,
ShiftRows, MixColumns e AddRoundKey na rodada 1; na rodada 10, não se aplica
MixColumns. As rodadas 2–9 de B não são cobertas individualmente.
Em C.1, comparam-se InvShiftRows, InvSubBytes, AddRoundKey e InvMixColumns
nas dez rodadas de **INVERSE CIPHER**, omitindo InvMixColumns na última.
Cada módulo recebe diretamente o valor intermediário publicado, sem
depender da saída calculada por outro módulo.

As S-boxes são exercitadas pelas instâncias de SubBytes/InvSubBytes.
O testbench não contém modelo genérico, varreduras exaustivas ou composição
de um cifrador completo. Falhas de comparação e timeout usam `$fatal(1, ...)`.
Na execução realizada pelo usuário em **06/11/2026**, o VCS
**X-2025.06-SP2_Full64** apresentou `SEMANA_03_PASS checks=48`.
A simulação encerrou normalmente com `$finish`, em **48000 ps (48 ns)**,
conforme o print fornecido pelo usuário.

O log de lint fornecido apresenta **11 avisos `Lint-[NS]` (Null statement)**,
todos em `tb/tb_minisoc_aes_semana_03.sv`: dez referentes a `#1;`, usados
para aguardar a estabilização combinacional, e um referente a `#10000;`,
usado pelo watchdog de timeout. Não há erros nem avisos nos módulos RTL
no trecho apresentado. Os avisos do testbench permanecem na versão executada;
o resultado não deve ser descrito como lint sem avisos.

| Vetor | Entrada | Chave | Saída esperada |
| --- | --- | --- | --- |
| B, cifra | `3243f6a8885a308d313198a2e0370734` | `2b7e151628aed2a6abf7158809cf4f3c` | `3925841d02dc09fbdc118597196a0b32` |
| C.1, inversa | `69c4e0d86a7b0430d8cdb78070b4c55a` | `000102030405060708090a0b0c0d0e0f` | `00112233445566778899aabbccddeeff` |

Exemplo de MixColumns (B, rodada 1):

```text
Entrada: d4bf5d30e0b452aeb84111f11e2798e5
Saída:   046681e5e0cb199a48f8d37a2806264c
```

Exemplo de InvMixColumns (C.1, rodada inversa 1):

```text
Entrada: e9f74eec023020f61bf2ccf2353c21c7
Saída:   54d990a16ba09ab596bbf40ea111702f
```

Os testes verificam as transformações isoladas com chaves fixas. Expansão
de chave, engine integrado, clocks, reset, CDC, modos e memória ainda não
têm DUT nesta entrega; a microarquitetura descreve a integração proposta.


## Critérios de aceite

| Critério | Evidência | Estado |
| --- | --- | --- |
| Microarquitetura v1.0 | Documento em `docs/architecture/` | Preparado, aprovação pendente |
| RTL direto e inverso | Nove módulos combinacionais exercitados pelo testbench | Aprovado nas comparações cobertas |
| Intermediários B e C.1 | Print da execução: `SEMANA_03_PASS checks=48` | 48 comparações aprovadas |
| Lint sem erros | Log de lint fornecido pelo usuário | Sem erros no trecho apresentado; 11 avisos `Lint-[NS]` no testbench |


Referências: Block Guide v1.0.0, seções 4.2, 5.3, 6–8 e 10;
[NIST FIPS-197 (2001)](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf),
seções 5.1/5.3, Figura 7 e Apêndices A.1, B e C.1.
