library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity tb is
end tb;

architecture Behavioral of tb is

    function slv_to_str(slv : std_logic_vector) return string is
        variable result : string(1 to slv'length);
        variable idx    : integer := 1;
    begin
        for i in slv'range loop
            case slv(i) is
                when '0'    => result(idx) := '0';
                when '1'    => result(idx) := '1';
                when 'X'    => result(idx) := 'X';
                when 'Z'    => result(idx) := 'Z';
                when 'U'    => result(idx) := 'U';
                when others => result(idx) := '?';
            end case;
            idx := idx + 1;
        end loop;
        return result;
    end function;

    constant CLK_PERIOD    : time    := 10 ns;   -- 100 MHz
    constant BRAM_DEPTH    : integer := 2500;
    constant TOTAL_DEPTH   : integer := 10000;
    constant BRAM_INIT     : string  := "C:/bram_init2.txt";
    constant BRAM_DUMP     : string  := "C:/test2/bram_dump2.txt";

    constant START_X : integer := 5;
    constant START_Y : integer := 5;
    constant END_X   : integer := 99;
    constant END_Y   : integer := 99;

    constant START_COORD : std_logic_vector(13 downto 0) :=
        std_logic_vector(to_unsigned(START_X, 7)) & std_logic_vector(to_unsigned(START_Y, 7));
    constant END_COORD   : std_logic_vector(13 downto 0) :=
        std_logic_vector(to_unsigned(END_X, 7))   & std_logic_vector(to_unsigned(END_Y, 7));

    signal clka  : std_logic := '0';

    signal ena1  : std_logic := '1';
    signal wea1  : std_logic := '0';
    signal addra1: std_logic_vector(11 downto 0) := (others => '0');
    signal dina1 : std_logic_vector(23 downto 0) := (others => '0');
    signal douta1: std_logic_vector(23 downto 0);

    signal ena2  : std_logic := '1';
    signal wea2  : std_logic := '0';
    signal addra2: std_logic_vector(11 downto 0) := (others => '0');
    signal dina2 : std_logic_vector(23 downto 0) := (others => '0');
    signal douta2: std_logic_vector(23 downto 0);

    signal ena3  : std_logic := '1';
    signal wea3  : std_logic := '0';
    signal addra3: std_logic_vector(11 downto 0) := (others => '0');
    signal dina3 : std_logic_vector(23 downto 0) := (others => '0');
    signal douta3: std_logic_vector(23 downto 0);

    signal ena4  : std_logic := '1';
    signal wea4  : std_logic := '0';
    signal addra4: std_logic_vector(11 downto 0) := (others => '0');
    signal dina4 : std_logic_vector(23 downto 0) := (others => '0');
    signal douta4: std_logic_vector(23 downto 0);

    signal load_done : std_logic := '0';

    signal rst_ip       : std_logic := '0';

    signal cpu_we_ip    : std_logic := '0';
    signal cpu_addr_ip  : std_logic_vector(1 downto 0) := (others => '0');
    signal cpu_wdata_ip : std_logic_vector(13 downto 0) := (others => '0');

    signal bram_en_ip   : std_logic;
    signal bram_we_ip   : std_logic;
    signal bram_addr_ip : std_logic_vector(13 downto 0);
    signal bram_din_ip  : std_logic_vector(23 downto 0);
    signal bram_dout_ip : std_logic_vector(23 downto 0);

    signal bram_parallel_ip : std_logic;

    signal bram1_en_ip   : std_logic;
    signal bram1_we_ip   : std_logic;
    signal bram1_addr_ip : std_logic_vector(11 downto 0);
    signal bram1_din_ip  : std_logic_vector(23 downto 0);
    signal bram1_dout_ip : std_logic_vector(23 downto 0);

    signal bram2_en_ip   : std_logic;
    signal bram2_we_ip   : std_logic;
    signal bram2_addr_ip : std_logic_vector(11 downto 0);
    signal bram2_din_ip  : std_logic_vector(23 downto 0);
    signal bram2_dout_ip : std_logic_vector(23 downto 0);

    signal bram3_en_ip   : std_logic;
    signal bram3_we_ip   : std_logic;
    signal bram3_addr_ip : std_logic_vector(11 downto 0);
    signal bram3_din_ip  : std_logic_vector(23 downto 0);
    signal bram3_dout_ip : std_logic_vector(23 downto 0);

    signal bram4_en_ip   : std_logic;
    signal bram4_we_ip   : std_logic;
    signal bram4_addr_ip : std_logic_vector(11 downto 0);
    signal bram4_din_ip  : std_logic_vector(23 downto 0);
    signal bram4_dout_ip : std_logic_vector(23 downto 0);

    signal irq_ip : std_logic;

    signal enb1  : std_logic;
    signal web1  : std_logic;
    signal addrb1: std_logic_vector(11 downto 0);
    signal dinb1 : std_logic_vector(23 downto 0);

    signal enb2  : std_logic;
    signal web2  : std_logic;
    signal addrb2: std_logic_vector(11 downto 0);
    signal dinb2 : std_logic_vector(23 downto 0);

    signal enb3  : std_logic;
    signal web3  : std_logic;
    signal addrb3: std_logic_vector(11 downto 0);
    signal dinb3 : std_logic_vector(23 downto 0);

    signal enb4  : std_logic;
    signal web4  : std_logic;
    signal addrb4: std_logic_vector(11 downto 0);
    signal dinb4 : std_logic_vector(23 downto 0);

    signal global_sel     : integer range 1 to 4;
    signal global_subaddr : std_logic_vector(11 downto 0);

begin

    process(bram_addr_ip)
        variable full : unsigned(13 downto 0);
        variable sub  : unsigned(11 downto 0);
        variable sel  : integer range 1 to 4;
    begin
        full := unsigned(bram_addr_ip);
        if full < BRAM_DEPTH then
            sel := 1; sub := resize(full, 12);
        elsif full < 2*BRAM_DEPTH then
            sel := 2; sub := resize(full - BRAM_DEPTH, 12);
        elsif full < 3*BRAM_DEPTH then
            sel := 3; sub := resize(full - 2*BRAM_DEPTH, 12);
        else
            sel := 4; sub := resize(full - 3*BRAM_DEPTH, 12);
        end if;
        global_sel     <= sel;
        global_subaddr <= std_logic_vector(sub);
    end process;

    process(bram_parallel_ip,
            bram_en_ip, bram_we_ip, global_subaddr, bram_din_ip, global_sel,
            bram1_en_ip, bram1_we_ip, bram1_addr_ip, bram1_din_ip,
            bram2_en_ip, bram2_we_ip, bram2_addr_ip, bram2_din_ip,
            bram3_en_ip, bram3_we_ip, bram3_addr_ip, bram3_din_ip,
            bram4_en_ip, bram4_we_ip, bram4_addr_ip, bram4_din_ip)
    begin
        if bram_parallel_ip = '0' then
            enb1  <= bram_en_ip; addrb1 <= global_subaddr; dinb1 <= bram_din_ip;
            enb2  <= bram_en_ip; addrb2 <= global_subaddr; dinb2 <= bram_din_ip;
            enb3  <= bram_en_ip; addrb3 <= global_subaddr; dinb3 <= bram_din_ip;
            enb4  <= bram_en_ip; addrb4 <= global_subaddr; dinb4 <= bram_din_ip;
            if global_sel = 1 then
                web1 <= bram_we_ip; web2 <= '0'; web3 <= '0'; web4 <= '0';
            elsif global_sel = 2 then
                web1 <= '0'; web2 <= bram_we_ip; web3 <= '0'; web4 <= '0';
            elsif global_sel = 3 then
                web1 <= '0'; web2 <= '0'; web3 <= bram_we_ip; web4 <= '0';
            else
                web1 <= '0'; web2 <= '0'; web3 <= '0'; web4 <= bram_we_ip;
            end if;
        else
            enb1  <= bram1_en_ip; web1 <= bram1_we_ip; addrb1 <= bram1_addr_ip; dinb1 <= bram1_din_ip;
            enb2  <= bram2_en_ip; web2 <= bram2_we_ip; addrb2 <= bram2_addr_ip; dinb2 <= bram2_din_ip;
            enb3  <= bram3_en_ip; web3 <= bram3_we_ip; addrb3 <= bram3_addr_ip; dinb3 <= bram3_din_ip;
            enb4  <= bram4_en_ip; web4 <= bram4_we_ip; addrb4 <= bram4_addr_ip; dinb4 <= bram4_din_ip;
        end if;
    end process;

    process(global_sel, bram1_dout_ip, bram2_dout_ip, bram3_dout_ip, bram4_dout_ip)
    begin
        case global_sel is
            when 1      => bram_dout_ip <= bram1_dout_ip;
            when 2      => bram_dout_ip <= bram2_dout_ip;
            when 3      => bram_dout_ip <= bram3_dout_ip;
            when others => bram_dout_ip <= bram4_dout_ip;
        end case;
    end process;

    bram1TB : entity work.bram
        port map (
            clka  => clka,
            ena   => ena1,
            wea   => wea1,
            addra => addra1,
            dina  => dina1,
            douta => douta1,
            enb   => enb1,
            web   => web1,
            addrb => addrb1,
            dinb  => dinb1,
            doutb => bram1_dout_ip
        );

    bram2TB : entity work.bram
        port map (
            clka  => clka,
            ena   => ena2,
            wea   => wea2,
            addra => addra2,
            dina  => dina2,
            douta => douta2,
            enb   => enb2,
            web   => web2,
            addrb => addrb2,
            dinb  => dinb2,
            doutb => bram2_dout_ip
        );

    bram3TB : entity work.bram
        port map (
            clka  => clka,
            ena   => ena3,
            wea   => wea3,
            addra => addra3,
            dina  => dina3,
            douta => douta3,
            enb   => enb3,
            web   => web3,
            addrb => addrb3,
            dinb  => dinb3,
            doutb => bram3_dout_ip
        );

    bram4TB : entity work.bram
        port map (
            clka  => clka,
            ena   => ena4,
            wea   => wea4,
            addra => addra4,
            dina  => dina4,
            douta => douta4,
            enb   => enb4,
            web   => web4,
            addrb => addrb4,
            dinb  => dinb4,
            doutb => bram4_dout_ip
        );

    uut : entity work.pathfinder_ip
        generic map (
            GRID_SIZE => 100,
            ADDR_BITS => 14,
            DATA_BITS => 24
        )
        port map (
            clk       => clka,
            rst       => rst_ip,

            cpu_we    => cpu_we_ip,
            cpu_addr  => cpu_addr_ip,
            cpu_wdata => cpu_wdata_ip,

            bram_en   => bram_en_ip,
            bram_we   => bram_we_ip,
            bram_addr => bram_addr_ip,
            bram_din  => bram_din_ip,
            bram_dout => bram_dout_ip,

            irq       => irq_ip,

            bram_parallel => bram_parallel_ip,

            bram1_en   => bram1_en_ip,
            bram1_we   => bram1_we_ip,
            bram1_addr => bram1_addr_ip,
            bram1_din  => bram1_din_ip,
            bram1_dout => bram1_dout_ip,

            bram2_en   => bram2_en_ip,
            bram2_we   => bram2_we_ip,
            bram2_addr => bram2_addr_ip,
            bram2_din  => bram2_din_ip,
            bram2_dout => bram2_dout_ip,

            bram3_en   => bram3_en_ip,
            bram3_we   => bram3_we_ip,
            bram3_addr => bram3_addr_ip,
            bram3_din  => bram3_din_ip,
            bram3_dout => bram3_dout_ip,

            bram4_en   => bram4_en_ip,
            bram4_we   => bram4_we_ip,
            bram4_addr => bram4_addr_ip,
            bram4_din  => bram4_din_ip,
            bram4_dout => bram4_dout_ip
        );

    clk_proc : process
    begin
        clka <= '0';
        wait for CLK_PERIOD / 2;
        clka <= '1';
        wait for CLK_PERIOD / 2;
    end process;
        
    load_proc : process
        file     init_file : text;
        variable row       : line;
        variable data_slv  : std_logic_vector(23 downto 0);
        variable addr_int  : integer := 0;
        variable open_ok   : file_open_status;
        file     dump_file : text;
        variable node      : std_logic_vector(23 downto 0);
        variable sub_addr  : integer;
    begin
        rst_ip <= '0';
        wea1   <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';

        wait until rising_edge(clka);
        wait until rising_edge(clka);

        file_open(open_ok, init_file, BRAM_INIT, read_mode);

        if open_ok /= open_ok then
            report "GRESKA: Nije moguce otvoriti fajl: " & BRAM_INIT severity failure;
        end if;

        report "------------------------------------------------------------"
            severity note;
        report "[LOAD] Pocetak ucitavanja fajla: " & BRAM_INIT severity note;

        addr_int := 0;
        ena1 <= '1'; ena2 <= '1'; ena3 <= '1'; ena4 <= '1';

        while (not endfile(init_file)) and (addr_int < TOTAL_DEPTH) loop
            readline(init_file, row);
            if row'length > 0 then
                read(row, data_slv);
                sub_addr := addr_int mod BRAM_DEPTH;
                if addr_int < BRAM_DEPTH then
                    addra1 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina1  <= data_slv;
                    wea1 <= '1'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';
                elsif addr_int < 2*BRAM_DEPTH then
                    addra2 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina2  <= data_slv;
                    wea1 <= '0'; wea2 <= '1'; wea3 <= '0'; wea4 <= '0';
                elsif addr_int < 3*BRAM_DEPTH then
                    addra3 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina3  <= data_slv;
                    wea1 <= '0'; wea2 <= '0'; wea3 <= '1'; wea4 <= '0';
                else
                    addra4 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina4  <= data_slv;
                    wea1 <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '1';
                end if;
                wait until rising_edge(clka);
                addr_int := addr_int + 1;
            end if;
        end loop;

        file_close(init_file);
        wea1 <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';

        report "[LOAD] Ucitavanje zavrseno. Upisano " &
               integer'image(addr_int) & " lokacija u BRAM." severity note;

        load_done <= '1';

        report "------------------------------------------------------------"
            severity note;
        report "[RESET] Dizanje reseta na 1, IP se pokrece."
            severity note;

        rst_ip <= '1';
        wait until rising_edge(clka);   -- IP registruje rst='1'

        report "[RESET] IP is now active." severity note;

        report "------------------------------------------------------------"
            severity note;
        report "[CPU] Writing START register: (" &
               integer'image(START_X) & "," & integer'image(START_Y) &
               ") -> cpu_wdata = " & slv_to_str(START_COORD)
            severity note;

        cpu_addr_ip  <= "00";
        cpu_wdata_ip <= START_COORD;
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        wait until rising_edge(clka);

        report "[CPU] Writing END register: (" &
               integer'image(END_X) & "," & integer'image(END_Y) &
               ") -> cpu_wdata = " & slv_to_str(END_COORD)
            severity note;

        cpu_addr_ip  <= "01";
        cpu_wdata_ip <= END_COORD;
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        wait until rising_edge(clka);

        report "[CPU] Sending START pulse (cpu_addr = ""10"")";
        report "------------------------------------------------------------";
        report "[RUN] Pathfinder running. Waiting for IRQ...";
        report "------------------------------------------------------------";

        cpu_addr_ip  <= "10";
        cpu_wdata_ip <= (others => '0');
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        cpu_addr_ip  <= (others => '0');
        cpu_wdata_ip <= (others => '0');
        
        wait until irq_ip = '1';
        wait until rising_edge(clka);

        file_open(open_ok, dump_file, BRAM_DUMP, write_mode);

        if open_ok /= open_ok then
            report "[DUMP] GRESKA: Nije moguce otvoriti dump fajl: " & BRAM_DUMP severity failure;
        end if;

        for i in 0 to TOTAL_DEPTH - 1 loop
            sub_addr := i mod BRAM_DEPTH;
            if i < BRAM_DEPTH then
                addra1 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clka);
                wait until rising_edge(clka);
                write(row, douta1);
            elsif i < 2*BRAM_DEPTH then
                addra2 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clka);
                wait until rising_edge(clka);
                write(row, douta2);
            elsif i < 3*BRAM_DEPTH then
                addra3 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clka);
                wait until rising_edge(clka);
                write(row, douta3);
            else
                addra4 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clka);
                wait until rising_edge(clka);
                write(row, douta4);
            end if;
            writeline(dump_file, row);
        end loop;

        file_close(dump_file);
        report "[DUMP] Dump zavrsen." severity failure;

        wait;
    end process;

end Behavioral;