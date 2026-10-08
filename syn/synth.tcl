# ============================================================
# Script de Síntese
# ============================================================

# ------------------------------------------------------------
# Carregar configuração
# ------------------------------------------------------------

source syn/.synopsys_dc.setup

# ------------------------------------------------------------
# Ler RTL
# ------------------------------------------------------------


# ------------------------------------------------------------
# Elaborar
# ------------------------------------------------------------

elaborate 

link

# ------------------------------------------------------------
# Constraints
# ------------------------------------------------------------

read_sdc syn/vending.sdc

# ------------------------------------------------------------
# Verificação do design
# ------------------------------------------------------------

puts "\n=================================================="
puts "CHECK DESIGN"
puts "=================================================="

file mkdir syn/reports
redirect syn/reports/check_design.rpt {
  check_design
}

# ------------------------------------------------------------
# Relatórios pré-síntese
# ------------------------------------------------------------

file mkdir syn/reports

redirect syn/reports/area_pre.rpt {
  report_area -hierarchy
}

redirect syn/reports/timing_pre.rpt {
  report_timing -max_paths 10
}

# ------------------------------------------------------------
# Síntese
# ------------------------------------------------------------

puts "\n=================================================="
puts "INICIANDO SÍNTESE"
puts "=================================================="

compile_ultra -no_autoungroup

# ------------------------------------------------------------
# Relatórios pós-síntese
# ------------------------------------------------------------

file mkdir syn/reports

redirect syn/reports/area_pos.rpt {
  report_area -hierarchy
}

redirect syn/reports/timing_relatorio.rpt {
  report_timing -max_paths 10
}

redirect syn/reports/power.rpt {
  report_power
}

redirect syn/reports/setup_violations.rpt {
  report_constraint -all_violators
}

# ------------------------------------------------------------
# Exportar netlist
# ------------------------------------------------------------

write -format verilog -hierarchy -output syn/vending_top_syn.v

write -format ddc -hierarchy -output syn/vending_top_syn.ddc

# ------------------------------------------------------------
# Salvar sessão do DC
# ------------------------------------------------------------

write_file -format ddc -hierarchy -output syn/vending_top.ddc

puts "\n=================================================="
puts "SÍNTESE CONCLUÍDA"
puts "=================================================="
puts "Arquivos gerados:"
puts "  syn/reports/area_pos.rpt"
puts "  syn/reports/timing_relatorio.rpt"
puts "  syn/reports/power.rpt"
puts "  syn/reports/setup_violations.rpt"
puts "  syn/vending_top_syn.v"
puts "  syn/vending_top_syn.ddc"
puts "=================================================="
