library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_controller_router is
    generic (
        ADDR_BITS  : integer := 14;
        SUB_BITS   : integer := 12;
        DATA_BITS  : integer := 24;
        BRAM_DEPTH : integer := 2500
    );
    port (
        -- Strana AXI BRAM Controller-a (BRAM_PORTA interfejs)
        ctrl_en    : in  std_logic;
        ctrl_we    : in  std_logic;
        ctrl_addr  : in  std_logic_vector(ADDR_BITS-1 downto 0);
        ctrl_din   : in  std_logic_vector(DATA_BITS-1 downto 0);
        ctrl_dout  : out std_logic_vector(DATA_BITS-1 downto 0);

        -- Strana fizickih BRAM banaka (Port A svake od 4 instance bram.vhd)
        phys1_en   : out std_logic;
        phys1_we   : out std_logic;
        phys1_addr : out std_logic_vector(SUB_BITS-1 downto 0);
        phys1_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        phys1_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        phys2_en   : out std_logic;
        phys2_we   : out std_logic;
        phys2_addr : out std_logic_vector(SUB_BITS-1 downto 0);
        phys2_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        phys2_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        phys3_en   : out std_logic;
        phys3_we   : out std_logic;
        phys3_addr : out std_logic_vector(SUB_BITS-1 downto 0);
        phys3_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        phys3_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

        phys4_en   : out std_logic;
        phys4_we   : out std_logic;
        phys4_addr : out std_logic_vector(SUB_BITS-1 downto 0);
        phys4_din  : out std_logic_vector(DATA_BITS-1 downto 0);
        phys4_dout : in  std_logic_vector(DATA_BITS-1 downto 0)
    );
end entity bram_controller_router;

architecture rtl of bram_controller_router is

    -- gornja 2 bita adrese biraju banku (00/01/10/11)
    signal bank_sel : std_logic_vector(1 downto 0);
    signal sub_addr : std_logic_vector(SUB_BITS-1 downto 0);

begin

    bank_sel <= ctrl_addr(ADDR_BITS-1 downto ADDR_BITS-2);
    sub_addr <= ctrl_addr(SUB_BITS-1 downto 0);

    -- U svakom trenutku tacno jedna banka ima en aktivan; ostale su '0'.
    process(ctrl_en, ctrl_we, sub_addr, ctrl_din, bank_sel)
    begin
        -- podrazumevano: sve banke neaktivne
        phys1_en <= '0'; phys1_we <= '0'; phys1_addr <= (others => '0'); phys1_din <= (others => '0');
        phys2_en <= '0'; phys2_we <= '0'; phys2_addr <= (others => '0'); phys2_din <= (others => '0');
        phys3_en <= '0'; phys3_we <= '0'; phys3_addr <= (others => '0'); phys3_din <= (others => '0');
        phys4_en <= '0'; phys4_we <= '0'; phys4_addr <= (others => '0'); phys4_din <= (others => '0');

        case bank_sel is
            when "00" =>
                phys1_en   <= ctrl_en;
                phys1_we   <= ctrl_we;
                phys1_addr <= sub_addr;
                phys1_din  <= ctrl_din;
            when "01" =>
                phys2_en   <= ctrl_en;
                phys2_we   <= ctrl_we;
                phys2_addr <= sub_addr;
                phys2_din  <= ctrl_din;
            when "10" =>
                phys3_en   <= ctrl_en;
                phys3_we   <= ctrl_we;
                phys3_addr <= sub_addr;
                phys3_din  <= ctrl_din;
            when others => -- "11"
                phys4_en   <= ctrl_en;
                phys4_we   <= ctrl_we;
                phys4_addr <= sub_addr;
                phys4_din  <= ctrl_din;
        end case;
    end process;

    process(bank_sel, phys1_dout, phys2_dout, phys3_dout, phys4_dout)
    begin
        case bank_sel is
            when "00"   => ctrl_dout <= phys1_dout;
            when "01"   => ctrl_dout <= phys2_dout;
            when "10"   => ctrl_dout <= phys3_dout;
            when others => ctrl_dout <= phys4_dout;
        end case;
    end process;

end architecture rtl;