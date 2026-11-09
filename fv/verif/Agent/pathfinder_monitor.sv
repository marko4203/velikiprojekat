class pathfinder_monitor extends uvm_monitor;

   `uvm_component_utils (pathfinder_monitor)

   virtual pathfinder_if vif;

   // Analysis port: na njega ce se kasnije pretplatiti scoreboard i
   // coverage kolektor (stavke 4 i 5 bodovanja).
   uvm_analysis_port #(pathfinder_seq_item) item_collected_port;

   function new(string name = "pathfinder_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual pathfinder_if)::get(this, "", "pathfinder_vif", vif))
        `uvm_fatal(get_type_name(), "Virtualni interfejs nije pronadjen u config db!")
   endfunction

   task run_phase(uvm_phase phase);
      fork
         collect_axi_writes();
         collect_axi_reads();
         collect_irq();
         collect_mem();
         collect_reset();
      join
   endtask

   // -------------------------------------------------------------------
   // AXI upis je uocen kada su AW i W handshake aktivni (drajver ih
   // pobudjuje istovremeno, a slave drzi ready signale visoko).
   // -------------------------------------------------------------------
   task collect_axi_writes();
      pathfinder_seq_item item;
      forever begin
         @(posedge vif.clk);
         if (vif.aresetn && vif.awvalid && vif.awready && vif.wvalid && vif.wready) begin
            item = pathfinder_seq_item::type_id::create("item");
            item.op   = REG_WRITE;
            item.addr = vif.awaddr;
            item.data = vif.wdata;
            `uvm_info(get_type_name(),
                      $sformatf("Uocen AXI WRITE: addr = 0x%0h  data = 0x%0h",
                                item.addr, item.data), UVM_MEDIUM)
            item_collected_port.write(item);
         end
      end
   endtask

   task collect_axi_reads();
      pathfinder_seq_item item;
      forever begin
         @(posedge vif.clk);
         if (vif.aresetn && vif.rvalid && vif.rready) begin
            item = pathfinder_seq_item::type_id::create("item");
            item.op    = REG_READ;
            item.addr  = vif.araddr;
            item.rdata = vif.rdata;
            `uvm_info(get_type_name(),
                      $sformatf("Uocen AXI READ:  addr = 0x%0h  data = 0x%0h",
                                item.addr, item.rdata), UVM_MEDIUM)
            item_collected_port.write(item);
         end
      end
   endtask

   // -------------------------------------------------------------------
   // Prekid: detektuje se rastuca ivica irq_out signala.
   // -------------------------------------------------------------------
   task collect_irq();
      pathfinder_seq_item item;
      logic irq_d = 1'b0;
      forever begin
         @(posedge vif.clk);
         if (vif.aresetn && vif.irq_out === 1'b1 && irq_d === 1'b0) begin
            item = pathfinder_seq_item::type_id::create("item");
            item.op = IRQ_EVENT;
            `uvm_info(get_type_name(), "Uocen prekid (irq_out).", UVM_LOW)
            item_collected_port.write(item);
         end
         irq_d = vif.irq_out;
      end
   endtask

   // -------------------------------------------------------------------
   // Reset: detektuje se padajuca ivica aresetn signala (reset usred
   // rada). Pocetni reset na startu simulacije se ne objavljuje, jer
   // aresetn krece iz niskog stanja.
   // -------------------------------------------------------------------
   task collect_reset();
      pathfinder_seq_item item;
      logic rst_d = 1'b0;
      forever begin
         @(posedge vif.clk);
         if (vif.aresetn === 1'b0 && rst_d === 1'b1) begin
            item = pathfinder_seq_item::type_id::create("item");
            item.op = RESET_PULSE;
            `uvm_info(get_type_name(), "Uocen reset DUT-a (aresetn nizak).", UVM_LOW)
            item_collected_port.write(item);
         end
         rst_d = vif.aresetn;
      end
   endtask

   // -------------------------------------------------------------------
   // Memorijski port A: transakcija pocinje rastucom ivicom mem_en.
   // Upis je validan odmah; za citanje se, kao i u drajveru, ceka jedan
   // dodatni takt (sinhrono citanje BRAM-a + registrovan izbor banke),
   // pa se tek onda uzorkuje mem_dout.
   // -------------------------------------------------------------------
   task collect_mem();
      pathfinder_seq_item item;
      bit        prev_en = 1'b0;
      bit [13:0] rd_addr;
      forever begin
         @(posedge vif.clk);
         if (vif.aresetn && vif.mem_en === 1'b1 && !prev_en) begin
            if (vif.mem_we === 1'b1) begin
               item = pathfinder_seq_item::type_id::create("item");
               item.op       = MEM_WRITE;
               item.mem_addr = vif.mem_addr;
               item.mem_data = vif.mem_din;
               `uvm_info(get_type_name(),
                         $sformatf("Uocen MEM WRITE: addr = %0d  data = %b",
                                   item.mem_addr, item.mem_data), UVM_FULL)
               item_collected_port.write(item);
            end
            else begin
               rd_addr = vif.mem_addr;
               @(posedge vif.clk);
               item = pathfinder_seq_item::type_id::create("item");
               item.op        = MEM_READ;
               item.mem_addr  = rd_addr;
               item.mem_rdata = vif.mem_dout;
               `uvm_info(get_type_name(),
                         $sformatf("Uocen MEM READ:  addr = %0d  data = %b",
                                   item.mem_addr, item.mem_rdata), UVM_FULL)
               item_collected_port.write(item);
            end
            prev_en = 1'b1;
         end
         else
           prev_en = vif.mem_en;
      end
   endtask

endclass : pathfinder_monitor
