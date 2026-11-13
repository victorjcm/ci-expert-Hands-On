# Semana 4 — Expansão de chave e datapath AES-128

**Entrega:** 13/11/2026. **Testes:** 12/11/2026. **Branch:** `w04-rtl-v1.0`.

## O que foi feito

| Entrega | Implementação |
| --- | --- |
| [minisoc_aes_key_exp](../../rtl/minisoc_aes/minisoc_aes_key_exp.sv) | Expansão AES-128 pré-computada, com banco K0..K10 e leitura por índice |
| [minisoc_aes_dp](../../rtl/minisoc_aes/minisoc_aes_dp.sv) | Cifra e inversa de um bloco de 128 bits, uma rodada por ciclo e controle `start/busy/done` |
| [Testbench da semana 4](../../tb/tb_minisoc_aes_semana_04.sv) e [Makefile](../../Makefile) | Verificação integrada e seleção das fontes e do top da semana 4 |

A expansão pré-computada armazena **1.408 bits de chaves** e permite começar
a decriptação por K10, reutilizando o banco entre blocos. O datapath reutiliza
as transformações anteriores e omite MixColumns/InvMixColumns na última rodada.

## Cobertura de testes

| Grupo | Verificações | Resultado |
| --- | ---: | --- |
| Controle das quatro expansões completas | 268 | PASS |
| K0..K10 das duas chaves, status e índices inválidos | 196 | PASS |
| Seis blocos: cifra/inversa de C.1 e B, mais recuperação após reset | 504 | PASS |
| Reset, abortos e rejeição de start sem chaves prontas | 297 | PASS |
| **Total** | **1.265** | **PASS** |

Os testes também verificam latência, ordem das chaves, pulso de `done`,
retenção do resultado, captura das entradas e descarte de `start` durante
`busy`. Cada direção é comparada independentemente com a FIPS-197 (2001).

Na execução dos testes, os resultados coincidiram com as referencias e a simulação ocorreu normalmente

```text
SEMANA_04_PASS checks=1265 expansoes=4 blocos=6
```

Evidências: [log completo](semana_04/make_run.txt) e
[captura do terminal](semana_04/figures/semana_04_make_run.png).

## Critérios de aceite

| Critério | Evidência e estado |
| --- | --- |
| Onze round keys AES-128 e escolha justificada | Banco pré-computado implementado; K0..K10 conferidas para as duas chaves |
| Cifra e decriptação conforme os vetores do padrão | C.1 e B com resultados iguais aos esperados nos dois sentidos |
| Interface de controle funcional | Testes de `start/busy/done`, latência e reset concluídos sem falhas |
| Lint sem erros | Análise com `+lint=all` sem erros ou avisos de lint reportados no log |

