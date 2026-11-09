// Scoreboard sa referentnim modelom akceleratora.
//
// Princip rada:
//  - preko analysis imp porta prima sve transakcije koje monitor objavi,
//  - iz MEM_WRITE transakcija odrzava sliku memorije mape,
//  - iz REG_WRITE transakcija pamti START i END koordinate, a upis na
//    CONTROL adresu "naoruzava" proveru i pravi snimak ulazne mape,
//  - po IRQ_EVENT transakciji izvrsava referentni model nad snimkom mape
//    i racuna ocekivani sadrzaj memorije,
//  - svaku MEM_READ transakciju poredi sa ocekivanim sadrzajem; kada su
//    procitane sve lokacije, izdaje konacnu presudu i dodatno proverava
//    semanticku ispravnost lanca roditeljskih cvorova od cilja do starta.
//
// Referentni model verno replikuje hardver (pathfinder_ip.vhd), ukljucujuci:
//  - redosled obilaska suseda u EVAL fazi (i spolja, j unutra) i prekid
//    obilaska cim se dotakne END cvor,
//  - podelu MOVE pretrage na 4 banke (redovi 0-24, 25-49, 50-74, 75-99),
//    sa skeniranjem x rastuce / y unutrasnje i strogim < poredjenjem
//    (prvi minimum u banci pobedjuje),
//  - kaskadu poredjenja lokalnih minimuma banki iz stanja MOVE_NEXT_P:
//    banka1 pobedjuje samo ako je strogo manja od svih ostalih, inace se
//    kaskada spusta na banku2 (poredi se samo sa 3 i 4), pa na banku3
//    (poredi se samo sa 4), inace pobedjuje banka4.
class pathfinder_scoreboard extends uvm_scoreboard;

   `uvm_component_utils (pathfinder_scoreboard)

   uvm_analysis_imp #(pathfinder_seq_item, pathfinder_scoreboard) item_collected_export;

   localparam int GRID_SIZE   = 100;
   localparam int TOTAL_DEPTH = 10000;
   localparam int VAL_WALL    = 298;
   localparam int VAL_START   = 299;
   localparam int VAL_END     = 300;
   localparam int MAX_ERR_PRINT = 10;

   // Slika memorije koju odrzavaju MEM_WRITE transakcije
   bit [23:0] mem_image [0:TOTAL_DEPTH-1];

   // Snimak ulaza i ocekivani izlaz jednog pokretanja
   bit [23:0] expected  [0:TOTAL_DEPTH-1];
   bit        expected_valid = 0;
   bit        armed          = 0;
   bit        ref_solved     = 0;

   // Koordinate iz registara
   int start_x = 0, start_y = 0;
   int end_x   = 0, end_y   = 0;

   // Pracenje poredjenja
   bit [23:0] actual    [0:TOTAL_DEPTH-1];
   bit        seen      [0:TOTAL_DEPTH-1];
   int        seen_count     = 0;
   int        mismatch_count = 0;
   int        runs_checked   = 0;

   function new(string name = "pathfinder_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      item_collected_export = new("item_collected_export", this);
   endfunction

   // ------------------------------------------------------------------
   // Prijem transakcija od monitora
   // ------------------------------------------------------------------
   function void write(pathfinder_seq_item t);
      string outcome;
      case (t.op)

        MEM_WRITE : begin
           if (t.mem_addr < TOTAL_DEPTH)
             mem_image[t.mem_addr] = t.mem_data;
        end

        REG_WRITE : begin
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
                // CONTROL: pokretanje algoritma, naoruzavanje provere
                armed          = 1;
                expected_valid = 0;
                seen_count     = 0;
                mismatch_count = 0;
                foreach (seen[i]) seen[i] = 0;
                foreach (expected[i]) expected[i] = mem_image[i];
                `uvm_info(get_type_name(),
                          $sformatf("Pokretanje uoceno: start = (%0d,%0d), end = (%0d,%0d). Ulazna mapa snimljena.",
                                    start_x, start_y, end_x, end_y), UVM_LOW)
             end
             default : ;
           endcase
        end

        IRQ_EVENT : begin
           if (armed) begin
              run_ref_model();
              expected_valid = 1;
              if (ref_solved) outcome = "resena";
              else            outcome = "neresiva";
              `uvm_info(get_type_name(),
                        $sformatf("Referentni model izvrsen (mapa %s). Ocekivani sadrzaj memorije spreman.",
                                  outcome), UVM_LOW)
           end
        end

        MEM_READ : begin
           if (expected_valid && t.mem_addr < TOTAL_DEPTH)
             compare_location(t.mem_addr, t.mem_rdata);
        end

        default : ; // REG_READ i WAIT_IRQ nisu od interesa za scoreboard
      endcase
   endfunction

   // ------------------------------------------------------------------
   // Poredjenje jedne procitane lokacije sa ocekivanim sadrzajem
   // ------------------------------------------------------------------
   function void compare_location(bit [13:0] addr, bit [23:0] data);
      actual[addr] = data;
      if (!seen[addr]) begin
         seen[addr] = 1;
         seen_count++;
      end

      if (data !== expected[addr]) begin
         mismatch_count++;
         if (mismatch_count <= MAX_ERR_PRINT)
           `uvm_error(get_type_name(),
                      $sformatf("Neslaganje na adresi %0d, cvor (%0d,%0d): procitano %b, ocekivano %b",
                                addr, addr / GRID_SIZE, addr % GRID_SIZE,
                                data, expected[addr]))
         if (mismatch_count == MAX_ERR_PRINT + 1)
           `uvm_info(get_type_name(),
                     "Dalja pojedinacna neslaganja se ne ispisuju, broje se u zbiru.", UVM_LOW)
      end

      if (seen_count == TOTAL_DEPTH)
        final_verdict();
   endfunction

   // ------------------------------------------------------------------
   // Konacna presuda nakon poredjenja svih lokacija
   // ------------------------------------------------------------------
   function void final_verdict();
      runs_checked++;
      if (mismatch_count == 0)
        `uvm_info(get_type_name(),
                  $sformatf("SCOREBOARD PROVERA USPESNA: svih %0d lokacija se poklapa sa referentnim modelom.",
                            TOTAL_DEPTH), UVM_LOW)
      else
        `uvm_error(get_type_name(),
                   $sformatf("SCOREBOARD PROVERA NEUSPESNA: %0d od %0d lokacija se ne poklapa sa referentnim modelom.",
                             mismatch_count, TOTAL_DEPTH))

      if (ref_solved)
        check_parent_chain();
      else
        `uvm_info(get_type_name(),
                  "Mapa je neresiva po referentnom modelu, provera lanca roditelja se preskace.", UVM_LOW)

      // Stvarno stanje memorije postaje ulaz za eventualno sledece
      // pokretanje bez ponovnog ucitavanja mape (back-to-back scenario).
      foreach (mem_image[i]) mem_image[i] = actual[i];
      armed          = 0;
      expected_valid = 0;
   endfunction

   // ------------------------------------------------------------------
   // Semanticka provera: lanac roditelja od cilja do starta, nezavisna
   // od referentnog modela, izvrsava se nad stvarnim sadrzajem memorije.
   // ------------------------------------------------------------------
   function void check_parent_chain();
      int x, y, px, py, d, steps;
      x     = end_x;
      y     = end_y;
      steps = 0;

      forever begin
         d = actual[x * GRID_SIZE + y][23:15];

         if (d == VAL_START) begin
            `uvm_info(get_type_name(),
                      $sformatf("Lanac roditelja validan: od cilja (%0d,%0d) do starta (%0d,%0d) u %0d koraka.",
                                end_x, end_y, start_x, start_y, steps), UVM_LOW)
            return;
         end

         if (d == VAL_WALL) begin
            `uvm_error(get_type_name(),
                       $sformatf("Lanac roditelja prolazi kroz zid na cvoru (%0d,%0d)!", x, y))
            return;
         end

         px = actual[x * GRID_SIZE + y][14:8];
         py = actual[x * GRID_SIZE + y][7:1];

         if (px >= GRID_SIZE || py >= GRID_SIZE) begin
            `uvm_error(get_type_name(),
                       $sformatf("Cvor (%0d,%0d) ima nevalidnog roditelja (%0d,%0d)!", x, y, px, py))
            return;
         end

         if ((px > x + 1) || (px < x - 1) || (py > y + 1) || (py < y - 1) ||
             (px == x && py == y)) begin
            `uvm_error(get_type_name(),
                       $sformatf("Roditelj (%0d,%0d) cvora (%0d,%0d) nije njegov sused!", px, py, x, y))
            return;
         end

         x = px;
         y = py;
         steps++;

         if (steps > TOTAL_DEPTH) begin
            `uvm_error(get_type_name(),
                       "Lanac roditelja ne dostize start (moguca petlja u lancu)!")
            return;
         end
      end
   endfunction

   // ------------------------------------------------------------------
   // Referentni model: verna replika automata iz pathfinder_ip.vhd,
   // izvrsava se nad nizom expected (koji na ulazu sadrzi snimak mape).
   // ------------------------------------------------------------------
   function void run_ref_model();
      int cx, cy;
      int bank_dist [4];
      int bank_x    [4];
      int bank_y    [4];
      int sel;
      int a, d, i, j, k, x, y;
      bit touched_end;

      cx         = start_x;
      cy         = start_y;
      ref_solved = 0;

      forever begin
         // ------------------- EVAL faza -------------------
         // Obilazak suseda: i (kolona) spolja, j (red) unutra, redom
         // rastuce, uz preskakanje granica i centralnog cvora. Cim se
         // dotakne END cvor, upisuje se roditelj i obilazak se prekida
         // (preostali susedi ostaju neobradjeni, kao u RTL-u).
         touched_end = 0;
         for (i = cx - 1; i <= cx + 1; i++) begin
            for (j = cy - 1; j <= cy + 1; j++) begin
               if (i < 0 || i >= GRID_SIZE || j < 0 || j >= GRID_SIZE) continue;
               if (i == cx && j == cy) continue;
               a = i * GRID_SIZE + j;
               d = expected[a][23:15];
               if (d == VAL_END) begin
                  expected[a][14:8] = i7(cx);
                  expected[a][7:1]  = i7(cy);
                  // distance i visited bit END cvora se ne menjaju
                  touched_end = 1;
                  break;
               end
               else if (d == 0) begin
                  expected[a][23:15] = 9'(heuristic(i, j, end_x, end_y));
                  expected[a][14:8]  = i7(cx);
                  expected[a][7:1]   = i7(cy);
                  // visited bit se ne menja
               end
               // zidovi, start i vec evaluirani cvorovi se preskacu
            end
            if (touched_end) break;
         end

         if (touched_end) begin
            ref_solved = 1;
            return; // trenutni cvor NE dobija visited bit (kao u RTL-u)
         end

         // ------------------- MOVE faza -------------------
         // Cetiri banke se skeniraju nezavisno: banka k pokriva redove
         // x u [25k, 25k+24], skeniranje ide x rastuce, y unutrasnje.
         // Strogo < poredjenje: prvi minimum u banci pobedjuje.
         for (k = 0; k < 4; k++) begin
            bank_dist[k] = 511;
            bank_x[k]    = 127;
            bank_y[k]    = 127;
            for (x = 25 * k; x < 25 * k + 25; x++) begin
               for (y = 0; y < GRID_SIZE; y++) begin
                  a = x * GRID_SIZE + y;
                  d = expected[a][23:15];
                  if (expected[a][0] == 1'b0 && d > 0 && d < VAL_WALL && d < bank_dist[k]) begin
                     bank_dist[k] = d;
                     bank_x[k]    = x;
                     bank_y[k]    = y;
                  end
               end
            end
         end

         // Kaskada poredjenja lokalnih minimuma, identicna MOVE_NEXT_P:
         if (bank_dist[0] < bank_dist[1] && bank_dist[0] < bank_dist[2] && bank_dist[0] < bank_dist[3])
           sel = 0;
         else if (bank_dist[1] < bank_dist[2] && bank_dist[1] < bank_dist[3])
           sel = 1;
         else if (bank_dist[2] < bank_dist[3])
           sel = 2;
         else
           sel = 3;

         if (bank_x[sel] == 127 || bank_y[sel] == 127) begin
            // nijedan validan cvor: mapa je neresiva, trenutni cvor
            // ne dobija visited bit (kao u RTL-u)
            ref_solved = 0;
            return;
         end

         // MOVE_NEXT: trenutni cvor dobija visited bit, prelazak na sledeci
         expected[cx * GRID_SIZE + cy][0] = 1'b1;
         cx = bank_x[sel];
         cy = bank_y[sel];
      end
   endfunction

   // Heuristika, identicna funkciji heuristic() iz RTL-a:
   // h = 2 * |dx - dy| + 3 * min(dx, dy)
   function automatic int heuristic(int ix, int iy, int ex, int ey);
      int dx, dy, diff, minv;
      dx   = (ex >= ix) ? ex - ix : ix - ex;
      dy   = (ey >= iy) ? ey - iy : iy - ey;
      diff = (dx >= dy) ? dx - dy : dy - dx;
      minv = (dx >= dy) ? dy : dx;
      return 2 * diff + 3 * minv;
   endfunction

   // Pakovanje koordinate u 7 bita
   function automatic bit [6:0] i7(int v);
      return v[6:0];
   endfunction

   // ------------------------------------------------------------------
   // Zavrsna provera faze: upozorenje ako je provera ostala nedovrsena
   // ------------------------------------------------------------------
   function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (expected_valid && seen_count < TOTAL_DEPTH)
        `uvm_info(get_type_name(),
                  $sformatf("Delimicno poredjenje: procitano i provereno %0d od %0d lokacija.",
                            seen_count, TOTAL_DEPTH), UVM_LOW)
      if (runs_checked > 0)
        `uvm_info(get_type_name(),
                  $sformatf("Ukupno kompletno proverenih pokretanja: %0d.", runs_checked), UVM_LOW)
   endfunction

endclass : pathfinder_scoreboard
