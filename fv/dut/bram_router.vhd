library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_router is
    generic (
        ADDR_BITS  : integer := 14;
        SUB_BITS   : integer := 12;
        DATA_BITS  : integer := 24;
        BRAM_DEPTH : integer := 2500
    );
    port (
        clk : in std_logic;

        bram_parallel : in std_logic;

        -- flat interfejs
        bram_en    : in  std_logic;
        bram_we    : in  std_logic;
        bram_addr  : in  std_logic_vector(ADDR_BITS - 1 downto 0);
        bram_din   : in  std_logic_vector(DATA_BITS - 1 downto 0);
        bram_dout  : out std_logic_vector(DATA_BITS - 1 downto 0);

        -- paralelni interfejs
        bram1_en   : in  std_logic;
        bram1_we   : in  std_logic;
        bram1_addr : in  std_logic_vector(SUB_BITS - 1 downto 0);
        bram1_din  : in  std_logic_vector(DATA_BITS - 1 downto 0);
        bram1_dout : out std_logic_vector(DATA_BITS - 1 downto 0);

        bram2_en   : in  std_logic;
        bram2_we   : in  std_logic;
        bram2_addr : in  std_logic_vector(SUB_BITS - 1 downto 0);
        bram2_din  : in  std_logic_vector(DATA_BITS - 1 downto 0);
        bram2_dout : out std_logic_vector(DATA_BITS - 1 downto 0);

        bram3_en   : in  std_logic;
        bram3_we   : in  std_logic;
        bram3_addr : in  std_logic_vector(SUB_BITS - 1 downto 0);
        bram3_din  : in  std_logic_vector(DATA_BITS - 1 downto 0);
        bram3_dout : out std_logic_vector(DATA_BITS - 1 downto 0);

        bram4_en   : in  std_logic;
        bram4_we   : in  std_logic;
        bram4_addr : in  std_logic_vector(SUB_BITS - 1 downto 0);
        bram4_din  : in  std_logic_vector(DATA_BITS - 1 downto 0);
        bram4_dout : out std_logic_vector(DATA_BITS - 1 downto 0);

        phys1_en   : out std_logic;
        phys1_we   : out std_logic;
        phys1_addr : out std_logic_vector(SUB_BITS - 1 downto 0);
        phys1_din  : out std_logic_vector(DATA_BITS - 1 downto 0);
        phys1_dout : in  std_logic_vector(DATA_BITS - 1 downto 0);

        phys2_en   : out std_logic;
        phys2_we   : out std_logic;
        phys2_addr : out std_logic_vector(SUB_BITS - 1 downto 0);
        phys2_din  : out std_logic_vector(DATA_BITS - 1 downto 0);
        phys2_dout : in  std_logic_vector(DATA_BITS - 1 downto 0);

        phys3_en   : out std_logic;
        phys3_we   : out std_logic;
        phys3_addr : out std_logic_vector(SUB_BITS - 1 downto 0);
        phys3_din  : out std_logic_vector(DATA_BITS - 1 downto 0);
        phys3_dout : in  std_logic_vector(DATA_BITS - 1 downto 0);

        phys4_en   : out std_logic;
        phys4_we   : out std_logic;
        phys4_addr : out std_logic_vector(SUB_BITS - 1 downto 0);
        phys4_din  : out std_logic_vector(DATA_BITS - 1 downto 0);
        phys4_dout : in  std_logic_vector(DATA_BITS - 1 downto 0)
    );
end entity bram_router;

architecture rtl of bram_router is

    signal global_sel     : integer range 1 to 4;
    signal global_subaddr : std_logic_vector(SUB_BITS - 1 downto 0);
    signal global_sel_reg : integer range 1 to 4;

begin

    process (bram_addr)
        variable full : unsigned(ADDR_BITS - 1 downto 0);
        variable sub  : unsigned(SUB_BITS - 1 downto 0);
        variable sel  : integer range 1 to 4;
    begin
        full := unsigned(bram_addr);
        if full < BRAM_DEPTH then
            sel := 1; sub := resize(full, SUB_BITS);
        elsif full < 2 * BRAM_DEPTH then
            sel := 2; sub := resize(full - BRAM_DEPTH, SUB_BITS);
        elsif full < 3 * BRAM_DEPTH then
            sel := 3; sub := resize(full - 2 * BRAM_DEPTH, SUB_BITS);
        else
            sel := 4; sub := resize(full - 3 * BRAM_DEPTH, SUB_BITS);
        end if;
        global_sel     <= sel;
        global_subaddr <= std_logic_vector(sub);
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            global_sel_reg <= global_sel;
        end if;
    end process;

    process (bram_parallel,
             bram_en, bram_we, global_subaddr, bram_din, global_sel,
             bram1_en, bram1_we, bram1_addr, bram1_din,
             bram2_en, bram2_we, bram2_addr, bram2_din,
             bram3_en, bram3_we, bram3_addr, bram3_din,
             bram4_en, bram4_we, bram4_addr, bram4_din)
    begin
        if bram_parallel = '0' then
            phys1_addr <= global_subaddr; phys1_din <= bram_din;
            phys2_addr <= global_subaddr; phys2_din <= bram_din;
            phys3_addr <= global_subaddr; phys3_din <= bram_din;
            phys4_addr <= global_subaddr; phys4_din <= bram_din;

            if global_sel = 1 then
                phys1_en <= bram_en; phys2_en <= '0'; phys3_en <= '0'; phys4_en <= '0';
                phys1_we <= bram_we; phys2_we <= '0'; phys3_we <= '0'; phys4_we <= '0';
            elsif global_sel = 2 then
                phys1_en <= '0'; phys2_en <= bram_en; phys3_en <= '0'; phys4_en <= '0';
                phys1_we <= '0'; phys2_we <= bram_we; phys3_we <= '0'; phys4_we <= '0';
            elsif global_sel = 3 then
                phys1_en <= '0'; phys2_en <= '0'; phys3_en <= bram_en; phys4_en <= '0';
                phys1_we <= '0'; phys2_we <= '0'; phys3_we <= bram_we; phys4_we <= '0';
            else
                phys1_en <= '0'; phys2_en <= '0'; phys3_en <= '0'; phys4_en <= bram_en;
                phys1_we <= '0'; phys2_we <= '0'; phys3_we <= '0'; phys4_we <= bram_we;
            end if;
        else
            phys1_en <= bram1_en; phys1_we <= bram1_we; phys1_addr <= bram1_addr; phys1_din <= bram1_din;
            phys2_en <= bram2_en; phys2_we <= bram2_we; phys2_addr <= bram2_addr; phys2_din <= bram2_din;
            phys3_en <= bram3_en; phys3_we <= bram3_we; phys3_addr <= bram3_addr; phys3_din <= bram3_din;
            phys4_en <= bram4_en; phys4_we <= bram4_we; phys4_addr <= bram4_addr; phys4_din <= bram4_din;
        end if;
    end process;

    bram1_dout <= phys1_dout;
    bram2_dout <= phys2_dout;
    bram3_dout <= phys3_dout;
    bram4_dout <= phys4_dout;

    process (global_sel_reg, phys1_dout, phys2_dout, phys3_dout, phys4_dout)
    begin
        case global_sel_reg is
            when 1      => bram_dout <= phys1_dout;
            when 2      => bram_dout <= phys2_dout;
            when 3      => bram_dout <= phys3_dout;
            when others => bram_dout <= phys4_dout;
        end case;
    end process;

end architecture rtl;