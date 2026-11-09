// Osnovna end-to-end sekvenca. Jezgro scenarija je izdvojeno u task
// run_scenario, kako bi ga nasledjene sekvence (check, stress, coverage)
// mogle pozivati vise puta u istom testu, nad razlicitim mapama.
//
// Parametri se zadaju preko plusarg-ova:
//   +MAP_FILE=<putanja>       mapa za osnovni scenario
//   +EXPECT_UNSOLVABLE        mapa je ocekivano neresiva
//   +START_X/START_Y/END_X/END_Y   opcioni override koordinata iz mape
//                                  (vazi samo za pojedinacni scenario)
class pathfinder_simple_seq extends pathfinder_base_seq;

   `uvm_object_utils (pathfinder_simple_seq)

   string map_file               = "bram_init.txt";
   bit    expect_unsolvable      = 0;
   bit    allow_plusarg_override = 1;
   int    plusarg_hit;

   function new(string name = "pathfinder_simple_seq");
      super.new(name);
   endfunction

   task body();
      plusarg_hit = $value$plusargs("MAP_FILE=%s", map_file);
      if ($test$plusargs("EXPECT_UNSOLVABLE")) expect_unsolvable = 1;
      run_scenario(map_file, expect_unsolvable);
   endtask : body

   // -------------------------------------------------------------------
   // Kompletan scenario nad jednom mapom:
   //  1. ucitavanje mape (usput se otkrivaju pozicije sentinela),
   //  2. odredjivanje koordinata (iz mape, uz opcioni plusarg override),
   //  3. programiranje registara + read-back provera,
   //  4. CONTROL impuls,
   //  5. cekanje prekida,
   //  6. provera ciljnog cvora (ocekivanje zavisi od f_expect_unsolv).
   // -------------------------------------------------------------------
   task run_scenario(string f_map, bit f_expect_unsolv);
      bit [31:0] rd;
      bit [23:0] end_node;
      int        node_dist, parent_x, parent_y;
      int        sx, sy, ex, ey;
      int        t;

      // 1. Ucitavanje mape
      load_map(f_map);

      // 2. Koordinate: podrazumevano iz sentinela u mapi
      sx = map_start_x;
      sy = map_start_y;
      ex = map_end_x;
      ey = map_end_y;

      if (allow_plusarg_override) begin
         if ($value$plusargs("START_X=%d", t)) sx = t;
         if ($value$plusargs("START_Y=%d", t)) sy = t;
         if ($value$plusargs("END_X=%d",   t)) ex = t;
         if ($value$plusargs("END_Y=%d",   t)) ey = t;
      end

      if (sx < 0 || sy < 0)
        `uvm_fatal(get_type_name(),
                   "Mapa ne sadrzi START sentinel (299), a koordinate nisu zadate plusarg-ovima!")
      if (ex < 0 || ey < 0)
        `uvm_fatal(get_type_name(),
                   "Mapa ne sadrzi END sentinel (300), a koordinate nisu zadate plusarg-ovima!")

      `uvm_info(get_type_name(),
                $sformatf("Scenario: mapa = %s, start = (%0d,%0d), end = (%0d,%0d)",
                          f_map, sx, sy, ex, ey), UVM_LOW)

      // 3. Programiranje registara + provera citanjem
      reg_write(4'h0, pack_coord(sx, sy));
      reg_write(4'h4, pack_coord(ex, ey));

      reg_read(4'h0, rd);
      if (rd[13:0] !== pack_coord(sx, sy))
        `uvm_error(get_type_name(),
                   $sformatf("START registar: procitano 0x%0h, ocekivano 0x%0h",
                             rd[13:0], pack_coord(sx, sy)))
      else
        `uvm_info(get_type_name(), "START registar procitan ispravno.", UVM_LOW)

      reg_read(4'h4, rd);
      if (rd[13:0] !== pack_coord(ex, ey))
        `uvm_error(get_type_name(),
                   $sformatf("END registar: procitano 0x%0h, ocekivano 0x%0h",
                             rd[13:0], pack_coord(ex, ey)))
      else
        `uvm_info(get_type_name(), "END registar procitan ispravno.", UVM_LOW)

      // 4. CONTROL impuls pokrece algoritam
      `uvm_info(get_type_name(), "Slanje CONTROL impulsa, algoritam se pokrece...", UVM_LOW)
      reg_write(4'h8, 32'd1);

      // 5. Cekanje na prekid
      wait_irq();

      // 6. Provera ciljnog cvora u memoriji
      mem_read(flat_addr(ex, ey), end_node);
      node_dist = end_node[23:15];
      parent_x  = end_node[14:8];
      parent_y  = end_node[7:1];

      `uvm_info(get_type_name(),
                $sformatf("END cvor: distance = %0d, parent = (%0d,%0d)",
                          node_dist, parent_x, parent_y), UVM_LOW)

      if (!f_expect_unsolv) begin
         if (node_dist == VAL_END && parent_x < GRID_SIZE && parent_y < GRID_SIZE)
           `uvm_info(get_type_name(),
                     "PROVERA USPESNA: algoritam je stigao do END cvora i upisao validnog roditelja.",
                     UVM_LOW)
         else
           `uvm_error(get_type_name(),
                      "PROVERA NEUSPESNA: END cvor nema validnog roditelja - algoritam nije stigao do cilja!")
      end
      else begin
         // Mapa je oznacena kao neresiva: prekid mora da stigne (vec je
         // sacekan), a END cvor mora ostati bez validnog roditelja.
         if (node_dist == VAL_END && (parent_x >= GRID_SIZE || parent_y >= GRID_SIZE))
           `uvm_info(get_type_name(),
                     "PROVERA USPESNA: mapa je ocekivano neresiva, DUT je zavrsio rad bez dolaska do END cvora.",
                     UVM_LOW)
         else
           `uvm_error(get_type_name(),
                      "PROVERA NEUSPESNA: mapa je oznacena kao neresiva, a END cvor je dobio validnog roditelja!")
      end

   endtask : run_scenario

endclass : pathfinder_simple_seq
