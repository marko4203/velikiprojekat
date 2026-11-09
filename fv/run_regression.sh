#!/bin/bash
# =====================================================================
#  Regresioni testovi (Linux): test_scoreboard nad svim mapama iz maps/.
#  Mape ciji naziv pocinje sa "unsolvable" testiraju se sa ocekivanjem
#  da putanja ne postoji. Logovi: regr_logs/<mapa>.log + summary.txt
# =====================================================================
set -e

ls maps/*.txt > /dev/null 2>&1 || { echo "GRESKA: folder maps/ ne postoji ili je prazan."; exit 1; }

# 1. Kompajliranje i elaboracija (jednom)
xvhdl dut/pathfinder_ip.vhd \
      dut/pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd \
      dut/pathfinder_axi.vhd \
      dut/bram.vhd \
      dut/bram_router.vhd
xvlog -sv -L uvm \
      -i verif -i verif/Agent -i verif/Configurations -i verif/Sequences \
      -f run.f
xelab -L uvm -relax -timescale 1ns/1ps -debug typical \
      -s pathfinder_sim pathfinder_verif_top

# 2. Petlja po mapama
mkdir -p regr_logs
rm -f regr_logs/summary.txt
PASS_COUNT=0
FAIL_COUNT=0

echo
echo "===================== REGRESIJA: POCETAK ====================="
echo

set +e
for MAP in maps/*.txt; do
    NAME=$(basename "$MAP" .txt)
    EXTRA=()
    case "$NAME" in
        unsolvable*) EXTRA=(-testplusarg "EXPECT_UNSOLVABLE=1");;
    esac

    echo "[REGRESIJA] Pokrecem mapu $NAME ..."
    xsim pathfinder_sim -R -log "regr_logs/$NAME.log" \
         -testplusarg "UVM_TESTNAME=test_scoreboard" \
         -testplusarg "UVM_VERBOSITY=UVM_MEDIUM" \
         -testplusarg "MAP_FILE=$MAP" "${EXTRA[@]}" > /dev/null 2>&1

    if grep -Eq "UVM_ERROR : *0" "regr_logs/$NAME.log" && \
       grep -Eq "UVM_FATAL : *0" "regr_logs/$NAME.log"; then
        RES=PASS; PASS_COUNT=$((PASS_COUNT+1))
    else
        RES=FAIL; FAIL_COUNT=$((FAIL_COUNT+1))
    fi
    echo "[REGRESIJA] $NAME : $RES"
    echo "$NAME : $RES" >> regr_logs/summary.txt
done

# 3. Zbirni izvestaj
echo
echo "===================== REGRESIJA: IZVESTAJ ===================="
cat regr_logs/summary.txt
echo "--------------------------------------------------------------"
echo "PASS: $PASS_COUNT    FAIL: $FAIL_COUNT"
echo "=============================================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "REGRESIJA NEUSPESNA: pogledati logove u regr_logs/"
    exit 1
fi
echo "REGRESIJA USPESNA: sve mape prosle."
