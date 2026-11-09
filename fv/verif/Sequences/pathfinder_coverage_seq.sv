// Coverage sekvenca: izvrsava kompletan scenario nad svim mapama iz
// liste, u JEDNOJ simulaciji, cime se uzorci pokrivenosti akumuliraju u
// zbirni izvestaj (pokrivenost se ne prenosi izmedju zasebnih simulacija).
//
// Lista se zadaje sa +MAP_LIST (podrazumevano coverage.lst u root-u
// projekta). Format liste: jedna mapa po liniji, opciono praceno recju
// "unsolvable" za mape kod kojih putanja ne postoji; linije koje pocinju
// znakom # se preskacu.
class pathfinder_coverage_seq extends pathfinder_simple_seq;

   `uvm_object_utils (pathfinder_coverage_seq)

   string list_file = "coverage.lst";

   function new(string name = "pathfinder_coverage_seq");
      super.new(name);
   endfunction

   task body();
      int    fd;
      int    code;
      int    n_maps;
      string line, f_map, flag;
      bit    unsolv;

      code = $value$plusargs("MAP_LIST=%s", list_file);
      allow_plusarg_override = 0;

      fd = $fopen(list_file, "r");
      if (fd == 0)
        `uvm_fatal(get_type_name(),
                   $sformatf("Nije moguce otvoriti listu mapa: %s", list_file))

      n_maps = 0;
      while ($fgets(line, fd)) begin
         f_map = "";
         flag  = "";
         code  = $sscanf(line, "%s %s", f_map, flag);
         if (code < 1 || f_map.len() == 0) continue;
         if (f_map.substr(0, 0) == "#") continue;

         unsolv = (code == 2 && flag == "unsolvable");
         n_maps++;
         `uvm_info(get_type_name(),
                   $sformatf("Mapa %0d iz liste: %s%s",
                             n_maps, f_map, unsolv ? " (unsolvable)" : ""), UVM_LOW)
         run_scenario(f_map, unsolv);
      end
      $fclose(fd);

      if (n_maps == 0)
        `uvm_fatal(get_type_name(), "Lista mapa je prazna!")

      `uvm_info(get_type_name(),
                $sformatf("Coverage sekvenca zavrsena, broj izvrsenih scenarija: %0d.", n_maps),
                UVM_LOW)
   endtask : body

endclass : pathfinder_coverage_seq
