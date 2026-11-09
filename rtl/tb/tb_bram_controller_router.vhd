library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_bram_controller_router is
end entity tb_bram_controller_router;

architecture sim of tb_bram_controller_router is

    constant CLK_PERIOD : time := 10 ns;

    signal clk       : std_logic := '0';
    signal ctrl_en   : std_logic := '0';
    signal ctrl_we   : std_logic := '0';
    signal ctrl_addr : std_logic_vector(13 downto 0) := (others => '0');
    signal ctrl_din  : std_logic_vector(23 downto 0) := (others => '0');
    signal ctrl_dout : std_logic_vector(23 downto 0);

    signal phys1_en, phys2_en, phys3_en, phys4_en : std_logic;
    signal phys1_we, phys2_we, phys3_we, phys4_we : std_logic;
    signal phys1_addr, phys2_addr, phys3_addr, phys4_addr : std_logic_vector(11 downto 0);
    signal phys1_din,  phys2_din,  phys3_din,  phys4_din  : std_logic_vector(23 downto 0);
    signal phys1_dout, phys2_dout, phys3_dout, phys4_dout : std_logic_vector(23 downto 0);

    signal b1_en, b2_en, b3_en, b4_en : std_logic := '0';
    signal b1_we, b2_we, b3_we, b4_we : std_logic := '0';
    signal b1_addr, b2_addr, b3_addr, b4_addr : std_logic_vector(11 downto 0) := (others => '0');
    signal b1_din,  b2_din,  b3_din,  b4_din  : std_logic_vector(23 downto 0) := (others => '0');
    signal b1_dout, b2_dout, b3_dout, b4_dout : std_logic_vector(23 downto 0);

    signal sim_done : boolean := false;

begin

    clk <= not clk after CLK_PERIOD/2 when not sim_done else clk;

    dut : entity work.bram_controller_router
        generic map (
            ADDR_BITS  => 14,
            SUB_BITS   => 12,
            DATA_BITS  => 24,
            BRAM_DEPTH => 2500
        )
        port map (
            ctrl_en    => ctrl_en,
            ctrl_we    => ctrl_we,
            ctrl_addr  => ctrl_addr,
            ctrl_din   => ctrl_din,
            ctrl_dout  => ctrl_dout,

            phys1_en   => phys1_en,   phys1_we   => phys1_we,
            phys1_addr => phys1_addr, phys1_din  => phys1_din,  phys1_dout => phys1_dout,

            phys2_en   => phys2_en,   phys2_we   => phys2_we,
            phys2_addr => phys2_addr, phys2_din  => phys2_din,  phys2_dout => phys2_dout,

            phys3_en   => phys3_en,   phys3_we   => phys3_we,
            phys3_addr => phys3_addr, phys3_din  => phys3_din,  phys3_dout => phys3_dout,

            phys4_en   => phys4_en,   phys4_we   => phys4_we,
            phys4_addr => phys4_addr, phys4_din  => phys4_din,  phys4_dout => phys4_dout
        );

    bank1 : entity work.bram
        port map (
            clka => clk, ena => phys1_en, wea => phys1_we, addra => phys1_addr, dina => phys1_din, douta => phys1_dout,
            enb  => b1_en, web => b1_we, addrb => b1_addr, dinb => b1_din, doutb => b1_dout
        );

    bank2 : entity work.bram
        port map (
            clka => clk, ena => phys2_en, wea => phys2_we, addra => phys2_addr, dina => phys2_din, douta => phys2_dout,
            enb  => b2_en, web => b2_we, addrb => b2_addr, dinb => b2_din, doutb => b2_dout
        );

    bank3 : entity work.bram
        port map (
            clka => clk, ena => phys3_en, wea => phys3_we, addra => phys3_addr, dina => phys3_din, douta => phys3_dout,
            enb  => b3_en, web => b3_we, addrb => b3_addr, dinb => b3_din, doutb => b3_dout
        );

    bank4 : entity work.bram
        port map (
            clka => clk, ena => phys4_en, wea => phys4_we, addra => phys4_addr, dina => phys4_din, douta => phys4_dout,
            enb  => b4_en, web => b4_we, addrb => b4_addr, dinb => b4_din, doutb => b4_dout
        );

    main_proc : process
        variable read_result : std_logic_vector(23 downto 0);

        procedure measure_latency(
            addr           : in  std_logic_vector(13 downto 0);
            expected       : in  std_logic_vector(23 downto 0);
            label_str      : in  string
        ) is
            variable cycles : integer := 0;
            variable found  : boolean := false;
        begin
            wait until rising_edge(clk);
            ctrl_addr <= addr;
            ctrl_en   <= '1';
            ctrl_we   <= '0';

            -- proveravamo do 5 taktova unapred, a ocekujemo tacno 1
            for i in 0 to 4 loop
                wait until rising_edge(clk);
                wait for 1 ps;
                cycles := i + 1;
                if ctrl_dout = expected then
                    found := true;
                    report "[" & label_str & "] ctrl_dout je postao ispravan posle " & integer'image(cycles) & " takta.";
                    if cycles = 1 then
                        report "[" & label_str & "] REZULTAT: OK -- latencija je tacno 1 takt, kao direktan pristup bram.vhd.";
                    else
                        report "[" & label_str & "] REZULTAT: UPOZORENJE -- latencija NIJE 1 takt (izmereno: " & integer'image(cycles) & "). Ovo bi moglo pokvariti AXI read handshake sa kontrolerom." severity warning;
                    end if;
                    exit;
                end if;
            end loop;

            if not found then
                report "[" & label_str & "] REZULTAT: GRESKA -- ctrl_dout nije postao ocekivana vrednost ni posle 5 taktova. " & "Ocekivano:" & integer'image(to_integer(unsigned(expected))) & " Dobijeno:" & integer'image(to_integer(unsigned(ctrl_dout))) severity error;
            end if;

            ctrl_en <= '0';
            wait until rising_edge(clk);
        end procedure;

    begin

        wait until rising_edge(clk);
        b1_en <= '1'; b1_we <= '1'; b1_addr <= std_logic_vector(to_unsigned(10, 12));  b1_din <= x"AAAAAA";
        b4_en <= '1'; b4_we <= '1'; b4_addr <= std_logic_vector(to_unsigned(200, 12)); b4_din <= x"123456";
        wait until rising_edge(clk);
        b1_en <= '0'; b1_we <= '0';
        b4_en <= '0'; b4_we <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        report "Test 1: Banka 1";
        measure_latency(
            addr     => "00" & std_logic_vector(to_unsigned(10, 12)),
            expected => x"AAAAAA",
            label_str => "BANKA1"
        );

        report "Test 2: Banka 4";
        measure_latency(
            addr     => "11" & std_logic_vector(to_unsigned(200, 12)),
            expected => x"123456",
            label_str => "BANKA4"
        );

        report "--- Test zavrsen. ---";
        sim_done <= true;
        wait;
    end process;

end architecture sim;