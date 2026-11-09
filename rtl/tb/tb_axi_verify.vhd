library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity tb_axi_verify is
end entity tb_axi_verify;

architecture sim of tb_axi_verify is

    constant CLK_PERIOD  : time := 10 ns;
    constant BRAM_DEPTH  : integer := 2500;
    constant TOTAL_DEPTH : integer := 10000;

    constant BRAM_INIT   : string  := "C:/test/bram_init_2.txt";
    constant BRAM_DUMP   : string  := "C:/test/bram_dump_axi.txt";

    constant START_X : integer := 5;
    constant START_Y : integer := 5;
    constant END_X   : integer := 99;
    constant END_Y   : integer := 99;

    constant START_COORD : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(START_X, 7)) & std_logic_vector(to_unsigned(START_Y, 7));
    constant END_COORD   : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(END_X, 7))   & std_logic_vector(to_unsigned(END_Y, 7));

    signal clk     : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- AXI signali
    signal awaddr  : std_logic_vector(3 downto 0) := (others => '0');
    signal awvalid : std_logic := '0';
    signal awready : std_logic;
    signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal wvalid  : std_logic := '0';
    signal wready  : std_logic;
    signal wstrb   : std_logic_vector(3 downto 0) := (others => '1');
    signal bresp   : std_logic_vector(1 downto 0);
    signal bvalid  : std_logic;
    signal bready  : std_logic := '0';
    signal araddr  : std_logic_vector(3 downto 0) := (others => '0');
    signal arvalid : std_logic := '0';
    signal arready : std_logic;
    signal rdata   : std_logic_vector(31 downto 0);
    signal rresp   : std_logic_vector(1 downto 0);
    signal rvalid  : std_logic;
    signal rready  : std_logic := '0';
    signal irq_out : std_logic;

    signal bram_en    : std_logic;
    signal bram_we    : std_logic;
    signal bram_addr  : std_logic_vector(13 downto 0);
    signal bram_din   : std_logic_vector(23 downto 0);
    signal bram_dout  : std_logic_vector(23 downto 0);

    signal bram_parallel : std_logic;

    signal bram_parallel_d : std_logic := '0';
    signal iter_count      : integer   := 0;

    signal bram1_en, bram2_en, bram3_en, bram4_en : std_logic;
    signal bram1_we, bram2_we, bram3_we, bram4_we : std_logic;
    signal bram1_addr, bram2_addr, bram3_addr, bram4_addr : std_logic_vector(11 downto 0);
    signal bram1_din, bram2_din, bram3_din, bram4_din     : std_logic_vector(23 downto 0);
    signal bram1_dout, bram2_dout, bram3_dout, bram4_dout : std_logic_vector(23 downto 0);

    signal phys1_en, phys2_en, phys3_en, phys4_en : std_logic;
    signal phys1_we, phys2_we, phys3_we, phys4_we : std_logic;
    signal phys1_addr, phys2_addr, phys3_addr, phys4_addr : std_logic_vector(11 downto 0);
    signal phys1_din, phys2_din, phys3_din, phys4_din     : std_logic_vector(23 downto 0);
    signal phys1_dout, phys2_dout, phys3_dout, phys4_dout : std_logic_vector(23 downto 0);

    signal ena1, ena2, ena3, ena4 : std_logic := '0';
    signal wea1, wea2, wea3, wea4 : std_logic := '0';
    signal addra1, addra2, addra3, addra4 : std_logic_vector(11 downto 0) := (others => '0');
    signal dina1, dina2, dina3, dina4     : std_logic_vector(23 downto 0) := (others => '0');
    signal douta1, douta2, douta3, douta4 : std_logic_vector(23 downto 0);

    signal doutb1, doutb2, doutb3, doutb4 : std_logic_vector(23 downto 0);

    signal load_done : std_logic := '0';

    signal mux1_en, mux2_en, mux3_en, mux4_en : std_logic;
    signal mux1_we, mux2_we, mux3_we, mux4_we : std_logic;
    signal mux1_addr, mux2_addr, mux3_addr, mux4_addr : std_logic_vector(11 downto 0);
    signal mux1_din, mux2_din, mux3_din, mux4_din     : std_logic_vector(23 downto 0);

