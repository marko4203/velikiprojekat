library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram is
    port (
        -- Port A (CPU)
        clka  : in  std_logic;
        ena   : in  std_logic;
        wea   : in  std_logic;
        addra : in  std_logic_vector(13 downto 0);
        dina  : in  std_logic_vector(23 downto 0);
        douta : out std_logic_vector(23 downto 0);

        -- Port B (IP)
        enb   : in  std_logic;
        web   : in  std_logic;
        addrb : in  std_logic_vector(13 downto 0);
        dinb  : in  std_logic_vector(23 downto 0);
        doutb : out std_logic_vector(23 downto 0)
    );
end bram;

architecture Behavioral of bram is

    function clogb2(depth : natural) return integer is
        variable temp    : integer := depth;
        variable ret_val : integer := 0;
    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;
        return ret_val;
    end function;

    constant C_RAM_WIDTH       : integer := 24;       
    constant C_RAM_DEPTH       : integer := 10000;    
    constant C_RAM_PERFORMANCE : string  := "LOW_LATENCY";

    type ram_type is array (C_RAM_DEPTH-1 downto 0) of std_logic_vector(C_RAM_WIDTH-1 downto 0);

    signal ram_data_a : std_logic_vector(C_RAM_WIDTH-1 downto 0);
    signal ram_data_b : std_logic_vector(C_RAM_WIDTH-1 downto 0);

    shared variable ram_name : ram_type := (others => (others => '0'));

begin

    -- Port A (CPU)
    process(clka)
    begin
        if rising_edge(clka) then
            if ena = '1' then
                ram_data_a <= ram_name(to_integer(unsigned(addra)));
                if wea = '1' then
                    ram_name(to_integer(unsigned(addra))) := dina;
                end if;
            end if;
        end if;
    end process;

    -- Port B (IP)
    process(clka)
    begin
        if rising_edge(clka) then
            if enb = '1' then
                ram_data_b <= ram_name(to_integer(unsigned(addrb)));
                if web = '1' then
                    ram_name(to_integer(unsigned(addrb))) := dinb;
                end if;
            end if;
        end if;
    end process;

    douta <= ram_data_a;
    doutb <= ram_data_b;
end Behavioral;
