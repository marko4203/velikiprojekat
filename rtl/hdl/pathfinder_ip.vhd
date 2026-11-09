library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ---------------------------------------------------------------------------
-- Node kao i u SystemC modelu ima 24 bita:
--  [23:15]  distance   (9 bita)
--  [14:8]   parentX    (7 bita)
--  [7:1]    parentY    (7 bita)
--  [0]      visited    (1 bit)
--
-- Kodirane vrednosti:
--   298 = WALL
--   299 = START
--   300 = END
--   301 = FINALPATH - ne koristi se u IP, procesor obradjuje taj deo
-- ---------------------------------------------------------------------------

entity pathfinder_ip is
    generic (
        GRID_SIZE  : integer := 100;
        ADDR_BITS  : integer := 14;
        DATA_BITS  : integer := 24
    );
    port (
        clk        : in  std_logic;
        rst      : in  std_logic;

        -- CPU interfejs registri
        cpu_we     : in  std_logic;
        cpu_addr   : in  std_logic_vector(1 downto 0);   -- 0/1/2
        cpu_wdata  : in  std_logic_vector(ADDR_BITS-1 downto 0);

        -- BRAM interfejs
        bram_en    : out std_logic;
        bram_we    : out std_logic;
        bram_addr  : out std_logic_vector(ADDR_BITS-1 downto 0);
        bram_din   : out std_logic_vector(DATA_BITS-1 downto 0);
        bram_dout  : in  std_logic_vector(DATA_BITS-1 downto 0);

        -- Interrupt signal ka procesoru
        irq        : out std_logic;

        -- Parallel BRAM interfaces (12-bit sub-addresses, one per bank)
        bram_parallel  : out std_logic;

        bram1_en   : out std_logic;
        bram1_we   : out std_logic;
        bram1_addr : out std_logic_vector(11 downto 0);
        bram1_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        bram1_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        bram2_en   : out std_logic;
        bram2_we   : out std_logic;
        bram2_addr : out std_logic_vector(11 downto 0);
        bram2_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        bram2_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        bram3_en   : out std_logic;
        bram3_we   : out std_logic;
        bram3_addr : out std_logic_vector(11 downto 0);
        bram3_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        bram3_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        bram4_en   : out std_logic;
        bram4_we   : out std_logic;
        bram4_addr : out std_logic_vector(11 downto 0);
        bram4_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        bram4_dout : in  std_logic_vector(DATA_BITS-1 downto 0)
    );
end entity pathfinder_ip;

