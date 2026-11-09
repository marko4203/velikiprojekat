`timescale 1ns/1ps

`ifndef PATHFINDER_SEQ_PKG_SV
 `define PATHFINDER_SEQ_PKG_SV

package pathfinder_seq_pkg;

   import uvm_pkg::*;      // import the UVM library
 `include "uvm_macros.svh" // Include the UVM macros

   import pathfinder_agent_pkg::*;

`include "pathfinder_base_seq.sv"
`include "pathfinder_simple_seq.sv"
`include "pathfinder_check_seq.sv"
`include "pathfinder_stress_seq.sv"
`include "pathfinder_coverage_seq.sv"

endpackage : pathfinder_seq_pkg

`endif
