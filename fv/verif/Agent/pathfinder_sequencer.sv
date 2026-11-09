class pathfinder_sequencer extends uvm_sequencer #(pathfinder_seq_item);

   `uvm_component_utils (pathfinder_sequencer)

   function new(string name = "pathfinder_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction

endclass : pathfinder_sequencer