architecture rtl of pathfinder_ip is

    constant BRAM_DEPTH : integer := 2500;

    type state_t is (
        IDLE,
        EVAL_START,
        EVAL_READ,
        EVAL_WAIT,
        EVAL_PROCESS,
        EVAL_WRITE,
        EVAL_NEXT,
        MOVE_NEXT,
        MOVE_READ_P,
        MOVE_WAIT_P,
        MOVE_PROCESS_P,
        MOVE_NEXT_P,
        DONE
    );

    signal state : state_t := IDLE;

    signal start_x : unsigned(6 downto 0) := (others => '0');
    signal start_y : unsigned(6 downto 0) := (others => '0');
    signal end_x   : unsigned(6 downto 0) := (others => '0');
    signal end_y   : unsigned(6 downto 0) := (others => '0');

    signal current_x : unsigned(6 downto 0) := (others => '0');
    signal current_y : unsigned(6 downto 0) := (others => '0');

    signal eval_i : unsigned(6 downto 0) := (others => '0');
    signal eval_j : unsigned(6 downto 0) := (others => '0');

    -- Pomocni signali za move deo koji prate ternutni min_dist node
    signal scan_x    : unsigned(6 downto 0) := (others => '0');
    signal scan_y    : unsigned(6 downto 0) := (others => '0');

    signal min_dist  : unsigned(8 downto 0) := (others => '1');  -- inicijalizovano na 511 kako bi svaki validan node bio manji
    signal next_x    : unsigned(6 downto 0) := (others => '1');  -- inicijalizovano na vrednost 127 koja je van opsega (0-99)
    signal next_y    : unsigned(6 downto 0) := (others => '1');

    signal solved    : std_logic := '0';  -- solved fleg

    -- interni BRAM signali
    signal bram_addr_int : unsigned(ADDR_BITS-1 downto 0) := (others => '0');
    signal bram_we_int   : std_logic := '0';
    signal bram_din_int  : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
    
    signal current_node : std_logic_vector(DATA_BITS-1 downto 0);

    signal pscan_x1 : unsigned(6 downto 0) := (others => '0');
    signal pscan_y1 : unsigned(6 downto 0) := (others => '0');
    signal pscan_x2 : unsigned(6 downto 0) := (others => '0');
    signal pscan_y2 : unsigned(6 downto 0) := (others => '0');
    signal pscan_x3 : unsigned(6 downto 0) := (others => '0');
    signal pscan_y3 : unsigned(6 downto 0) := (others => '0');
    signal pscan_x4 : unsigned(6 downto 0) := (others => '0');
    signal pscan_y4 : unsigned(6 downto 0) := (others => '0');

    signal min_dist1 : unsigned(8 downto 0) := (others => '1');
    signal next_x1   : unsigned(6 downto 0) := (others => '1');
    signal next_y1   : unsigned(6 downto 0) := (others => '1');
    signal min_dist2 : unsigned(8 downto 0) := (others => '1');
    signal next_x2   : unsigned(6 downto 0) := (others => '1');
    signal next_y2   : unsigned(6 downto 0) := (others => '1');
    signal min_dist3 : unsigned(8 downto 0) := (others => '1');
    signal next_x3   : unsigned(6 downto 0) := (others => '1');
    signal next_y3   : unsigned(6 downto 0) := (others => '1');
    signal min_dist4 : unsigned(8 downto 0) := (others => '1');
    signal next_x4   : unsigned(6 downto 0) := (others => '1');
    signal next_y4   : unsigned(6 downto 0) := (others => '1');

    signal bram_parallel_int : std_logic := '0';

