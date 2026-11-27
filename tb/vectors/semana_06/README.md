# Vetores da semana 6

O arquivo `vectors.txt` será gerado **manualmente pelo usuário**, a partir da raiz:

```bash
python3 scripts/gen_semana_06_vectors.py
```

O assistente preparou o gerador, mas não o executou. Não há vetores gerados
nem resultado do modelo ou do RTL registrado nesta entrega. O gerador usa
somente a biblioteca padrão do Python 3.6 ou posterior, sem instalação de pacotes.

Antes de escrever o arquivo, o modelo compara cifra e decriptação com valores
fixos da FIPS-197 e do NIST SP 800-38A (apêndices F.1, F.2 e F.5). Uma divergência
interrompe a geração. Depois prepara 22 casos: ECB/CBC/CTR × 1/2/256 blocos ×
cifra/decriptação, dois casos CTR com overflow de 64 bits e dois casos ECB FIPS.

Formato textual consumido por `tb_minisoc_semana_06.sv`:

```text
quantidade_de_casos_decimal
id_decimal mode_decimal decrypt_decimal num_blocks_decimal key_hex iv_hex counter_hex
bloco_entrada_hex bloco_esperado_hex
... uma linha por bloco, seguida do cabeçalho do próximo caso ...
```

Chave, IV e blocos têm 32 dígitos hexadecimais; contador tem 16. O Word 0 é
sempre o grupo de oito dígitos mais à esquerda. Não há padding ou troca de bytes.
Os arquivos são determinísticos; repetições da geração sobrescrevem `vectors.txt`.
Esse arquivo não é ignorado pelo Git e pode ser incluído na entrega após a geração.

O TB não calcula AES para produzir o esperado: lê esses pares e compara as
escritas e o readback da memória. Também confere as palavras fora da região
processada. Para usar outro local após compilar:

```bash
./simv -l simv.log +vectors=/caminho/absoluto/vectors.txt
```

O modo CTR da especificação utiliza `AES(IV XOR zero_extend(counter))` e soma
módulo 2^64. Os casos usam a metade baixa do IV diferente de zero para detectar
implementações que substituam esse XOR por concatenação ou soma.

PCBC, CFB e OFB ficam para a semana 10. Na semana 6, o TB espera rejeição por
ERROR e nenhuma escrita para esses códigos, além dos modos reservados 6 e 7.
Essa limitação deve acompanhar a entrega ao verificador parceiro e o relatório
semanal futuro; nenhuma comunicação externa foi feita pelo assistente.
