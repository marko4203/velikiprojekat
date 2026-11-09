class test_stress extends test_base;

   `uvm_component_utils (test_stress)

   function new(string name = "test_stress", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      pathfinder_stress_seq seq;
      phase.raise_objection(this);

      seq = pathfinder_stress_seq::type_id::create("seq");
      seq.start(env.agent.seqr);

      phase.drop_objection(this);
   endtask

endclass : test_stress
