# Plano de desenvolvimento — Semana 4

**Escopo:** expansão de chave e datapath AES-128; entrega prevista para 13/11/2026.
Este documento é o plano técnico e roteiro de testes, não o relatório da semana.
Simulação, lint, compilação e demais execuções ficam a cargo do usuário.

## 1. Sequência de desenvolvimento

1. Implementar `rtl/minisoc_aes/minisoc_aes_key_exp.sv`: capturar a chave,
   gerar K1..K10 com RotWord, SubWord e Rcon e disponibilizar K0..K10 por índice.
2. Implementar `rtl/minisoc_aes/minisoc_aes_dp.sv`: AddRoundKey inicial e dez
   rodadas, reutilizando as transformações combinacionais da semana 3.
3. Preparar `tb/tb_minisoc_aes_semana_04.sv`: comparar as round keys e os
   blocos com referências fixas da FIPS-197, além do controle sequencial.
4. Atualizar as fontes e o top padrão do Makefile para a semana 4.
5. Revisar o código por leitura e entregar os comandos para execução manual.
   Elaborar o relatório somente depois dos resultados fornecidos pelo usuário.

## 2. Decisões de implementação

### Expansão pré-computada

A escolha segue a microarquitetura v1.0: banco de **11 × 128 = 1.408 bits**,
com K0 capturada na aceitação de `start` e uma nova round key por ciclo,
durante dez ciclos. Quatro instâncias da S-box direta calculam SubWord.
O banco tem uma porta combinacional de leitura, selecionada pelo datapath.

O custo é o armazenamento das onze chaves, os muxes de leitura e a lógica de
expansão. Uma alternativa on-the-fly reduziria armazenamento, mas a inversa
precisa começar por K10: seria necessário chegar até ela e depois gerar as
chaves anteriores, ou armazená-las. O banco permite reutilizar a mesma chave
em vários blocos e alternar cifra/inversa sem nova expansão. Os 1.408 bits
são uma contagem lógica do banco, não uma medição de área de síntese.

### Datapath iterativo

Estado de 128 bits e contador de rodada, com uma rodada por ciclo:

| Etapa | Cifra | Inversa convencional |
| --- | --- | --- |
| Aceitação | Entrada XOR K0 | Entrada XOR K10 |
| Rodadas 1..9 | SubBytes → ShiftRows → MixColumns → XOR Kr | InvShiftRows → InvSubBytes → XOR K(10-r) → InvMixColumns |
| Rodada 10 | SubBytes → ShiftRows → XOR K10 | InvShiftRows → InvSubBytes → XOR K0 |

A inversa usa as chaves originais, sem aplicar InvMixColumns ao banco.
Os caminhos direto/inverso compartilham AddRoundKey. A convenção de bytes
continua sendo `state[127-8*n -: 8] = s[n%4][n/4]`.
Uma rodada por ciclo é a latência funcional prevista; não comprova timing.

## 3. Interfaces e contrato

Ambos os módulos usam `clk` e `rst_n`, com reset assíncrono ativo em zero.
Na integração, a liberação de reset deverá ser sincronizada ao clock local.

| Módulo | Entradas | Saídas |
| --- | --- | --- |
| `minisoc_aes_key_exp` | `clk`, `rst_n`, `i_start`, `i_key[127:0]`, `i_round_index[3:0]` | `o_busy`, `o_done`, `o_keys_ready`, `o_round_key[127:0]` |
| `minisoc_aes_dp` | `clk`, `rst_n`, `i_start`, `i_block[127:0]`, `i_decrypt_primitive`, `i_keys_ready`, `i_round_key[127:0]` | `o_busy`, `o_done`, `o_result[127:0]`, `o_round_index[3:0]` |

- Expansão aceita `i_start` somente ociosa. O start aceito invalida
  `o_keys_ready`; a conclusão registra K10, afirma ready e pulsa done.
- Datapath aceita `i_start` somente ocioso e com `i_keys_ready=1`.
  Bloco e direção são amostrados na aceitação. Starts durante busy são
  ignorados, inclusive na borda da última rodada; não há fila de pedidos.
- `i_start` deve ser um pulso de um ciclo. Um sinal mantido alto poderá
  ser aceito novamente quando o módulo voltar a ficar ocioso.
