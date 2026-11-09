class pathfinder_agent extends uvm_agent;

   `uvm_component_utils (pathfinder_agent)

   pathfinder_config    cfg;
   pathfinder_sequencer seqr;
   pathfinder_driver    drv;
   pathfinder_monitor   mon;

   function new(string name = "pathfinder_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(pathfinder_config)::get(this, "", "pathfinder_config", cfg))
        `uvm_fatal(get_type_name(), "Konfiguracija nije pronadjena u config db!")

      mon = pathfinder_monitor::type_id::create("mon", this);

      if (cfg.is_active == UVM_ACTIVE) begin
         seqr = pathfinder_sequencer::type_id::create("seqr", this);
         drv  = pathfinder_driver::type_id::create("drv", this);
      end
   endfunction

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(seqr.seq_item_export);
   endfunction

endclass : pathfinder_agent
