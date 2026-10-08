# Ci-Expert-HandsOn

Projeto de um acelerador AES com interface SPI e baixo consumo.

## Exemplo minimo da semana 1

O exemplo atual usa um **teste**, nao uma implementacao criptografica do AES.
Ele recebe entrada e chave de 128 bits e devolve `data_in ^ key`.

- `rtl/aes_teste.sv`: modulo sintetizavel de teste, com latencia configuravel.
- `tb/tb_aes_teste.sv`: testbench com verificacao automatica e timeout.

### Interface

| Sinal | Funcao |
| --- | --- |
| `clk` | Clock; as operacoes sao atualizadas na borda de subida. |
| `rst_n` | Reset assincrono ativo em zero; aborta a operacao e limpa as saidas. |
| `start` | Pulso de um ciclo para solicitar uma operacao quando `busy == 0`. |
| `data_in`, `key` | Valores capturados na borda de aceitacao de `start`. |
| `busy` | Indica processamento; pedidos recebidos nesse periodo sao ignorados. |
| `done` | Pulso de um ciclo que indica uma nova saida valida. |
| `data_out` | Resultado retido ate outra conclusao ou reset. |

O parametro `LATENCY` deve ser maior ou igual a 1 e vale 4 por padrao.
A conclusao ocorre quatro bordas de subida depois da aceitacao de `start`.
Um pedido na propria borda de conclusao ainda e ignorado, pois `busy` estava
ativo. Uma nova operacao pode ser aceita na borda seguinte. `start` deve ser
pulsado: mante-lo alto pode iniciar outra operacao quando o modulo voltar ao
estado ocioso.

### Executar com as ferramentas fornecidas

Pre-requisitos: ambiente Linux compativel com Synopsys VCS, GNU Make,
`vlogan` e `vcs` no `PATH`, e licenca configurada conforme o ambiente do curso.

Na raiz do repositorio:

```sh
make run
```

Esse comando analisa os fontes com `vlogan +lint=all`, elabora o testbench
com VCS e executa a simulacao. Caso a trilha exija uma ferramenta dedicada de
lint, sua configuracao ainda devera ser adicionada ao fluxo.

O resultado esperado e:

```text
PASS: tb_aes_teste - 8 testes concluidos
```

Qualquer divergencia ou timeout encerra o testbench com `$fatal(1, ...)`.
Os testes verificam o XOR, a latencia, a captura dos operandos, pedidos durante
`busy`, o pulso `done`, a retencao da saida, operacoes sucessivas e reset durante
processamento, seguido de recuperacao.

Para gerar uma forma de onda VCD depois da compilacao:

```sh
./simv +DUMP_VCD
```

O arquivo gerado e `waves.vcd`. O exemplo ainda nao integra SPI, memoria ou PLL
e nao valida as rodadas do AES real.
