class pathfinder_env extends uvm_env;

   `uvm_component_utils (pathfinder_env)

   pathfinder_agent        agent;
   pathfinder_scoreboard   sb;
   pathfinder_cov_collector cov;

   function new(string name = "pathfinder_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = pathfinder_agent::type_id::create("agent", this);
      sb    = pathfinder_scoreboard::type_id::create("sb", this);
      cov   = pathfinder_cov_collector::type_id::create("cov", this);
   endfunction

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.item_collected_port.connect(sb.item_collected_export);
      agent.mon.item_collected_port.connect(cov.item_collected_export);
   endfunction

endclass : pathfinder_env
