library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_controller_width_adapter is
    port (
        -- Strana AXI BRAM Controller-a
        bram_addr_a   : in  std_logic_vector(15 downto 0);
        bram_wrdata_a : in  std_logic_vector(31 downto 0);
        bram_rddata_a : out std_logic_vector(31 downto 0);
        bram_en_a     : in  std_logic;
        bram_we_a     : in  std_logic_vector(3 downto 0);

        -- Strana bram_controller_router-a
        ctrl_en    : out std_logic;
        ctrl_we    : out std_logic;
        ctrl_addr  : out std_logic_vector(13 downto 0);
        ctrl_din   : out std_logic_vector(23 downto 0);
        ctrl_dout  : in  std_logic_vector(23 downto 0)
    );
end entity bram_controller_width_adapter;

architecture rtl of bram_controller_width_adapter is
begin

    ctrl_addr <= bram_addr_a(13 downto 0);
    ctrl_en <= bram_en_a;
    ctrl_we <= bram_we_a(0) or bram_we_a(1) or bram_we_a(2) or bram_we_a(3);
    ctrl_din <= bram_wrdata_a(23 downto 0);
    bram_rddata_a <= "00000000" & ctrl_dout;

end architecture rtl;