GBFS Pathfinding Accelerator (Zybo Z7-10, Vivado 2024.1)

Pokretanje build skripte:

1. Otvoriti Vivado (bez otvorenog projekta).
2. U Tcl konzoli ukucati:

   source <putanja-do-repozitorijuma>/rtl/script/build.tcl

Skripta pakuje IP jezgra, pravi blok dizajn, radi sintezu i
implementaciju, i generise .xsa fajl.

Svi rezultati zavrsavaju u rtl/build/ folderu, koji se pravi
automatski. Krajnji rezultat: rtl/build/block_design_wrapper.xsa
