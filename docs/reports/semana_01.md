# Semana 1 — Estudo e preparação do ambiente

## O que foi feito

- Estudo do algoritmo AES, do protocolo SPI e da arquitetura AES Top Level.
- Organização do material de estudo em [Resumo_AES_SPI.pdf](Resumos/Resumo_AES_SPI.pdf).
- Preparação do repositório.
- Criação do backlog inicial.
- Execução do ambiente com teste: aes_teste.sv.

## Resultados obtidos

- Repositório montado corretamente.
- Fontes RTL, testbench e scripts preparados para execução.
- Resumo de estudo separado do relatório semanal.
- O testbench prevê oito testes e encerra com erro em caso de divergência ou timeout.
- Ambiente executando compilação, lint e simulação perfeitamente através do Makefile.



## Problemas encontrados

- Nenhum problema de infraestrutura encontrado até o momento, apenas o estudo do material e organização foi realizado

## Próximos passos

- Definição do diagrama de blocos e das interfaces internas entre os módulos, a partir da arquitetura do sistema de topo.
- Detalhamento das interfaces de topo (GLOBAL RESET, clk from OSC, SPI IF e MEMORY DATA IF) conforme a especificação do sistema de topo.
- Definição do mapa de registradores.
- Definir estratégias e interfaces