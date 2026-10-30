# ==========================================
# Diretórios
# ==========================================
RTL_DIR   = rtl
TB_DIR    = tb
SYN_DIR   = syn

# ==========================================
# Arquivos
# ==========================================
PKG_FILES =

RTL_FILES = $(RTL_DIR)/minisoc_aes/minisoc_aes_sbox.sv \
			$(RTL_DIR)/minisoc_aes/minisoc_aes_sub_bytes.sv \
			$(RTL_DIR)/minisoc_aes/minisoc_aes_shift_rows.sv

TB_FILES = $(TB_DIR)/tb_minisoc_aes_semana_02.sv

# ==========================================
# Top do testbench
# ==========================================
TOP = tb_minisoc_aes_semana_02

# ==========================================
# Flags
# ==========================================
TIMESCALE = 1ns/1ps

VLOGAN_FLAGS = -full64 \
			   -sverilog \
			   -kdb \
			   +lint=all

VCS_FLAGS = -full64 \
			-timescale=$(TIMESCALE) \
			-debug_access+all \
			-kdb

# ==========================================
# Verificação de sintaxe
# ==========================================
syntax:
	vlogan $(VLOGAN_FLAGS) \
		$(PKG_FILES) \
		$(RTL_FILES) \
		$(TB_FILES)

# ==========================================
# Compilação / Elaboração
# ==========================================
compile: syntax
	vcs $(VCS_FLAGS) -top $(TOP)

# ==========================================
# Simulação
# ==========================================
run: compile
	./simv

# ==========================================
# Abrir waveform
# ==========================================
wave:
	verdi -ssf waves.fsdb &

# ==========================================
# Síntese
# ==========================================
# O Tcl usa minisoc_top; a integração e o SDC ainda estão pendentes.
synth:
	dc_shell -f $(SYN_DIR)/synth.tcl

# ==========================================
# Limpeza da síntese
# ==========================================
clean_synth:
	rm -rf \
		./alib-52 \
		./work \
		./WORK \
		$(SYN_DIR)/reports \
		$(SYN_DIR)/output \
		$(SYN_DIR)/work \
		$(SYN_DIR)/alib
	rm -f \
		default.svf \
		$(SYN_DIR)/minisoc_top_syn.v \
		$(SYN_DIR)/minisoc_top_syn.ddc \
		$(SYN_DIR)/minisoc_top.ddc \
		command.log \
		filenames.log \
		$(SYN_DIR)/command.log \
		$(SYN_DIR)/filenames.log

# ==========================================
# Limpeza da simulação
# ==========================================
clean_sim:
	rm -rf \
		csrc \
		simv* \
		*.daidir \
		novas* \
		AN.DB \
		ucli.key \
		verdi* \
		DVEfiles \
		.vlogan* \
		*.fsdb \
		vlogan.log \
		vcs.log \
		simv.log

# ==========================================
# Limpeza total
# ==========================================
clean: clean_sim clean_synth

.PHONY: syntax compile run wave synth clean clean_sim clean_synth