- `o_keys_ready` permanece alto até outro start da expansão ou reset.
  Antes disso, a leitura retorna zero. Índices de leitura 11..15 retornam zero.
- Ligar `dp.o_round_index` a `key_exp.i_round_index`, `key_exp.o_round_key`
  a `dp.i_round_key` e `key_exp.o_keys_ready` a `dp.i_keys_ready`.
  A seleção inicial usa a direção de entrada; durante busy usa a direção
  capturada e o contador interno, sem depender de mudanças nas entradas.
- O controlador futuro deve impedir nova expansão enquanto o datapath
  estiver ocupado e manter o banco válido durante todo o bloco. Não há
  arbitragem entre pedidos independentes de expansão/datapath nestes módulos.
- `o_result` é zerado no reset e no start aceito; recebe o resultado na
  conclusão e o mantém até o próximo start aceito/reset.
- Reset aborta a operação, limpa busy/done/resultado e invalida/zera as chaves.
  Uma nova operação requer nova expansão e novo start.

### Contagem de ciclos

Considere E0 como a borda que aceita o start de cada módulo:

| Borda | Expansão | Datapath |
| --- | --- | --- |
| E0 | Registra K0; busy=1, ready=0, done=0 | Registra AddRoundKey inicial; busy=1, done=0 |
| E1..E9 | Registra K1..K9 | Registra rodadas 1..9 |
| E10 | Registra K10; busy=0, ready=1, done=1 | Registra rodada 10/resultado; busy=0, done=1 |
| E11 | Limpa done; pode aceitar outro start | Limpa done; pode aceitar outro start |

São onze atualizações contando E0 e dez períodos de clock entre aceitação e
conclusão. O consumidor síncrono observa done/ready na borda seguinte à sua
afirmação. Não iniciar o datapath na borda que ainda está registrando K10.

## 4. Testbench e critérios para a execução manual

Referências: **FIPS-197 (2001)**, Apêndices A.1 (expansão da chave de B),
B e C.1. As referências ficam no testbench; não há modelo AES genérico.

| Vetor | Chave | Plaintext | Ciphertext |
| --- | --- | --- | --- |
| C.1 | `000102030405060708090a0b0c0d0e0f` | `00112233445566778899aabbccddeeff` | `69c4e0d86a7b0430d8cdb78070b4c55a` |
| B | `2b7e151628aed2a6abf7158809cf4f3c` | `3243f6a8885a308d313198a2e0370734` | `3925841d02dc09fbdc118597196a0b32` |

Verificações previstas:

- K0..K10 contra constantes para ambas as chaves, incluindo substituição
  do banco e leitura fora da faixa.
- Cifra e inversa de ambos os vetores, alimentando a inversa com o ciphertext
  publicado; cada direção é comparada independentemente com a FIPS.
- Reutilização das chaves entre blocos e alternância de direção.
- Latência E0..E10, índices K0..K10/K10..K0, busy e pulso de done.
- Entradas alteradas após aceitação e start espúrio durante busy,
  inclusive na borda de conclusão; resultado estável quando ocioso.
- Start rejeitado antes de as chaves estarem prontas, inclusive durante expansão.
- Reset ocioso, durante expansão e durante datapath; recuperação com nova chave.
- Watchdog e `$fatal` para falhas; marcador final de sucesso somente se o
  fluxo completo de verificações terminar sem divergências.

## 5. Comandos para o usuário

Na raiz do repositório, no ambiente já utilizado com VCS:

```sh
# Análise de sintaxe/lint, se desejar executar esta etapa isoladamente.
make syntax

# Inclui análise, compilação/elaboração e simulação.
make run
```

O top padrão será `tb_minisoc_aes_semana_04`. O resultado **esperado**, ainda
não observado, é a conclusão das comparações com `SEMANA_04_PASS` e ausência
de erros de lint. Guardar o log completo, incluindo eventuais avisos, para
avaliarmos o aceite e redigirmos o relatório após os testes manuais.

Não fazem parte desta entrega: engine, modos de operação, SPI, memória, PLL,
CDC, síntese, medições de área/timing ou relatório da semana 4.
