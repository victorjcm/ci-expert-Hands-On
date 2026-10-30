# MiniSoC AES

Projeto orientado pelo **Block Guide do MiniSoC AES (v1.0.0)**.
O documento de referência está em
[`docs/spec/DV_BlockGuide_MiniSoCAES_v1.0.0.pdf`](docs/spec/DV_BlockGuide_MiniSoCAES_v1.0.0.pdf).
A Semana 2 implementa S-box, SubBytes e ShiftRows combinacionais. A integração
do MiniSoC e o restante do datapath ainda serão desenvolvidos.

## Estrutura do repositório

```text
.
├── README.md
├── docs/
│   ├── spec/             # Block Guide MiniSoC AES v1.0.0
│   ├── architecture/     # Microarquitetura e arquitetura de energia
│   └── reports/          # Relatórios semanais
├── rtl/
│   ├── minisoc_aes/      # minisoc_aes_top, minisoc_aes_dp, minisoc_aes_key_exp e submódulos
│   ├── minisoc_mem/      # minisoc_memory
│   ├── minisoc_pll/      # minisoc_pll_mock (modelo de integração)
│   ├── minisoc_spi/      # minisoc_spi
│   └── minisoc_top.sv    # Integração do MiniSoC
├── tb/                  # Testbenches e modelo de referência
├── formal/              # Scripts e relatórios do Formality
├── syn/                 # SDC, scripts e relatórios de síntese
├── upf/                 # Arquivos UPF e relatórios
└── scripts/             # Automação do fluxo
```

`rtl/minisoc_top.sv` é apenas um marcador, sem implementação ou interfaces.

## Estado da transição

O conteúdo anterior de `docs/reports/semana_02/` foi removido para a elaboração
de um novo relatório. Os materiais anteriores não definem os requisitos deste
projeto; a referência passa a ser o Block Guide v1.0.0.

O modelo de teste anterior e seu testbench foram removidos. A simulação atual
usa `tb_minisoc_aes_semana_02`, sem depender do futuro testbench do sistema.
A síntese continua configurada para `minisoc_top`, cuja implementação ainda
está pendente.

As pastas locais auxiliares `libs/`, `pessoal/` e `output/` foram preservadas;
não fazem parte da estrutura de blocos do MiniSoC.

## Simulação e síntese

Executar o `Makefile` a partir da raiz do repositório, com GNU Make e shell
POSIX no ambiente Synopsys. O arquivo mantém o padrão original, com listas
explícitas de fontes e chamadas diretas às ferramentas.
`make` ou `make syntax` analisa os fontes com `vlogan +lint=all`;
`make compile` executa essa análise e elabora o testbench com VCS;
`make run` executa toda a sequência e inicia `./simv`.

`RTL_FILES` lista os três módulos da Semana 2, `TB_FILES` lista o testbench e
`TOP` seleciona `tb_minisoc_aes_semana_02`. Novos fontes devem ser adicionados
explicitamente a essas listas. `PKG_FILES` está vazio nesta etapa.

`make synth` chama diretamente `dc_shell -f syn/synth.tcl`. O Tcl mantém o
padrão original: configuração, leitura explícita do RTL, `elaborate`, `link`,
constraints, verificação, relatórios, `compile_ultra` e exportação.
O topo é `minisoc_top` e a biblioteca é `saed32rvt_tt1v25c.db`, buscada em
`./libs`. Ajustes de biblioteca, fontes e topo são feitos diretamente no Tcl.
A biblioteca foi mantida da configuração anterior; a tecnologia alvo ainda
deverá ser confirmada para o novo projeto.

A síntese do sistema depende da implementação de `minisoc_top` e dos demais
blocos. A chamada `read_sdc syn/minisoc_top.sdc` permanece comentada, como no
padrão original; criar e habilitar o SDC antes de avaliar o timing.

As saídas de simulação ficam na raiz do repositório, como no fluxo original.
Relatórios de síntese ficam em `syn/reports/`; netlist e arquivos DDC ficam
diretamente em `syn/`, com o prefixo `minisoc_top`.
`clean_sim` remove apenas a simulação, e `clean_synth` remove apenas os
resultados e diretórios de trabalho da síntese. `make clean` executa ambos.

## Semana 2: execução manual

Os arquivos foram preparados **sem executar simulação ou lint**, conforme
solicitado. Resultados e aceite permanecem pendentes da execução manual.
O relatório está em [`docs/reports/semana_02.md`](docs/reports/semana_02.md).

No ambiente com GNU Make e Synopsys VCS/vlogan no PATH, um único comando
executa análise com `+lint=all`, compilação e o testbench autoverificável:

```sh
make run
```

Para executar apenas a análise de sintaxe e lint, usar `make syntax`.

O testbench prevê 903 comparações: S-box nas 256 entradas; SubBytes com todos os
valores em cada uma das 16 posições; permutação de bytes e de bits do ShiftRows;
cadeia SubBytes → ShiftRows; e vetores fixos das rodadas 1 e 10 do Apêndice B da
FIPS-197 (2001). Uma falha encerra a simulação com `$fatal(1, ...)`.

O sucesso deverá produzir `SEMANA_02_PASS checks=903` na saída do testbench.
Esse marcador é um **resultado esperado**, não o resultado de uma execução
já realizada. O Make interrompe o fluxo se uma ferramenta retornar erro;
o aceite também exige conferir o marcador de conclusão e as mensagens do lint.
