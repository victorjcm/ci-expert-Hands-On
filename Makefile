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

RTL_FILES = $(RTL_DIR)/aes_teste.sv

TB_FILES = $(TB_DIR)/tb_aes_teste.sv

# ==========================================
# Top do testbench
# ==========================================
TOP = tb_aes_teste

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
synth:
	dc_shell -f $(SYN_DIR)/synth.tcl

# ==========================================
# Limpeza da síntese
# ==========================================
clean_synth:
	rm -rf \
		./vending_top.ddc \
		./alib-52 \
		./default.svf \
		./work* \
		$(SYN_DIR)/*.rpt \
		$(SYN_DIR)/*.ddc \
		$(SYN_DIR)/*.db \
		$(SYN_DIR)/*_syn.v

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
		*.log

# ==========================================
# Limpeza total
# ==========================================
clean: clean_sim clean_synth

.PHONY: syntax compile run wave synth clean clean_sim clean_synth
