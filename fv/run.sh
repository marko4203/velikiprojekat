#!/bin/bash
# =====================================================================
#  Pokretanje UVM simulacije u Vivado xsim-u (komandna linija, Linux).
#  Upotreba: ./run.sh [MAP_FILE=... START_X=... END_X=... itd.]
# =====================================================================
set -e

# Korisnicki plusarg-ovi idu pre podrazumevanih ($value$plusargs uzima
# prvo poklapanje, pa korisnicka vrednost pregazi podrazumevanu).
EXTRA=()
for a in "$@"; do
    EXTRA+=(-testplusarg "$a")
done

# 1. VHDL izvori (DUT + memorijski harness)
xvhdl dut/pathfinder_ip.vhd \
      dut/pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd \
      dut/pathfinder_axi.vhd \
      dut/bram.vhd \
      dut/bram_router.vhd

# 2. SystemVerilog izvori (UVM okruzenje)
xvlog -sv -L uvm \
      -i verif -i verif/Agent -i verif/Configurations -i verif/Sequences \
      -f run.f

# 3. Elaboracija
xelab -L uvm -relax -timescale 1ns/1ps -debug typical \
      -s pathfinder_sim pathfinder_verif_top

# 4. Simulacija
xsim pathfinder_sim -R "${EXTRA[@]}" \
     -testplusarg "UVM_TESTNAME=test_simple" \
     -testplusarg "UVM_VERBOSITY=UVM_MEDIUM" \
     -testplusarg "MAP_FILE=bram_init.txt"
