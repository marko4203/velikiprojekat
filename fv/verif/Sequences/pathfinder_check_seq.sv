// Sekvenca za scoreboard proveru: izvrsava kompletan osnovni scenario
// (nasledjeno od pathfinder_simple_seq), a zatim cita svih 10000 lokacija
// memorije. Procitane vrednosti monitor objavljuje na analysis port, gde
// ih scoreboard poredi sa ocekivanim sadrzajem iz referentnog modela.
class pathfinder_check_seq extends pathfinder_simple_seq;

   `uvm_object_utils (pathfinder_check_seq)

   function new(string name = "pathfinder_check_seq");
      super.new(name);
   endfunction

   task body();
      bit [23:0] tmp;

      super.body();

      `uvm_info(get_type_name(),
                "Citanje kompletnog sadrzaja memorije za scoreboard proveru...", UVM_LOW)

      for (int addr = 0; addr < TOTAL_DEPTH; addr++)
        mem_read(addr[13:0], tmp);

      `uvm_info(get_type_name(),
                "Citanje memorije zavrseno, scoreboard je izvrsio poredjenje.", UVM_LOW)
   endtask : body

endclass : pathfinder_check_seq
