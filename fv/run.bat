@echo off
setlocal enabledelayedexpansion
rem =====================================================================
rem  Pokretanje UVM simulacije u Vivado xsim-u (komandna linija).
rem  Pokrenuti iz cmd-a u kome je ucitan settings64.bat Vivado-a.
rem
rem  Upotreba (argumenti OBAVEZNO pod navodnicima zbog znaka '='):
rem    run.bat
rem    run.bat "END_X=7" "END_Y=7"
rem    run.bat "MAP_FILE=mape/mapa_03.txt" "START_X=0" "START_Y=0" "END_X=99" "END_Y=99"
rem =====================================================================

rem Korisnicki plusarg-ovi idu PRE podrazumevanih, jer $value$plusargs
rem uzima prvo poklapanje, pa korisnicka vrednost pregazi podrazumevanu.
set EXTRA=
:parse
if "%~1"=="" goto compile
set EXTRA=!EXTRA! -testplusarg "%~1"
shift
goto parse

:compile
rem 1. Kompajliranje VHDL izvora (DUT + memorijski harness)
call xvhdl dut/pathfinder_ip.vhd ^
           dut/pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd ^
           dut/pathfinder_axi.vhd ^
           dut/bram.vhd ^
           dut/bram_router.vhd
if errorlevel 1 goto :error

rem 2. Kompajliranje SystemVerilog izvora (UVM okruzenje)
call xvlog -sv -L uvm ^
           -i verif -i verif/Agent -i verif/Configurations -i verif/Sequences ^
           -f run.f
if errorlevel 1 goto :error

rem 3. Elaboracija (mixed-language: SV top instancira VHDL entitete)
call xelab -L uvm -relax -timescale 1ns/1ps -debug typical ^
           -s pathfinder_sim pathfinder_verif_top
if errorlevel 1 goto :error

rem 4. Simulacija
call xsim pathfinder_sim -R !EXTRA! ^
          -testplusarg "UVM_TESTNAME=test_simple" ^
          -testplusarg "UVM_VERBOSITY=UVM_MEDIUM" ^
          -testplusarg "MAP_FILE=bram_init.txt"
goto :eof

:error
echo.
echo GRESKA: prethodni korak nije uspeo, simulacija prekinuta.
exit /b 1
