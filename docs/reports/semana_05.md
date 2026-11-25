# Semana 5 — SPI front-end e PLL mock

**Estado em 23/11/2026:** RTL e testbench preparados e revisados por leitura. Lint, compilação e simulação **não executados**. Aceite funcional e relatório de resultados pendentes da execução pelo usuário.

## Arquivos preparados

| Arquivo | Conteúdo |
| --- | --- |
| [minisoc_spi.sv](../../rtl/minisoc_spi/minisoc_spi.sv) | SPI Mode 0, frame de 40 bits, mailboxes de comando/resposta e banco always-on |
| [minisoc_pll_mock.sv](../../rtl/minisoc_pll/minisoc_pll_mock.sv) | Divisores /1, /2, /4, /8, aquisição pseudoaleatória por LFSR e gate de saída |
| [tb_minisoc_semana_05.sv](../../tb/tb_minisoc_semana_05.sv) | Testes dirigidos de SPI, registradores, START, CDC lógico e PLL |
| [Makefile](../../Makefile) | Seleção da semana 5 e logs explícitos de análise, elaboração e simulação |

Os módulos AES anteriores foram preservados. O testbench conecta diretamente SPI e PLL. Os sinais de status AES são estímulos síncronos fornecidos pelo testbench; ainda não há engine, memória ou top-level integrado nesta entrega.

## Contrato implementado

- Frame MOSI: `{RWb, ADDR[5:0], RSV, DATA[31:0]}`, MSB-first; RWb=0 escreve e RWb=1 solicita leitura. RSV deve ser zero.
- Cada ativação de CS recebe um frame. Frame parcial é descartado; clocks após o 40º são ignorados até CS subir.
- Leitura usa READ request seguido de NOP, endereço `0x3F`. O NOP aceita RWb=0 ou 1 e DATA ignorado, com RSV=0.
- **Convenção local de resposta:** MISO retorna oito zeros nas primeiras oito subidas e DATA[31:0] nas 32 seguintes. Em escritas, solicitações de leitura, NOP sem resposta e repouso, retorna zero.
- O snapshot é obtido quando `clk` processa o READ request. O retorno não acompanha alterações posteriores do status.
- Um NOP consome a resposta na oitava descida de SCLK, quando ela é copiada para TX. Se for abortado depois disso, repita READ request e NOP. Abortá-lo antes desse ponto preserva a resposta.
- O fluxo suportado mantém um READ pendente por vez, seguido de NOP antes de outro READ. O handshake impede sobrescrever o mailbox ocupado; uma violação de capacidade gera `$fatal` na simulação. Não há fila de comandos nem pino de backpressure.
- Endereços desconhecidos retornam zero e ignoram escritas. RSV=1 é descartado. Escritas nos três registradores R são ignoradas.
- Registradores de configuração começam em zero. Reservados são lidos como zero. START é um pulso de um ciclo de `clk` e é lido como zero. VERSION é parâmetro, com valor local padrão `0x00010000`.
- NUM_BLOCKS mantém 32 bits. MODE/NUM_BLOCKS não são validados pelo front-end; a validação operacional do engine será integrada posteriormente.

A localização dos bits de retorno, o valor de VERSION e as políticas para acessos malformados são decisões locais porque o Block Guide não os fecha. Precisam ser compatibilizados com o verificador externo; não são apresentados como confirmação adicional do guia.

## Clocks, reset e PLL

O banco usa `clk` de 2 GHz, independente do PLL. RX usa subidas de `spi_sclk`; TX e captura da resposta usam descidas. O testbench utiliza SCLK de 25 MHz e 10 MHz, duty cycle de 50%, setup de MOSI de meio período e CS alto por meio período entre transações. Libera reset com SCLK baixo, CS alto e afastado das bordas de referência. Esses tempos são o contrato exercitado pelo testbench, não caracterização física dos pinos.

