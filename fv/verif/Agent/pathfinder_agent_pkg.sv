`timescale 1ns/1ps

`ifndef PATHFINDER_AGENT_PKG_SV
 `define PATHFINDER_AGENT_PKG_SV

package pathfinder_agent_pkg;

   import uvm_pkg::*;      // import the UVM library
 `include "uvm_macros.svh" // Include the UVM macros

   import configurations_pkg::*;

   // Operacije koje seq_item modeluje na granici DUT-a.
   // IRQ_EVENT ne koriste sekvence, vec ga monitor objavljuje kada uoci prekid.
   typedef enum {
      REG_WRITE,  // AXI4-Lite upis u registar
      REG_READ,   // AXI4-Lite citanje registra
      MEM_WRITE,  // upis u memoriju mape (port A)
      MEM_READ,   // citanje iz memorije mape (port A)
      WAIT_IRQ,    // blokirajuce cekanje na irq_out
      WAIT_CYCLES, // pasivno cekanje zadatog broja taktova
      RESET_PULSE, // reset DUT-a usred rada (aresetn impuls)
      IRQ_EVENT    // dogadjaj prekida (objavljuje monitor)
   } pathfinder_op_t;

`include "pathfinder_seq_item.sv"
`include "pathfinder_sequencer.sv"
`include "pathfinder_driver.sv"
`include "pathfinder_monitor.sv"
`include "pathfinder_agent.sv"

endpackage : pathfinder_agent_pkg

`endif
