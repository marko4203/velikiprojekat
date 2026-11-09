class pathfinder_config extends uvm_object;

   uvm_active_passive_enum is_active = UVM_ACTIVE;

   // Watchdog: maksimalan broj taktova cekanja na irq_out.
   // Iz PSDS merenja: najveca mapa je trajala ~70M taktova, pa je default 100M.
   int unsigned irq_timeout = 100_000_000;

   `uvm_object_utils_begin (pathfinder_config)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
      `uvm_field_int(irq_timeout, UVM_DEFAULT)
   `uvm_object_utils_end

   function new(string name = "pathfinder_config");
      super.new(name);
   endfunction

endclass : pathfinder_config