Comandos e respostas usam payload estável, toggle sincronizado por dois estágios e uma borda adicional para captura. CS não reinicializa os mailboxes. O reset global limpa os dois lados. A integração física ainda precisa tratar recovery/removal, liberação de reset e constraints de bundled-data/CDC.

Os status AES de entrada devem ser coerentes e síncronos a `clk`; o futuro bridge é responsável por isso. `i_pll_locked` passa por dois estágios antes de compor SYSTEM_STATUS. `o_start` pertence a `clk` e não deve ser ligado diretamente ao futuro domínio `sys_clk`.

O PLL usa LFSR de oito bits, seed padrão `0xA5`, e escolhe uma espera de 8..39 ciclos na aceitação de enable. O gate abre na primeira descida do clock selecionado após essa espera; portanto, o tempo total também inclui aceitação e alinhamento de fase. A seed zero é substituída por um.

O divisor é capturado no começo da aquisição. Mudanças enquanto habilitado ficam para a próxima aquisição. Use disable → configure → enable. Ao desabilitar, locked e gate caem na próxima descida do clock selecionado, em até um período (máximo 4 ns). Essa latência preserva o pulso alto em andamento. Reset global força zero imediatamente e pode interromper um pulso. O modelo não é uma macro PLL nem um fluxo de clock gating físico.

| Seletor | Divisor | Frequência/período esperados |
| --- | --- | --- |
| 00 | /1 | 2 GHz / 0,5 ns |
| 01 | /2 | 1 GHz / 1 ns |
| 10 | /4 | 500 MHz / 2 ns |
| 11 | /8 | 250 MHz / 4 ns |

## Cobertura preparada, ainda não executada

O testbench inclui leitura dos defaults dos 16 registradores; escrita/leitura dos 13 R/W; proteção dos três R; padrões zero, uns e palavras distintas; ordem de KEY/IV/COUNTER; NUM_BLOCKS=1/256; MODE/DECRYPT; START consecutivos e duração do pulso; bits reservados; snapshot de status; NOP nos dois valores de RWb; NOP parcial; frame parcial/excedente; RSV inválido; endereço desconhecido; SCLK parado/mais lento; reset de transferência; lock nos quatro divisores; períodos e larguras de pulso; disable/re-enable e reset com PLL ativo.

As comparações e timeouts geram `$fatal` em divergência. A mensagem de sucesso escrita no código só constitui evidência se aparecer em uma execução concluída do usuário, com os logs correspondentes. Não há resultado observado ou contagem de testes aprovados registrada aqui.

## Lint e execução — pendentes

| Etapa | Comando no ambiente VCS do usuário | Log previsto | Estado |
| --- | --- | --- | --- |
| Análise e lint | `make syntax` | `vlogan.log`, com `+lint=all` | Não executado |
| Elaboração | `make compile` | `vcs.log`, além da análise anterior | Não executado |
| Fluxo funcional completo | `make run` | `simv.log`, além dos logs anteriores | Não executado |

`make run` já inclui análise e elaboração. Não é necessário executar os três comandos em sequência. Para gerar waveform após a compilação, execute `./simv -l simv.log +waves`; o arquivo será `semana_05.vcd`. O alvo antigo `make wave` espera FSDB e não abre automaticamente esse VCD.

**Relatório de lint nesta revisão:** não há log da semana 5, quantidade de erros/avisos conhecida ou justificativas baseadas em mensagens reais. Após a execução, registrar versão da ferramenta, comando, revisão das fontes, cada mensagem com arquivo/linha, correção ou justificativa e resultado da nova análise quando necessária. Avisos sobre clocks derivados, resets ou atribuições não devem ser classificados como benignos sem examinar a mensagem concreta.

Fonte dos requisitos: [Block Guide v1.0.0](Resumos/DV_BlockGuide_MiniSoCAES_v1.0.0.pdf), seções 4.1, 5, 6 e passos 8–9 da seção 9, e enunciado da semana 5 fornecido pelo usuário.
