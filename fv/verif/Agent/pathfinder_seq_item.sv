class pathfinder_seq_item extends uvm_sequence_item;

   rand pathfinder_op_t op;

   // Registarski pristup (bajt ofseti: 0x0 START, 0x4 END, 0x8 CONTROL, 0xC STATUS)
   rand bit [3:0]  addr;
   rand bit [31:0] data;
   bit [31:0]      rdata;   // rezultat REG_READ operacije, popunjava drajver

   // Pristup memoriji mape (ravna adresa: x * 100 + y)
   rand bit [13:0] mem_addr;
   rand bit [23:0] mem_data;
   bit [23:0]      mem_rdata; // rezultat MEM_READ operacije, popunjava drajver

   constraint c_mem_addr { mem_addr < 14'd10000; }

   `uvm_object_utils_begin (pathfinder_seq_item)
      `uvm_field_enum(pathfinder_op_t, op, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(rdata, UVM_DEFAULT)
      `uvm_field_int(mem_addr, UVM_DEFAULT)
      `uvm_field_int(mem_data, UVM_DEFAULT)
      `uvm_field_int(mem_rdata, UVM_DEFAULT)
   `uvm_object_utils_end

   function new(string name = "pathfinder_seq_item");
      super.new(name);
   endfunction

endclass : pathfinder_seq_item
