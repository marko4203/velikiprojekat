class test_coverage extends test_base;

   `uvm_component_utils (test_coverage)

   function new(string name = "test_coverage", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      pathfinder_coverage_seq seq;
      phase.raise_objection(this);

      seq = pathfinder_coverage_seq::type_id::create("seq");
      seq.start(env.agent.seqr);

      phase.drop_objection(this);
   endtask

endclass : test_coverage
