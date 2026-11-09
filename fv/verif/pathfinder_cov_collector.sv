// Kolektor funkcionalne pokrivenosti.
//
// Pasivna komponenta pretplacena na analysis port monitora, kao i
// scoreboard. Iz uocenih transakcija uzorkuje covergroup-ove kojima se
// meri koliko je prostor mogucih scenarija zaista ispitan:
//
//  - cg_reg_write / cg_reg_read : pokrivenost registarskih operacija
//    (koje su adrese upisivane, odnosno citane),
//  - cg_scenario : pokrivenost scenarija, uzorkuje se pri CONTROL upisu:
//      * pozicija startnog i ciljnog cvora (ugao / ivica / sredina mape),
//      * Cebisevljevo rastojanje start-cilj (blizu / srednje / daleko),
//      * redni broj pokretanja u testu (prvo / uzastopno bez reseta),
//  - cg_map : gustina zidova ucitane mape (nema / malo / mnogo),
//  - cg_irq : da li je prekid uocen.
//
// Napomena: bin "uzastopno" u cp_broj_pokretanja odgovara funkcionalnosti
// broj 5 iz tabele verifikacionog plana (uzastopna pokretanja bez reseta),
// koja je u planu oznacena kao "plan" - dok se ne doda odgovarajuci test,
// ovaj bin ostaje nepokriven i pokrivenost to verno prikazuje.
class pathfinder_cov_collector extends uvm_component;

   `uvm_component_utils (pathfinder_cov_collector)

   uvm_analysis_imp #(pathfinder_seq_item, pathfinder_cov_collector) item_collected_export;

   localparam int GRID_SIZE = 100;
   localparam int VAL_WALL  = 298;

   // Pomocne promenljive nad kojima se uzorkuju covergroup-ovi
   bit [3:0] rw_addr;
   int       start_x, start_y, end_x, end_y;
   int       start_pozicija, end_pozicija; // 0 = ugao, 1 = ivica, 2 = sredina
   int       cheb_rastojanje;
   int       broj_pokretanja = 0;
   int       broj_zidova     = 0;
   bit       mapa_ucitana    = 0;
   bit       irq_uocen       = 0;
   bit       start_polovina, end_polovina;   // 0 = leva (x < 50), 1 = desna
   bit       reset_pre_pokretanja = 1;       // pocetni reset uvek prethodi prvom pokretanju
   bit       nakon_prekida = 0;
   bit [13:0] end_flat_addr;
   bit       end_ima_roditelja;

   // ------------------------------------------------------------------
   // Covergroup-ovi
   // ------------------------------------------------------------------
   covergroup cg_reg_write;
      option.per_instance = 1;
      cp_adresa : coverpoint rw_addr {
         bins start_registar   = {4'h0};
         bins end_registar     = {4'h4};
         bins control_registar = {4'h8};
      }
   endgroup

   covergroup cg_reg_read;
      option.per_instance = 1;
      cp_adresa : coverpoint rw_addr {
         bins start_registar = {4'h0};
         bins end_registar   = {4'h4};
      }
   endgroup

   covergroup cg_scenario;
      option.per_instance = 1;
      cp_start_pozicija : coverpoint start_pozicija {
         bins ugao    = {0};
         bins ivica   = {1};
         bins sredina = {2};
      }
      cp_end_pozicija : coverpoint end_pozicija {
         bins ugao    = {0};
         bins ivica   = {1};
         bins sredina = {2};
      }
      cp_rastojanje : coverpoint cheb_rastojanje {
         bins blizu   = {[1:10]};
         bins srednje = {[11:50]};
         bins daleko  = {[51:99]};
      }
      cp_broj_pokretanja : coverpoint broj_pokretanja {
         bins prvo      = {1};
         bins uzastopno = {[2:$]};
      }
      cp_start_polovina : coverpoint start_polovina {
         bins leva  = {0};
         bins desna = {1};
      }
      cp_end_polovina : coverpoint end_polovina {
         bins leva  = {0};
         bins desna = {1};
      }
      cp_reset_pre_pokretanja : coverpoint reset_pre_pokretanja {
         bins sa_resetom  = {1};
         bins bez_reseta  = {0};
      }
   endgroup

   // Ishod pretrage, uzorkuje se pri citanju END cvora nakon prekida:
   // "ima" = resiva mapa (upisan validan roditelj), "nema" = neresiva.
   covergroup cg_outcome;
      option.per_instance = 1;
      cp_end_roditelj : coverpoint end_ima_roditelja {
         bins ima  = {1};
         bins nema = {0};
      }
   endgroup

   covergroup cg_map;
      option.per_instance = 1;
      cp_zidovi : coverpoint broj_zidova {
         bins nema  = {0};
         bins malo  = {[1:99]};
         bins mnogo = {[100:9999]};
      }
   endgroup

   covergroup cg_irq;
      option.per_instance = 1;
      cp_prekid : coverpoint irq_uocen {
         bins stigao = {1};
      }
   endgroup

   function new(string name = "pathfinder_cov_collector", uvm_component parent = null);
      super.new(name, parent);
      item_collected_export = new("item_collected_export", this);
      cg_reg_write = new();
      cg_reg_read  = new();
      cg_scenario  = new();
      cg_map       = new();
      cg_irq       = new();
      cg_outcome   = new();
   endfunction

   // ------------------------------------------------------------------
   // Prijem transakcija od monitora i uzorkovanje
   // ------------------------------------------------------------------
   function void write(pathfinder_seq_item t);
      case (t.op)

        REG_WRITE : begin
           rw_addr = t.addr;
           cg_reg_write.sample();
           case (t.addr)
             4'h0 : begin
                start_x = t.data[13:7];
                start_y = t.data[6:0];
             end
             4'h4 : begin
                end_x = t.data[13:7];
                end_y = t.data[6:0];
             end
             4'h8 : begin
                broj_pokretanja++;
                start_pozicija  = pozicija(start_x, start_y);
                end_pozicija    = pozicija(end_x, end_y);
                start_polovina  = (start_x >= GRID_SIZE / 2);
                end_polovina    = (end_x   >= GRID_SIZE / 2);
                cheb_rastojanje = cheb(start_x, start_y, end_x, end_y);
                cg_scenario.sample();
                if (mapa_ucitana)
                  cg_map.sample();
                mapa_ucitana         = 0;
                broj_zidova          = 0;
                reset_pre_pokretanja = 0;
                nakon_prekida        = 0;
                end_flat_addr        = 14'((end_x * GRID_SIZE) + end_y);
             end
             default : ;
           endcase
        end

        REG_READ : begin
           rw_addr = t.addr;
           cg_reg_read.sample();
        end

        MEM_WRITE : begin
           mapa_ucitana = 1;
           if (t.mem_data[23:15] == VAL_WALL)
             broj_zidova++;
        end

        IRQ_EVENT : begin
           irq_uocen     = 1;
           nakon_prekida = 1;
           cg_irq.sample();
        end

        MEM_READ : begin
           // Citanje END cvora nakon prekida: pokrivenost ishoda pretrage
           if (nakon_prekida && t.mem_addr == end_flat_addr) begin
              end_ima_roditelja = (t.mem_rdata[14:8] < GRID_SIZE) &&
                                  (t.mem_rdata[7:1]  < GRID_SIZE);
              cg_outcome.sample();
              nakon_prekida = 0;
           end
        end

        RESET_PULSE : begin
           // objavljuje monitor pri resetu usred rada
           reset_pre_pokretanja = 1;
        end

        default : ; // WAIT_IRQ i WAIT_CYCLES nisu od interesa za pokrivenost
      endcase
   endfunction

   // Klasifikacija pozicije cvora: 0 = ugao, 1 = ivica, 2 = sredina
   function automatic int pozicija(int x, int y);
      bit na_x_ivici, na_y_ivici;
      na_x_ivici = (x == 0) || (x == GRID_SIZE - 1);
      na_y_ivici = (y == 0) || (y == GRID_SIZE - 1);
      if (na_x_ivici && na_y_ivici) return 0;
      if (na_x_ivici || na_y_ivici) return 1;
      return 2;
   endfunction

   // Cebisevljevo rastojanje (broj koraka pretrage po pravoj liniji)
   function automatic int cheb(int x1, int y1, int x2, int y2);
      int dx, dy;
      dx = (x2 >= x1) ? x2 - x1 : x1 - x2;
      dy = (y2 >= y1) ? y2 - y1 : y1 - y2;
      return (dx >= dy) ? dx : dy;
   endfunction

   // ------------------------------------------------------------------
   // Izvestaj o pokrivenosti na kraju testa
   // ------------------------------------------------------------------
   function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_type_name(), $sformatf(
         {"\nFunkcionalna pokrivenost:\n",
          "  registarski upisi   : %6.2f %%\n",
          "  registarska citanja : %6.2f %%\n",
          "  scenario            : %6.2f %%\n",
          "  mapa (zidovi)       : %6.2f %%\n",
          "  ishod pretrage      : %6.2f %%\n",
          "  prekid              : %6.2f %%\n",
          "  UKUPNO              : %6.2f %%"},
         cg_reg_write.get_coverage(),
         cg_reg_read.get_coverage(),
         cg_scenario.get_coverage(),
         cg_map.get_coverage(),
         cg_outcome.get_coverage(),
         cg_irq.get_coverage(),
         $get_coverage()), UVM_LOW)
   endfunction

endclass : pathfinder_cov_collector
