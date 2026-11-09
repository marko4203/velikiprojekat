class test_base extends uvm_test;

   `uvm_component_utils (test_base)

   pathfinder_env    env;
   pathfinder_config cfg;

   function new(string name = "test_base", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = pathfinder_env::type_id::create("env", this);
      cfg = pathfinder_config::type_id::create("cfg");
      uvm_config_db#(pathfinder_config)::set(this, "*", "pathfinder_config", cfg);
   endfunction

   function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_top.print_topology();
   endfunction

endclass : test_base