begin

    mux1_en   <= ena1   when load_done = '0' else phys1_en;
    mux1_we   <= wea1   when load_done = '0' else phys1_we;
    mux1_addr <= addra1 when load_done = '0' else phys1_addr;
    mux1_din  <= dina1  when load_done = '0' else phys1_din;

    mux2_en   <= ena2   when load_done = '0' else phys2_en;
    mux2_we   <= wea2   when load_done = '0' else phys2_we;
    mux2_addr <= addra2 when load_done = '0' else phys2_addr;
    mux2_din  <= dina2  when load_done = '0' else phys2_din;

    mux3_en   <= ena3   when load_done = '0' else phys3_en;
    mux3_we   <= wea3   when load_done = '0' else phys3_we;
    mux3_addr <= addra3 when load_done = '0' else phys3_addr;
    mux3_din  <= dina3  when load_done = '0' else phys3_din;

    mux4_en   <= ena4   when load_done = '0' else phys4_en;
    mux4_we   <= wea4   when load_done = '0' else phys4_we;
    mux4_addr <= addra4 when load_done = '0' else phys4_addr;
    mux4_din  <= dina4  when load_done = '0' else phys4_din;

    dut : entity work.pathfinder_axi
        generic map (
            GRID_SIZE => 100,
            ADDR_BITS => 14,
            DATA_BITS => 24,
            C_S00_AXI_DATA_WIDTH => 32,
            C_S00_AXI_ADDR_WIDTH => 4
        )
        port map (
            irq_out => irq_out,

            bram_en    => bram_en,
            bram_we    => bram_we,
            bram_addr  => bram_addr,
            bram_din   => bram_din,
            bram_dout  => bram_dout,

            bram_parallel => bram_parallel,

            bram1_en => bram1_en, bram1_we => bram1_we, bram1_addr => bram1_addr, bram1_din => bram1_din, bram1_dout => bram1_dout,
            bram2_en => bram2_en, bram2_we => bram2_we, bram2_addr => bram2_addr, bram2_din => bram2_din, bram2_dout => bram2_dout,
            bram3_en => bram3_en, bram3_we => bram3_we, bram3_addr => bram3_addr, bram3_din => bram3_din, bram3_dout => bram3_dout,
            bram4_en => bram4_en, bram4_we => bram4_we, bram4_addr => bram4_addr, bram4_din => bram4_din, bram4_dout => bram4_dout,

            s00_axi_aclk    => clk,
            s00_axi_aresetn => aresetn,

            s00_axi_awaddr  => awaddr,
            s00_axi_awprot  => "000",
            s00_axi_awvalid => awvalid,
            s00_axi_awready => awready,

            s00_axi_wdata   => wdata,
            s00_axi_wstrb   => wstrb,
            s00_axi_wvalid  => wvalid,
            s00_axi_wready  => wready,

            s00_axi_bresp   => bresp,
            s00_axi_bvalid  => bvalid,
            s00_axi_bready  => bready,

            s00_axi_araddr  => araddr,
            s00_axi_arprot  => "000",
            s00_axi_arvalid => arvalid,
            s00_axi_arready => arready,

            s00_axi_rdata   => rdata,
            s00_axi_rresp   => rresp,
            s00_axi_rvalid  => rvalid,
            s00_axi_rready  => rready
        );

    router_inst : entity work.bram_router
        generic map (
            ADDR_BITS  => 14,
            SUB_BITS   => 12,
            DATA_BITS  => 24,
            BRAM_DEPTH => BRAM_DEPTH
        )
        port map (
            clk => clk,

            bram_parallel => bram_parallel,

            bram_en   => bram_en,
            bram_we   => bram_we,
            bram_addr => bram_addr,
            bram_din  => bram_din,
            bram_dout => bram_dout,

            bram1_en => bram1_en, bram1_we => bram1_we, bram1_addr => bram1_addr, bram1_din => bram1_din, bram1_dout => bram1_dout,
            bram2_en => bram2_en, bram2_we => bram2_we, bram2_addr => bram2_addr, bram2_din => bram2_din, bram2_dout => bram2_dout,
            bram3_en => bram3_en, bram3_we => bram3_we, bram3_addr => bram3_addr, bram3_din => bram3_din, bram3_dout => bram3_dout,
            bram4_en => bram4_en, bram4_we => bram4_we, bram4_addr => bram4_addr, bram4_din => bram4_din, bram4_dout => bram4_dout,

            phys1_en => phys1_en, phys1_we => phys1_we, phys1_addr => phys1_addr, phys1_din => phys1_din, phys1_dout => phys1_dout,
            phys2_en => phys2_en, phys2_we => phys2_we, phys2_addr => phys2_addr, phys2_din => phys2_din, phys2_dout => phys2_dout,
            phys3_en => phys3_en, phys3_we => phys3_we, phys3_addr => phys3_addr, phys3_din => phys3_din, phys3_dout => phys3_dout,
            phys4_en => phys4_en, phys4_we => phys4_we, phys4_addr => phys4_addr, phys4_din => phys4_din, phys4_dout => phys4_dout
        );

    bram1_inst : entity work.bram
        port map (
            clka  => clk,
            ena   => mux1_en,
            wea   => mux1_we,
            addra => mux1_addr,
            dina  => mux1_din,
            douta => phys1_dout,
            enb   => '1',
            web   => '0',
            addrb => addra1,
            dinb  => (others => '0'),
            doutb => doutb1
        );

    bram2_inst : entity work.bram
        port map (
            clka  => clk,
            ena   => mux2_en,
            wea   => mux2_we,
            addra => mux2_addr,
            dina  => mux2_din,
            douta => phys2_dout,
            enb   => '1',
            web   => '0',
            addrb => addra2,
            dinb  => (others => '0'),
            doutb => doutb2
        );

    bram3_inst : entity work.bram
        port map (
            clka  => clk,
            ena   => mux3_en,
            wea   => mux3_we,
            addra => mux3_addr,
            dina  => mux3_din,
            douta => phys3_dout,
            enb   => '1',
            web   => '0',
            addrb => addra3,
            dinb  => (others => '0'),
            doutb => doutb3
        );

    bram4_inst : entity work.bram
        port map (
            clka  => clk,
            ena   => mux4_en,
            wea   => mux4_we,
            addra => mux4_addr,
            dina  => mux4_din,
            douta => phys4_dout,
            enb   => '1',
            web   => '0',
            addrb => addra4,
            dinb  => (others => '0'),
            doutb => doutb4
        );

    douta1 <= doutb1;
    douta2 <= doutb2;
    douta3 <= doutb3;
    douta4 <= doutb4;

    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    iter_proc : process(clk)
    begin
        if rising_edge(clk) then
            bram_parallel_d <= bram_parallel;
            if bram_parallel = '1' and bram_parallel_d = '0' then
                iter_count <= iter_count + 1;
            end if;
        end if;
    end process;

    main_proc : process
        file     init_file  : text;
        variable row        : line;
        variable data_slv   : std_logic_vector(23 downto 0);
        variable addr_int   : integer := 0;
        variable open_ok    : file_open_status;
        file     dump_file  : text;
        variable sub_addr   : integer;
        variable t_start    : time;
        variable t_end      : time;
        variable n_cycles   : integer;

        procedure axi_write(addr : integer; data : integer) is
        begin
            wait until rising_edge(clk);
            awaddr  <= std_logic_vector(to_unsigned(addr, 4));
            awvalid <= '1';
            wdata   <= std_logic_vector(to_unsigned(data, 32));
            wvalid  <= '1';
            wait until rising_edge(clk) and awready = '1';
            wait until rising_edge(clk);
            awvalid <= '0';
            wvalid  <= '0';
            bready  <= '1';
            wait until rising_edge(clk) and bvalid = '1';
            wait until rising_edge(clk);
            bready  <= '0';
        end procedure;

    begin
        aresetn <= '0';
        wea1 <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        file_open(open_ok, init_file, BRAM_INIT, read_mode);
        if open_ok /= open_ok then
            report "GRESKA: Nije moguce otvoriti fajl: " & BRAM_INIT severity failure;
        end if;

        report "------------------------------------------------------------" severity note;
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
                    wea1   <= '1'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';
                elsif addr_int < 2*BRAM_DEPTH then
                    addra2 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina2  <= data_slv;
                    wea1   <= '0'; wea2 <= '1'; wea3 <= '0'; wea4 <= '0';
                elsif addr_int < 3*BRAM_DEPTH then
                    addra3 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina3  <= data_slv;
                    wea1   <= '0'; wea2 <= '0'; wea3 <= '1'; wea4 <= '0';
                else
                    addra4 <= std_logic_vector(to_unsigned(sub_addr, 12));
                    dina4  <= data_slv;
                    wea1   <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '1';
                end if;
                wait until rising_edge(clk);
                addr_int := addr_int + 1;
            end if;
        end loop;

        file_close(init_file);
        wea1 <= '0'; wea2 <= '0'; wea3 <= '0'; wea4 <= '0';
        ena1 <= '0'; ena2 <= '0'; ena3 <= '0'; ena4 <= '0';

        report "[LOAD] Ucitavanje zavrseno. Upisano " & integer'image(addr_int) & " lokacija u BRAM." severity note;

        load_done <= '1';
        wait until rising_edge(clk);

        report "------------------------------------------------------------" severity note;
        report "[RESET] Dizanje aresetn na 1, IP se pokrece (kroz AXI)." severity note;

        aresetn <= '1';
        wait until rising_edge(clk);
        wait for CLK_PERIOD * 2;

        report "------------------------------------------------------------" severity note;
        report "[AXI] Writing START register (offset 0x00): (" & integer'image(START_X) & "," & integer'image(START_Y) & ")" severity note;
        axi_write(0, to_integer(unsigned(START_COORD)));

        report "[AXI] Writing END register (offset 0x04): (" & integer'image(END_X) & "," & integer'image(END_Y) & ")" severity note;
        axi_write(4, to_integer(unsigned(END_COORD)));

        report "[AXI] Sending CONTROL pulse (offset 0x08)" severity note;
        report "------------------------------------------------------------" severity note;
        report "[RUN] Pathfinder running (via AXI). Waiting for irq_out..." severity note;
        report "------------------------------------------------------------" severity note;
        axi_write(8, 1);
        t_start := now;

        wait until irq_out = '1';
        t_end    := now;
        n_cycles := (t_end - t_start) / CLK_PERIOD;
        wait until rising_edge(clk);

        report "[RUN] irq_out detektovan. Algoritam zavrsen." severity note;

        report "------------------------------------------------------------" severity note;
        report "[PERF] Ukupan broj taktova (start -> irq): " & integer'image(n_cycles) severity note;
        report "[PERF] Ukupno vreme izvrsavanja: " & time'image(t_end - t_start) severity note;
        report "[PERF] Broj iteracija algoritma: " & integer'image(iter_count) severity note;
        if iter_count > 0 then
            report "[PERF] Taktova po iteraciji: " & integer'image(n_cycles / iter_count) severity note;
        end if;
        report "------------------------------------------------------------" severity note;

        file_open(open_ok, dump_file, BRAM_DUMP, write_mode);
        if open_ok /= open_ok then
            report "[DUMP] GRESKA: Nije moguce otvoriti dump fajl: " & BRAM_DUMP severity failure;
        end if;

        for i in 0 to TOTAL_DEPTH - 1 loop
            sub_addr := i mod BRAM_DEPTH;
            if i < BRAM_DEPTH then
                addra1 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                write(row, douta1);
            elsif i < 2 * BRAM_DEPTH then
                addra2 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                write(row, douta2);
            elsif i < 3 * BRAM_DEPTH then
                addra3 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                write(row, douta3);
            else
                addra4 <= std_logic_vector(to_unsigned(sub_addr, 12));
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                write(row, douta4);
            end if;
            writeline(dump_file, row);
        end loop;

        file_close(dump_file);
        report "[DUMP] Dump zavrsen (AXI verzija)." severity note;

        std.env.stop;
    end process;

end architecture sim;