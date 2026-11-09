library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pathfinder_axi is
	generic (
		GRID_SIZE : integer := 100;
		ADDR_BITS : integer := 14;
		DATA_BITS : integer := 24;
		
		C_S00_AXI_DATA_WIDTH : integer := 32;
		C_S00_AXI_ADDR_WIDTH : integer := 4
	);
	port (
		irq_out : out std_logic;

		-- BRAM interfejs (flat)
		bram_en    : out std_logic;
		bram_we    : out std_logic;
		bram_addr  : out std_logic_vector(ADDR_BITS-1 downto 0);
		bram_din   : out std_logic_vector(DATA_BITS-1 downto 0);
		bram_dout  : in  std_logic_vector(DATA_BITS-1 downto 0);

		-- BRAM interfejs (paralelni)
		bram_parallel : out std_logic;

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
		bram4_dout : in  std_logic_vector(DATA_BITS-1 downto 0);

		-- Portovi AXI Slave Bus interfejsa
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end pathfinder_axi;

architecture arch_imp of pathfinder_axi is

	component pathfinder_axi_slave_lite_v1_0_S00_AXI is
		generic (
            C_S_AXI_DATA_WIDTH : integer := 32;
            C_S_AXI_ADDR_WIDTH : integer := 4
		);
		port (
            S_AXI_ACLK      : in std_logic;
            S_AXI_ARESETN	: in std_logic;
            S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
            S_AXI_AWVALID	: in std_logic;
            S_AXI_AWREADY	: out std_logic;
            S_AXI_WDATA	    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_WSTRB	    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
            S_AXI_WVALID	: in std_logic;
            S_AXI_WREADY	: out std_logic;
            S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
            S_AXI_BVALID	: out std_logic;
            S_AXI_BREADY	: in std_logic;
            S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
            S_AXI_ARVALID	: in std_logic;
            S_AXI_ARREADY	: out std_logic;
            S_AXI_RDATA	    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
            S_AXI_RVALID	: out std_logic;
            S_AXI_RREADY	: in std_logic;
    
            cpu_we     : out std_logic;
            cpu_addr   : out std_logic_vector(1 downto 0);
            cpu_wdata  : out std_logic_vector(13 downto 0);
            done_flag  : in  std_logic
		);
	end component pathfinder_axi_slave_lite_v1_0_S00_AXI;

	component pathfinder_ip is
		generic (
			GRID_SIZE : integer := 100;
			ADDR_BITS : integer := 14;
			DATA_BITS : integer := 24
		);
		port (
			clk        : in  std_logic;
			rst        : in  std_logic;

			cpu_we     : in  std_logic;
			cpu_addr   : in  std_logic_vector(1 downto 0);
			cpu_wdata  : in  std_logic_vector(ADDR_BITS-1 downto 0);

			bram_en    : out std_logic;
			bram_we    : out std_logic;
			bram_addr  : out std_logic_vector(ADDR_BITS-1 downto 0);
			bram_din   : out std_logic_vector(DATA_BITS-1 downto 0);
			bram_dout  : in  std_logic_vector(DATA_BITS-1 downto 0);

			irq        : out std_logic;

			bram_parallel : out std_logic;

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
	end component pathfinder_ip;

	-- interni signali
	signal core_cpu_we    : std_logic;
	signal core_cpu_addr  : std_logic_vector(1 downto 0);
	signal core_cpu_wdata : std_logic_vector(13 downto 0);
	signal core_irq       : std_logic;
	signal core_rst       : std_logic;

begin

pathfinder_axi_slave_lite_v1_0_S00_AXI_inst : pathfinder_axi_slave_lite_v1_0_S00_AXI
	generic map (
		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
	)
	port map (
		S_AXI_ACLK	    => s00_axi_aclk,
		S_AXI_ARESETN	=> s00_axi_aresetn,
		S_AXI_AWADDR	=> s00_axi_awaddr,
		S_AXI_AWPROT	=> s00_axi_awprot,
		S_AXI_AWVALID	=> s00_axi_awvalid,
		S_AXI_AWREADY	=> s00_axi_awready,
		S_AXI_WDATA	    => s00_axi_wdata,
		S_AXI_WSTRB	    => s00_axi_wstrb,
		S_AXI_WVALID	=> s00_axi_wvalid,
		S_AXI_WREADY	=> s00_axi_wready,
		S_AXI_BRESP	    => s00_axi_bresp,
		S_AXI_BVALID	=> s00_axi_bvalid,
		S_AXI_BREADY	=> s00_axi_bready,
		S_AXI_ARADDR	=> s00_axi_araddr,
		S_AXI_ARPROT	=> s00_axi_arprot,
		S_AXI_ARVALID	=> s00_axi_arvalid,
		S_AXI_ARREADY	=> s00_axi_arready,
		S_AXI_RDATA	    => s00_axi_rdata,
		S_AXI_RRESP	    => s00_axi_rresp,
		S_AXI_RVALID	=> s00_axi_rvalid,
		S_AXI_RREADY	=> s00_axi_rready,

		cpu_we     => core_cpu_we,
		cpu_addr   => core_cpu_addr,
		cpu_wdata  => core_cpu_wdata,
		done_flag  => core_irq
	);

	core_rst <= s00_axi_aresetn;

	pathfinder_ip_inst : pathfinder_ip
		generic map (
			GRID_SIZE => GRID_SIZE,
			ADDR_BITS => ADDR_BITS,
			DATA_BITS => DATA_BITS
		)
		port map (
			clk        => s00_axi_aclk,
			rst        => core_rst,

			cpu_we     => core_cpu_we,
			cpu_addr   => core_cpu_addr,
			cpu_wdata  => core_cpu_wdata,

			bram_en    => bram_en,
			bram_we    => bram_we,
			bram_addr  => bram_addr,
			bram_din   => bram_din,
			bram_dout  => bram_dout,

			irq        => core_irq,

			bram_parallel => bram_parallel,

			bram1_en   => bram1_en,
			bram1_we   => bram1_we,
			bram1_addr => bram1_addr,
			bram1_din  => bram1_din,
			bram1_dout => bram1_dout,

			bram2_en   => bram2_en,
			bram2_we   => bram2_we,
			bram2_addr => bram2_addr,
			bram2_din  => bram2_din,
			bram2_dout => bram2_dout,

			bram3_en   => bram3_en,
			bram3_we   => bram3_we,
			bram3_addr => bram3_addr,
			bram3_din  => bram3_din,
			bram3_dout => bram3_dout,

			bram4_en   => bram4_en,
			bram4_we   => bram4_we,
			bram4_addr => bram4_addr,
			bram4_din  => bram4_din,
			bram4_dout => bram4_dout
		);

	irq_out <= core_irq;

end arch_imp;