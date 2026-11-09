@echo off
setlocal enabledelayedexpansion
rem =====================================================================
rem  Regresioni testovi: pokrece test_scoreboard nad svim mapama iz
rem  foldera maps\. Mape ciji naziv pocinje sa "unsolvable" testiraju se
rem  sa ocekivanjem da putanja ne postoji.
rem
rem  Dizajn se kompajlira i elaborira JEDNOM, a zatim se za svaku mapu
rem  pokrece samo simulacija. Log svake mape ide u regr_logs\<mapa>.log,
rem  a zbirni izvestaj u regr_logs\summary.txt.
rem
rem  Upotreba: run_regression.bat
rem =====================================================================

if not exist maps\*.txt (
    echo GRESKA: folder maps\ ne postoji ili je prazan.
    exit /b 1
)

rem ---------- 1. Kompajliranje i elaboracija (jednom) ----------
call xvhdl dut/pathfinder_ip.vhd ^
           dut/pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd ^
           dut/pathfinder_axi.vhd ^
           dut/bram.vhd ^
           dut/bram_router.vhd
if errorlevel 1 goto :builderror

call xvlog -sv -L uvm ^
           -i verif -i verif/Agent -i verif/Configurations -i verif/Sequences ^
           -f run.f
if errorlevel 1 goto :builderror

call xelab -L uvm -relax -timescale 1ns/1ps -debug typical ^
           -s pathfinder_sim pathfinder_verif_top
if errorlevel 1 goto :builderror

rem ---------- 2. Petlja po mapama ----------
if not exist regr_logs mkdir regr_logs
if exist regr_logs\summary.txt del regr_logs\summary.txt

set PASS_COUNT=0
set FAIL_COUNT=0

echo.
echo ===================== REGRESIJA: POCETAK =====================
echo.

for %%F in (maps\*.txt) do (
    set MAPNAME=%%~nF
    set MAPPATH=maps/%%~nxF
    set EXTRA=

    echo !MAPNAME! | findstr /B /C:"unsolvable" >nul
    if !errorlevel!==0 set EXTRA=-testplusarg "EXPECT_UNSOLVABLE=1"

    echo [REGRESIJA] Pokrecem mapu !MAPNAME! ...
    call xsim pathfinder_sim -R -log regr_logs\!MAPNAME!.log ^
              -testplusarg "UVM_TESTNAME=test_scoreboard" ^
              -testplusarg "UVM_VERBOSITY=UVM_MEDIUM" ^
              -testplusarg "MAP_FILE=!MAPPATH!" !EXTRA! >nul 2>&1

    set RES=FAIL
    findstr /R /C:"UVM_ERROR : *0" regr_logs\!MAPNAME!.log >nul 2>&1
    if !errorlevel!==0 (
        findstr /R /C:"UVM_FATAL : *0" regr_logs\!MAPNAME!.log >nul 2>&1
        if !errorlevel!==0 set RES=PASS
    )

    if "!RES!"=="PASS" (set /a PASS_COUNT+=1) else (set /a FAIL_COUNT+=1)
    echo [REGRESIJA] !MAPNAME! : !RES!
    echo !MAPNAME! : !RES!>> regr_logs\summary.txt
)

rem ---------- 3. Zbirni izvestaj ----------
echo.
echo ===================== REGRESIJA: IZVESTAJ ====================
type regr_logs\summary.txt
echo --------------------------------------------------------------
echo PASS: !PASS_COUNT!    FAIL: !FAIL_COUNT!
echo ==============================================================

if !FAIL_COUNT! GTR 0 (
    echo REGRESIJA NEUSPESNA: pogledati logove u regr_logs\
    exit /b 1
)
echo REGRESIJA USPESNA: sve mape prosle.
exit /b 0

:builderror
echo.
echo GRESKA: kompajliranje ili elaboracija nisu uspeli, regresija prekinuta.
exit /b 1
