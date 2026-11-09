library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_bram_ctrl_width_adapter is
end entity tb_bram_ctrl_width_adapter;

architecture sim of tb_bram_ctrl_width_adapter is

    signal bram_addr_a   : std_logic_vector(15 downto 0) := (others => '0');
    signal bram_wrdata_a : std_logic_vector(31 downto 0) := (others => '0');
    signal bram_rddata_a : std_logic_vector(31 downto 0);
    signal bram_en_a     : std_logic := '0';
    signal bram_we_a     : std_logic_vector(3 downto 0) := (others => '0');

    signal ctrl_en    : std_logic;
    signal ctrl_we    : std_logic;
    signal ctrl_addr  : std_logic_vector(13 downto 0);
    signal ctrl_din   : std_logic_vector(23 downto 0);
    signal ctrl_dout  : std_logic_vector(23 downto 0) := (others => '0');

    signal any_error : boolean := false;

begin

    dut : entity work.bram_controller_width_adapter
        port map (
            bram_addr_a   => bram_addr_a,
            bram_wrdata_a => bram_wrdata_a,
            bram_rddata_a => bram_rddata_a,
            bram_en_a     => bram_en_a,
            bram_we_a     => bram_we_a,
            ctrl_en       => ctrl_en,
            ctrl_we       => ctrl_we,
            ctrl_addr     => ctrl_addr,
            ctrl_din      => ctrl_din,
            ctrl_dout     => ctrl_dout
        );

    main_proc : process
        variable errors : integer := 0;

        procedure check_std(actual, expected : std_logic; label_str : string) is
        begin
            if actual /= expected then
                report "[GRESKA] " & label_str & ": ocekivano='" & std_logic'image(expected) & "' dobijeno='" & std_logic'image(actual) & "'" severity error;
                errors := errors + 1;
            else
                report "[OK] " & label_str;
            end if;
        end procedure;

        procedure check_vec(actual, expected : std_logic_vector; label_str : string) is
        begin
            if actual /= expected then
                report "[GRESKA] " & label_str & ": ocekivano=" & integer'image(to_integer(unsigned(expected))) & " dobijeno=" & integer'image(to_integer(unsigned(actual))) severity error;
                errors := errors + 1;
            else
                report "[OK] " & label_str & " (vrednost=" & integer'image(to_integer(unsigned(actual))) & ")";
            end if;
        end procedure;

    begin

        bram_addr_a <= "11" & std_logic_vector(to_unsigned(1234, 14));
        wait for 1 ns;
        check_vec(ctrl_addr, std_logic_vector(to_unsigned(1234, 14)), "Test1: ctrl_addr odsecanje na 14 bita (gornja 2 bita ignorisu se)");

        bram_en_a <= '1';
        wait for 1 ns;
        check_std(ctrl_en, '1', "Test2a: ctrl_en='1' kad je bram_en_a='1'");

        bram_en_a <= '0';
        wait for 1 ns;
        check_std(ctrl_en, '0', "Test2b: ctrl_en='0' kad je bram_en_a='0'");

        bram_we_a <= "0000";
        wait for 1 ns;
        check_std(ctrl_we, '0', "Test3a: ctrl_we='0' kad je bram_we_a=0000");

        bram_we_a <= "0001";
        wait for 1 ns;
        check_std(ctrl_we, '1', "Test3b: ctrl_we='1' kad je bram_we_a=0001");

        bram_we_a <= "0010";
        wait for 1 ns;
        check_std(ctrl_we, '1', "Test3c: ctrl_we='1' kad je bram_we_a=0010");

        bram_we_a <= "0100";
        wait for 1 ns;
        check_std(ctrl_we, '1', "Test3d: ctrl_we='1' kad je bram_we_a=0100");

        bram_we_a <= "1000";
        wait for 1 ns;
        check_std(ctrl_we, '1', "Test3e: ctrl_we='1' kad je bram_we_a=1000");

        bram_we_a <= "1111";
        wait for 1 ns;
        check_std(ctrl_we, '1', "Test3f: ctrl_we='1' kad je bram_we_a=1111");

        bram_we_a <= "0000";
        wait for 1 ns;

        bram_wrdata_a <= x"FF" & x"ABCDEF";
        wait for 1 ns;
        check_vec(ctrl_din, x"ABCDEF", "Test4: ctrl_din odsecanje na 24 bita (gornjih 8 bita ignorisu se)");

        ctrl_dout <= x"123456";
        wait for 1 ns;
        check_vec(bram_rddata_a, x"00123456", "Test5: bram_rddata_a prosirenje sa nulama gore");

        report "=== Test zavrsen. Ukupno gresaka: " & integer'image(errors) & " ===";
        if errors = 0 then
            report "=== SVI TESTOVI PROSLI ===";
        else
            report "=== " & integer'image(errors) & " TEST(OVA) NIJE PROSLO ===" severity error;
        end if;

        wait;
    end process;

end architecture sim;