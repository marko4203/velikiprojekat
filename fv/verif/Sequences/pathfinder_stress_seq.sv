// Stress sekvenca: pokriva funkcionalnosti 5 i 6 iz tabele verifikacionog
// plana (uzastopna pokretanja bez reseta i reset u toku rada).
//
// Koraci:
//  1/4  kompletan scenario,
//  2/4  kompletan scenario odmah zatim, bez reseta izmedju (FSM se posle
//       DONE vraca u IDLE, pa drugo pokretanje mora raditi ispravno),
//  3/4  pokretanje algoritma pa reset usred rada (posle RESET_DELAY
//       taktova, podrazumevano 30000),
//  4/4  kompletan scenario nakon reseta, kao dokaz oporavka.
//
// Mapa se zadaje sa +MAP_FILE (mora biti resiva); +RESET_DELAY po zelji.
// Preporuka je mapa sa duzom pretragom (npr. maps/02_map.txt), kako bi
// reset u koraku 3/4 zaista pao usred pretrage.
class pathfinder_stress_seq extends pathfinder_simple_seq;

   `uvm_object_utils (pathfinder_stress_seq)

   int unsigned reset_delay = 30000;
   int          plusarg_tmp;

   function new(string name = "pathfinder_stress_seq");
      super.new(name);
   endfunction

   task body();
      plusarg_hit = $value$plusargs("MAP_FILE=%s", map_file);
      if ($value$plusargs("RESET_DELAY=%d", plusarg_tmp))
        reset_delay = plusarg_tmp;

      // koordinate se uvek uzimaju iz mape (bez override-a),
      // jer se isti scenario ponavlja vise puta
      allow_plusarg_override = 0;

      `uvm_info(get_type_name(), "Korak 1/4: prvo pokretanje.", UVM_LOW)
      run_scenario(map_file, 0);

      `uvm_info(get_type_name(), "Korak 2/4: uzastopno pokretanje bez reseta.", UVM_LOW)
      run_scenario(map_file, 0);

      `uvm_info(get_type_name(),
                $sformatf("Korak 3/4: pokretanje pa reset nakon %0d taktova.", reset_delay),
                UVM_LOW)
      load_map(map_file);
      if (map_start_x < 0 || map_end_x < 0)
        `uvm_fatal(get_type_name(), "Mapa ne sadrzi START/END sentinele!")
      reg_write(4'h0, pack_coord(map_start_x, map_start_y));
      reg_write(4'h4, pack_coord(map_end_x,   map_end_y));
      reg_write(4'h8, 32'd1);
      wait_cycles(reset_delay);
      reset_pulse();

      `uvm_info(get_type_name(), "Korak 4/4: kompletan scenario nakon reseta.", UVM_LOW)
      run_scenario(map_file, 0);

      `uvm_info(get_type_name(), "Stress sekvenca zavrsena.", UVM_LOW)
   endtask : body

endclass : pathfinder_stress_seq
