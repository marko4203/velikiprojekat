`timescale 1ns/1ps

`ifndef CONFIGURATIONS_PKG_SV
 `define CONFIGURATIONS_PKG_SV

package configurations_pkg;

   import uvm_pkg::*;      // import the UVM library
 `include "uvm_macros.svh" // Include the UVM macros

`include "pathfinder_config.sv"

endpackage : configurations_pkg

`endif
