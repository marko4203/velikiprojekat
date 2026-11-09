class pathfinder_driver extends uvm_driver #(pathfinder_seq_item);

   `uvm_component_utils (pathfinder_driver)

   virtual pathfinder_if vif;
   pathfinder_config     cfg;

   function new(string name = "pathfinder_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual pathfinder_if)::get(this, "", "pathfinder_vif", vif))
        `uvm_fatal(get_type_name(), "Virtualni interfejs nije pronadjen u config db!")
      if (!uvm_config_db#(pathfinder_config)::get(this, "", "pathfinder_config", cfg))
        `uvm_fatal(get_type_name(), "Konfiguracija nije pronadjena u config db!")
   endfunction

   task run_phase(uvm_phase phase);
      reset_dut();
      forever begin
         seq_item_port.get_next_item(req);
         drive_item(req);
         seq_item_port.item_done();
      end
   endtask

   // -------------------------------------------------------------------
   // Reset: aresetn drzimo nisko nekoliko taktova, zatim pustamo DUT u IDLE.
   // -------------------------------------------------------------------
   task reset_dut();
      vif.aresetn <= 1'b0;
      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b0;
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b0;
      vif.mem_en  <= 1'b0;
      vif.mem_we  <= 1'b0;
      repeat (5) @(posedge vif.clk);
      vif.aresetn <= 1'b1;
      repeat (2) @(posedge vif.clk);
      `uvm_info(get_type_name(), "Reset zavrsen, DUT je u IDLE stanju.", UVM_MEDIUM)
   endtask

   task drive_item(pathfinder_seq_item item);
      case (item.op)
        REG_WRITE : axi_write(item.addr, item.data);
        REG_READ  : axi_read (item.addr, item.rdata);
        MEM_WRITE : mem_write(item.mem_addr, item.mem_data);
        MEM_READ  : mem_read (item.mem_addr, item.mem_rdata);
        WAIT_IRQ    : wait_irq();
        WAIT_CYCLES : repeat (item.data) @(posedge vif.clk);
        RESET_PULSE : begin
           `uvm_info(get_type_name(), "Reset DUT-a usred rada (RESET_PULSE).", UVM_LOW)
           reset_dut();
        end
        default   : `uvm_warning(get_type_name(),
                       $sformatf("Drajver je dobio nepodrzanu operaciju: %s", item.op.name()))
      endcase
   endtask

   // -------------------------------------------------------------------
   // AXI4-Lite upis: AW i W kanal se pobudjuju istovremeno (kao u
   // referentnom tb_axi_verify.vhd), zatim se ceka B odgovor.
   // -------------------------------------------------------------------
   task axi_write(bit [3:0] addr, bit [31:0] data);
      @(posedge vif.clk);
      vif.awaddr  <= addr;
      vif.awvalid <= 1'b1;
      vif.wdata   <= data;
      vif.wstrb   <= 4'hF;
      vif.wvalid  <= 1'b1;
      do @(posedge vif.clk); while (!(vif.awready && vif.wready));
      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b1;
      do @(posedge vif.clk); while (!vif.bvalid);
      vif.bready  <= 1'b0;
      `uvm_info(get_type_name(),
                $sformatf("AXI WRITE  addr = 0x%0h  data = 0x%0h", addr, data), UVM_HIGH)
   endtask

   // -------------------------------------------------------------------
   // AXI4-Lite citanje.
   // -------------------------------------------------------------------
   task axi_read(bit [3:0] addr, output bit [31:0] data);
      @(posedge vif.clk);
      vif.araddr  <= addr;
      vif.arvalid <= 1'b1;
      do @(posedge vif.clk); while (!vif.arready);
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b1;
      do @(posedge vif.clk); while (!vif.rvalid);
      data        = vif.rdata;
      vif.rready  <= 1'b0;
      `uvm_info(get_type_name(),
                $sformatf("AXI READ   addr = 0x%0h  data = 0x%0h", addr, data), UVM_HIGH)
   endtask

   // -------------------------------------------------------------------
   // Upis u memoriju mape kroz port A (jedan takt po lokaciji).
   // -------------------------------------------------------------------
   task mem_write(bit [13:0] addr, bit [23:0] data);
      @(posedge vif.clk);
      vif.mem_en   <= 1'b1;
      vif.mem_we   <= 1'b1;
      vif.mem_addr <= addr;
      vif.mem_din  <= data;
      @(posedge vif.clk);
      vif.mem_en   <= 1'b0;
      vif.mem_we   <= 1'b0;
   endtask

   // -------------------------------------------------------------------
   // Citanje iz memorije mape kroz port A. BRAM ima sinhrono citanje
   // (podatak validan takt nakon adrese), a bank-mux u verif_top-u je
   // registrovan, pa se ceka dva takta pre uzorkovanja.
   // -------------------------------------------------------------------
   task mem_read(bit [13:0] addr, output bit [23:0] data);
      @(posedge vif.clk);
      vif.mem_en   <= 1'b1;
      vif.mem_we   <= 1'b0;
      vif.mem_addr <= addr;
      repeat (2) @(posedge vif.clk);
      data        = vif.mem_dout;
      vif.mem_en  <= 1'b0;
   endtask

   // -------------------------------------------------------------------
   // Blokirajuce cekanje na irq_out sa watchdog-om iz konfiguracije.
   // -------------------------------------------------------------------
   task wait_irq();
      int unsigned t = 0;
      while (vif.irq_out !== 1'b1) begin
         @(posedge vif.clk);
         t++;
         if (t % 1_000_000 == 0)
           `uvm_info(get_type_name(),
                     $sformatf("Cekanje na irq_out u toku... proslo %0d taktova.", t), UVM_LOW)
         if (t >= cfg.irq_timeout)
           `uvm_fatal(get_type_name(),
                      $sformatf("Watchdog: irq_out nije stigao za %0d taktova!", cfg.irq_timeout))
      end
      `uvm_info(get_type_name(),
                $sformatf("irq_out detektovan nakon %0d taktova.", t), UVM_LOW)
      @(posedge vif.clk);
   endtask

endclass : pathfinder_driver
