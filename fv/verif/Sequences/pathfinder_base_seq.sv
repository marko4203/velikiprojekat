class pathfinder_base_seq extends uvm_sequence #(pathfinder_seq_item);

   `uvm_object_utils (pathfinder_base_seq)

   // Sentinel vrednosti polja distance, iste kao u RTL-u i softverskoj specifikaciji.
   localparam int VAL_WALL  = 298;
   localparam int VAL_START = 299;
   localparam int VAL_END   = 300;

   localparam int GRID_SIZE   = 100;
   localparam int TOTAL_DEPTH = 10000;

   // Koordinate sentinela otkrivene tokom ucitavanja mape (-1 ako ih nema)
   int map_start_x = -1;
   int map_start_y = -1;
   int map_end_x   = -1;
   int map_end_y   = -1;

   function new(string name = "pathfinder_base_seq");
      super.new(name);
   endfunction

   // -------------------------------------------------------------------
   // Pomocni task-ovi: svaki generise jedan seq_item i posalje ga drajveru.
   // -------------------------------------------------------------------

   task reg_write(bit [3:0] addr, bit [31:0] data);
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op   = REG_WRITE;
      req.addr = addr;
      req.data = data;
      finish_item(req);
   endtask

   task reg_read(bit [3:0] addr, output bit [31:0] data);
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op   = REG_READ;
      req.addr = addr;
      finish_item(req);
      data = req.rdata; // drajver je popunio rezultat u istom objektu
   endtask

   task mem_write(bit [13:0] addr, bit [23:0] data);
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op       = MEM_WRITE;
      req.mem_addr = addr;
      req.mem_data = data;
      finish_item(req);
   endtask

   task mem_read(bit [13:0] addr, output bit [23:0] data);
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op       = MEM_READ;
      req.mem_addr = addr;
      finish_item(req);
      data = req.mem_rdata;
   endtask

   task wait_irq();
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op = WAIT_IRQ;
      finish_item(req);
   endtask

   task wait_cycles(int unsigned n);
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op   = WAIT_CYCLES;
      req.data = n;
      finish_item(req);
   endtask

   task reset_pulse();
      req = pathfinder_seq_item::type_id::create("req");
      start_item(req);
      req.op = RESET_PULSE;
      finish_item(req);
   endtask

   // -------------------------------------------------------------------
   // Ucitavanje mape iz tekstualnog fajla (isti format kao bram_init.txt:
   // jedna 24-bitna binarna rec po liniji, adrese 0 do 9999 redom).
   // -------------------------------------------------------------------
   task load_map(string map_file);
      int          fd;
      int          code;
      int          idx;
      bit [23:0]   node;

      fd = $fopen(map_file, "r");
      if (fd == 0)
        `uvm_fatal(get_type_name(),
                   $sformatf("Nije moguce otvoriti fajl mape: %s", map_file))

      `uvm_info(get_type_name(),
                $sformatf("Pocetak ucitavanja mape iz fajla: %s", map_file), UVM_LOW)

      map_start_x = -1;
      map_start_y = -1;
      map_end_x   = -1;
      map_end_y   = -1;

      idx = 0;
      while (!$feof(fd) && idx < TOTAL_DEPTH) begin
         code = $fscanf(fd, " %b", node);
         if (code == 1) begin
            // usput se otkrivaju pozicije START i END sentinela,
            // pa koordinate ne moraju da se zadaju rucno
            if (node[23:15] == VAL_START) begin
               map_start_x = idx / GRID_SIZE;
               map_start_y = idx % GRID_SIZE;
            end
            else if (node[23:15] == VAL_END) begin
               map_end_x = idx / GRID_SIZE;
               map_end_y = idx % GRID_SIZE;
            end
            mem_write(idx[13:0], node);
            idx++;
         end
      end
      $fclose(fd);

      if (idx != TOTAL_DEPTH)
        `uvm_warning(get_type_name(),
                     $sformatf("Fajl mape sadrzi %0d od ocekivanih %0d lokacija!", idx, TOTAL_DEPTH))
      else
        `uvm_info(get_type_name(),
                  $sformatf("Ucitavanje zavrseno, upisano %0d lokacija.", idx), UVM_LOW)
   endtask

   // Pakovanje koordinata u format registra: X(13:7) & Y(6:0).
   function bit [31:0] pack_coord(int x, int y);
      return {18'd0, x[6:0], y[6:0]};
   endfunction

   // Ravna adresa cvora u memoriji mape.
   function bit [13:0] flat_addr(int x, int y);
      return 14'((x * GRID_SIZE) + y);
   endfunction

endclass : pathfinder_base_seq