begin

    bram_en   <= '1';
    bram_we   <= bram_we_int;
    bram_addr <= std_logic_vector(bram_addr_int);
    bram_din  <= bram_din_int;

    bram_parallel <= bram_parallel_int;

    p_cpu_regs : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                start_x <= (others => '0');
                start_y <= (others => '0');
                end_x   <= (others => '0');
                end_y   <= (others => '0');
            elsif cpu_we = '1' then
                case cpu_addr is
                    when "00" =>   -- START koordinate
                        start_x <= unsigned(cpu_wdata(13 downto 7));
                        start_y <= unsigned(cpu_wdata(6  downto 0));
                    when "01" =>   -- END koordinate
                        end_x   <= unsigned(cpu_wdata(13 downto 7));
                        end_y   <= unsigned(cpu_wdata(6  downto 0));
                    when others => -- "10" se tumaci kao start signal u FSM-u
                        null;
                end case;
            end if;
        end if;
    end process p_cpu_regs;

    p_fsm : process(clk)

        -- Funkcija za proracun adrese na osnovu x i y koord
        function bram_flat(x, y : unsigned(6 downto 0)) return unsigned is
        begin
            return (x * GRID_SIZE) + resize(y, ADDR_BITS);
        end function;

        -- Funkcija za proracun heuristike
        -- dx = |endX - i|,  dy = |endY - j|
        -- dist = 2*|dx-dy| + 3*min(dx,dy)
        function heuristic(
            ix, iy   : unsigned(6 downto 0);
            ex, ey   : unsigned(6 downto 0)
        ) return unsigned is
            variable dx, dy, diff, minv : unsigned(6 downto 0);
            variable result             : unsigned(8 downto 0);
        begin
            if ex >= ix then 
                dx := ex - ix; 
            else
                dx := ix - ex;
            end if;
            
            if ey >= iy then
                dy := ey - iy;
            else
                dy := iy - ey;
            end if;
            
            if dx >= dy then
                diff := dx - dy;
                minv := dy;
            else
                diff := dy - dx;
                minv := dx;   
            end if;
            
            result := resize(2*diff, 9) + resize(3*minv, 9);
            
            return result;
        end function;

        function bram_sub(flat : unsigned(ADDR_BITS-1 downto 0)) return std_logic_vector is
            variable sub : unsigned(11 downto 0);
        begin
            if flat < BRAM_DEPTH then
                sub := resize(flat, 12);
            elsif flat < 2*BRAM_DEPTH then
                sub := resize(flat - BRAM_DEPTH, 12);
            elsif flat < 3*BRAM_DEPTH then
                sub := resize(flat - 2*BRAM_DEPTH, 12); 
            else
                sub := resize(flat - 3*BRAM_DEPTH, 12);
            end if;
            return std_logic_vector(sub);
        end function;

        variable v_dist    : unsigned(8 downto 0);
        variable v_visited : std_logic;
        variable v_new_data: std_logic_vector(DATA_BITS-1 downto 0);

        variable v_dist1    : unsigned(8 downto 0);
        variable v_visited1 : std_logic;
        variable v_dist2    : unsigned(8 downto 0);
        variable v_visited2 : std_logic;
        variable v_dist3    : unsigned(8 downto 0);
        variable v_visited3 : std_logic;
        variable v_dist4    : unsigned(8 downto 0);
        variable v_visited4 : std_logic;

        variable cur_flat : unsigned(ADDR_BITS-1 downto 0);

    begin
        if rising_edge(clk) then
            -- podrazumevano: nema pisanja u BRAM, i nema interrupta
            bram_we_int <= '0';
            irq         <= '0';

            bram1_en <= '0'; bram1_we <= '0'; bram1_addr <= (others => '0'); bram1_din <= (others => '0');
            bram2_en <= '0'; bram2_we <= '0'; bram2_addr <= (others => '0'); bram2_din <= (others => '0');
            bram3_en <= '0'; bram3_we <= '0'; bram3_addr <= (others => '0'); bram3_din <= (others => '0');
            bram4_en <= '0'; bram4_we <= '0'; bram4_addr <= (others => '0'); bram4_din <= (others => '0');

            if rst = '0' then
                state     <= IDLE;
                solved    <= '0';
                min_dist  <= (others => '1');
                next_x    <= (others => '1');
                next_y    <= (others => '1');
                bram_parallel_int <= '0';
            else
                case state is

                    when IDLE =>
                        solved   <= '0';
                        min_dist <= (others => '1');
                        next_x   <= (others => '1');
                        next_y   <= (others => '1');

                        if cpu_we = '1' and cpu_addr = "10" then
                            current_x <= start_x;
                            current_y <= start_y;
                            state     <= EVAL_START;
                        end if;

                    when EVAL_START =>
                        eval_i <= current_x - 1;  -- ako je current_x nula, doci ce do underflow-a i bice "1111 111" odnosno 127
                        eval_j <= current_y - 1;  -- ako je current_y nula, doci ce do underflow-a i bice "1111 111" odnosno 127
                        state  <= EVAL_READ;
                    
                    when EVAL_READ =>
                        if eval_i = 127 or eval_i >= GRID_SIZE or eval_j = 127 or eval_j >= GRID_SIZE or (eval_i = current_x and eval_j = current_y) then
                            state <= EVAL_NEXT;
                        else
                            bram_addr_int <= bram_flat(eval_i, eval_j);
                            bram_we_int   <= '0';
                            state         <= EVAL_WAIT;
                        end if;

                    when EVAL_WAIT =>
                        -- Potrosimo jedan ciklus na "prazno" stanje, kako bismo sacekali BRAM
                        state <= EVAL_PROCESS;

                    when EVAL_PROCESS =>
                        v_dist    := unsigned(bram_dout(23 downto 15));
                        v_visited := bram_dout(0);
                    
                        if v_dist = 300 then --300 je sentinel vrednost za END node
                            v_new_data(23 downto 15) := std_logic_vector(to_unsigned(300, 9)); -- ne menja se vrednost END node-a
                            v_new_data(14 downto 8)  := std_logic_vector(current_x); --dodela X koordinate roditelja 
                            v_new_data(7  downto 1)  := std_logic_vector(current_y); --dodela Y koordinate roditelja
                            v_new_data(0)            := v_visited; --evaluate ne dira visited bit
                            bram_din_int  <= v_new_data;
                            bram_addr_int <= bram_flat(eval_i, eval_j);
                            bram_we_int   <= '1';
                            solved        <= '1';
                            state         <= EVAL_WRITE;
                    
                        elsif v_dist = 0 then --0 distanca znaci da je neposecen PATH node kojem nije odredjena heuristika
                            v_new_data(23 downto 15) := std_logic_vector(heuristic(eval_i, eval_j, end_x, end_y)); --distanca se postavlja na izracunatu heuristiku
                            v_new_data(14 downto 8)  := std_logic_vector(current_x); --dodela X koordinate roditelja
                            v_new_data(7  downto 1)  := std_logic_vector(current_y); --dodela Y koordinate roditelja
                            v_new_data(0)            := v_visited; --evaluate ne dira visited bit
                            bram_din_int  <= v_new_data;
                            bram_addr_int <= bram_flat(eval_i, eval_j);
                            bram_we_int   <= '1';
                            state         <= EVAL_WRITE;
                    
                        else
                            -- za WALL ili START nodeove se ne evaluira heuristika
                            state <= EVAL_NEXT;
                        end if;

                    when EVAL_WRITE =>
                        -- trosenje praznog ciklusa za BRAM write
                        state <= EVAL_NEXT;

                    when EVAL_NEXT =>
                        if solved = '1' then
                            state <= DONE;
                        else
                            if eval_j < current_y + 1 or eval_j = 127 then --eval_j = 127 je "minus jedan" zbog underflow-a, pa ce sledeca linija da overflow-uje nazad na nulu
                                eval_j <= eval_j + 1;
                                state  <= EVAL_READ;
                            elsif eval_i < current_x + 1 or eval_i = 127 then --eval_i = 127 je "minus jedan" zbog underflow-a, pa ce sledeca linija da overflow-uje nazad na nulu
                                eval_i <= eval_i + 1;
                                eval_j <= current_y - 1;
                                state  <= EVAL_READ;
                            else
                                min_dist1 <= (others => '1'); next_x1 <= (others => '1'); next_y1 <= (others => '1');
                                min_dist2 <= (others => '1'); next_x2 <= (others => '1'); next_y2 <= (others => '1');
                                min_dist3 <= (others => '1'); next_x3 <= (others => '1'); next_y3 <= (others => '1');
                                min_dist4 <= (others => '1'); next_x4 <= (others => '1'); next_y4 <= (others => '1');

                                pscan_x1 <= to_unsigned(0,  7); pscan_y1 <= to_unsigned(0, 7);
                                pscan_x2 <= to_unsigned(25, 7); pscan_y2 <= to_unsigned(0, 7);
                                pscan_x3 <= to_unsigned(50, 7); pscan_y3 <= to_unsigned(0, 7);
                                pscan_x4 <= to_unsigned(75, 7); pscan_y4 <= to_unsigned(0, 7);
                                bram_parallel_int <= '1';
                                state <= MOVE_READ_P;
                            end if;
                        end if;

                    when MOVE_READ_P =>
                        bram1_en   <= '1';
                        bram1_we   <= '0';
                        bram1_addr <= bram_sub(bram_flat(pscan_x1, pscan_y1));
                        bram2_en   <= '1';
                        bram2_we   <= '0';
                        bram2_addr <= bram_sub(bram_flat(pscan_x2, pscan_y2));
                        bram3_en   <= '1';
                        bram3_we   <= '0';
                        bram3_addr <= bram_sub(bram_flat(pscan_x3, pscan_y3));
                        bram4_en   <= '1';
                        bram4_we   <= '0';
                        bram4_addr <= bram_sub(bram_flat(pscan_x4, pscan_y4));
                        state <= MOVE_WAIT_P;

                    when MOVE_WAIT_P =>
                        state <= MOVE_PROCESS_P;

                    when MOVE_PROCESS_P =>
                        v_dist1    := unsigned(bram1_dout(23 downto 15));
                        v_visited1 := bram1_dout(0);
                        if pscan_x1 = current_x and pscan_y1 = current_y then
                            current_node <= bram1_dout;
                        end if;
                        if v_visited1 = '0' and v_dist1 > 0 and v_dist1 < 298 and v_dist1 < min_dist1 then
                            min_dist1 <= v_dist1; next_x1 <= pscan_x1; next_y1 <= pscan_y1;
                        end if;

                        v_dist2    := unsigned(bram2_dout(23 downto 15));
                        v_visited2 := bram2_dout(0);
                        if pscan_x2 = current_x and pscan_y2 = current_y then
                            current_node <= bram2_dout;
                        end if;
                        if v_visited2 = '0' and v_dist2 > 0 and v_dist2 < 298 and v_dist2 < min_dist2 then
                            min_dist2 <= v_dist2; next_x2 <= pscan_x2; next_y2 <= pscan_y2;
                        end if;

                        v_dist3    := unsigned(bram3_dout(23 downto 15));
                        v_visited3 := bram3_dout(0);
                        if pscan_x3 = current_x and pscan_y3 = current_y then
                            current_node <= bram3_dout;
                        end if;
                        if v_visited3 = '0' and v_dist3 > 0 and v_dist3 < 298 and v_dist3 < min_dist3 then
                            min_dist3 <= v_dist3; next_x3 <= pscan_x3; next_y3 <= pscan_y3;
                        end if;

                        v_dist4    := unsigned(bram4_dout(23 downto 15));
                        v_visited4 := bram4_dout(0);
                        if pscan_x4 = current_x and pscan_y4 = current_y then
                            current_node <= bram4_dout;
                        end if;
                        if v_visited4 = '0' and v_dist4 > 0 and v_dist4 < 298 and v_dist4 < min_dist4 then
                            min_dist4 <= v_dist4; next_x4 <= pscan_x4; next_y4 <= pscan_y4;
                        end if;

                        state <= MOVE_NEXT_P;

                    when MOVE_NEXT_P =>
                        if pscan_y1 < GRID_SIZE - 1 then
                            pscan_y1 <= pscan_y1 + 1;
                            pscan_y2 <= pscan_y2 + 1;
                            pscan_y3 <= pscan_y3 + 1;
                            pscan_y4 <= pscan_y4 + 1;
                        elsif pscan_x1 < 24 then
                            pscan_x1 <= pscan_x1 + 1; pscan_y1 <= (others => '0');
                            pscan_x2 <= pscan_x2 + 1; pscan_y2 <= (others => '0');
                            pscan_x3 <= pscan_x3 + 1; pscan_y3 <= (others => '0');
                            pscan_x4 <= pscan_x4 + 1; pscan_y4 <= (others => '0');
                        end if;

                        if (pscan_x1 = 24 and pscan_y1 = GRID_SIZE - 1) then
                            min_dist <= (others => '1');
                            next_x   <= (others => '1');
                            next_y   <= (others => '1');
                            if min_dist1 < min_dist2 and min_dist1 < min_dist3 and min_dist1 < min_dist4 then
                                min_dist <= min_dist1; next_x <= next_x1; next_y <= next_y1;
                            elsif min_dist2 < min_dist3 and min_dist2 < min_dist4 then
                                min_dist <= min_dist2; next_x <= next_x2; next_y <= next_y2;
                            elsif min_dist3 < min_dist4 then
                                min_dist <= min_dist3; next_x <= next_x3; next_y <= next_y3;
                            else
                                min_dist <= min_dist4; next_x <= next_x4; next_y <= next_y4;
                            end if;
                            bram_parallel_int <= '0';
                            state <= MOVE_NEXT;
                        else
                            state <= MOVE_READ_P;
                        end if;
                    when MOVE_NEXT =>
                        if next_x = "1111111" or next_y = "1111111" then
                            --next_x i next_y nisu pomereni, znaci da nema vise validnih node_ova i mapa je neresiva
                            state <= DONE;
                        else
                            bram_addr_int <= bram_flat(current_x, current_y);
                            bram_we_int   <= '1';
                            bram_din_int <= current_node(DATA_BITS-1 downto 1) & '1'; --setuje se visited bit
                            -- prelazak u sledeci node
                            current_x <= next_x;
                            current_y <= next_y;
                            -- sledeca iteracija algoritma
                            state <= EVAL_START;
                        end if;
                    -- -------------------------------------------------------
                    when DONE =>
                        irq   <= '1';   -- prekid ka CPU
                        state <= IDLE;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process p_fsm;

end architecture rtl;