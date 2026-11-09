library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pathfinder_axi_slave_lite_v1_0_S00_AXI is
	generic (
		C_S_AXI_DATA_WIDTH : integer := 32;
		C_S_AXI_ADDR_WIDTH : integer := 4
	);
	port (
		cpu_we        : out std_logic;
		cpu_addr      : out std_logic_vector(1 downto 0);
		cpu_wdata     : out std_logic_vector(13 downto 0);
		done_flag     : in  std_logic;

		S_AXI_ACLK    : in std_logic;
		S_AXI_ARESETN : in std_logic;
		S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
		S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
		S_AXI_AWVALID : in std_logic;
		S_AXI_AWREADY : out std_logic;
		S_AXI_WDATA	  : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		S_AXI_WSTRB	  : in std_logic_vector((C_S_AXI_DATA_WIDTH / 8) - 1 downto 0);
		S_AXI_WVALID  : in std_logic;
		S_AXI_WREADY  : out std_logic;
		S_AXI_BRESP	  : out std_logic_vector(1 downto 0);
		S_AXI_BVALID  : out std_logic;
		S_AXI_BREADY  : in std_logic;
		S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
		S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
		S_AXI_ARVALID : in std_logic;
		S_AXI_ARREADY : out std_logic;
		S_AXI_RDATA	  : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		S_AXI_RRESP	  : out std_logic_vector(1 downto 0);
		S_AXI_RVALID  : out std_logic;
		S_AXI_RREADY  : in std_logic
	);
end pathfinder_axi_slave_lite_v1_0_S00_AXI;

architecture arch_imp of pathfinder_axi_slave_lite_v1_0_S00_AXI is

	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	constant ADDR_LSB : integer := (C_S_AXI_DATA_WIDTH / 32) + 1;
	constant OPT_MEM_ADDR_BITS : integer := 1;

	signal reg_start	: std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
	signal reg_end	    : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
	signal reg_control	: std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
	signal byte_index	: integer;

	signal mem_logic : std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

	constant Idle  : std_logic_vector(1 downto 0) := "00";
	constant Raddr : std_logic_vector(1 downto 0) := "10";
	constant Rdata : std_logic_vector(1 downto 0) := "11";
	constant Waddr : std_logic_vector(1 downto 0) := "10";
	constant Wdata : std_logic_vector(1 downto 0) := "11";
	
	signal state_read  : std_logic_vector(1 downto 0);
	signal state_write : std_logic_vector(1 downto 0); 
begin

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	    <= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RRESP	    <= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;
	
	mem_logic <= S_AXI_AWADDR(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) when (S_AXI_AWVALID = '1') else axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

	 process (S_AXI_ACLK)                                       
	   begin                                       
	     if rising_edge(S_AXI_ACLK) then                                       
	        if S_AXI_ARESETN = '0' then                                                                             
	          axi_awready <= '0';                                       
	          axi_wready  <= '0';                                       
	          axi_bvalid  <= '0';                                       
	          axi_bresp   <= (others => '0');                                       
	          state_write <= Idle;                                       
	        else                                       
	          case (state_write) is                                       
	             when Idle =>
	               if (S_AXI_ARESETN = '1') then                                       
	                 axi_awready <= '1';                                       
	                 axi_wready  <= '1';                                       
	                 state_write <= Waddr;                                       
	               else state_write <= state_write;                                       
	               end if;                                       
	             when Waddr =>
	               if (S_AXI_AWVALID = '1' and axi_awready = '1') then                                       
	                 axi_awaddr <= S_AXI_AWADDR;                                       
	                 if (S_AXI_WVALID = '1') then                                       
	                   axi_awready <= '1';                                       
	                   state_write <= Waddr;                                       
	                   axi_bvalid  <= '1';                                       
	                 else                                       
	                   axi_awready <= '0';                                       
	                   state_write <= Wdata;                                       
	                   if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                       
	                     axi_bvalid <= '0';                                       
	                   end if;                                       
	                 end if;                                       
	               else                                        
	                 state_write <= state_write;                                       
	                 if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                       
	                   axi_bvalid <= '0';                                       
	                 end if;                                       
	               end if;                                       
	             when Wdata =>
	               if (S_AXI_WVALID = '1') then                                       
	                 state_write <= Waddr;                                       
	                 axi_bvalid  <= '1';                                       
	                 axi_awready <= '1';                                       
	               else                                       
	                 state_write <= state_write;                                       
	                 if (S_AXI_BREADY ='1' and axi_bvalid = '1') then                                       
	                   axi_bvalid <= '0';                                       
	                 end if;                                       
	               end if;                                       
	             when others =>
	               axi_awready <= '0';                                       
	               axi_wready  <= '0';                                       
	               axi_bvalid  <= '0';                                       
	           end case;                                       
	        end if;                                       
	      end if;                                                
	 end process;                                       

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      reg_start   <= (others => '0');
	      reg_end     <= (others => '0');
	      reg_control <= (others => '0');
	    else
	      reg_control <= (others => '0');

	      if (S_AXI_WVALID = '1') then
	          case (mem_logic) is
	          when b"00" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH / 8 - 1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                reg_start(byte_index * 8 + 7 downto byte_index * 8) <= S_AXI_WDATA(byte_index * 8 + 7 downto byte_index * 8);
	              end if;
	            end loop;
	          when b"01" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                reg_end(byte_index * 8 + 7 downto byte_index * 8) <= S_AXI_WDATA(byte_index * 8 + 7 downto byte_index * 8);
	              end if;
	            end loop;
	          when b"10" =>
	            reg_control(0) <= '1';
	          when b"11" =>
	            null;
	          when others =>
	            reg_start <= reg_start;
	            reg_end   <= reg_end;
	        end case;
	      end if;
	    end if;
	  end if;                   
	end process; 

	 process (S_AXI_ACLK)                                          
	   begin                                          
	     if rising_edge(S_AXI_ACLK) then                                           
	        if S_AXI_ARESETN = '0' then                                                                                  
	          axi_arready <= '0';                                          
	          axi_rvalid  <= '0';                                          
	          axi_rresp   <= (others => '0');                                          
	          state_read  <= Idle;                                          
	        else                                          
	          case (state_read) is                                          
	            when Idle =>
	                if (S_AXI_ARESETN = '1') then                                          
	                  axi_arready <= '1';                                          
	                  state_read  <= Raddr;                                          
	                else state_read <= state_read;                                          
	                end if;                                          
	            when Raddr =>
	                if (S_AXI_ARVALID = '1' and axi_arready = '1') then                                          
	                  state_read  <= Rdata;                                          
	                  axi_rvalid  <= '1';                                          
	                  axi_arready <= '0';                                          
	                  axi_araddr  <= S_AXI_ARADDR;                                          
	                else                                          
	                  state_read  <= state_read;                                          
	                end if;                                          
	            when Rdata =>
	                if (axi_rvalid = '1' and S_AXI_RREADY = '1') then                                          
	                  axi_rvalid  <= '0';                                          
	                  axi_arready <= '1';                                          
	                  state_read  <= Raddr;                                          
	                else                                          
	                  state_read  <= state_read;                                          
	                end if;                                          
	            when others =>
	                axi_arready <= '0';                                          
	                axi_rvalid  <= '0';                                          
	           end case;                                          
	         end if;                                          
	       end if;                                                   
	  end process;                                          

	 S_AXI_RDATA <= reg_start when (axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) = "00") else 
	                reg_end when (axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) = "01") else 
	                reg_control when (axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) = "10") else
	                (0 => done_flag, others => '0') when (axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) = "11") else
	                (others => '0');

	process (S_AXI_ACLK)
	begin
		if rising_edge(S_AXI_ACLK) then
			if S_AXI_ARESETN = '0' then
				cpu_we    <= '0';
				cpu_addr  <= "00";
				cpu_wdata <= (others => '0');
			else
				cpu_we <= '0';

				if (S_AXI_WVALID = '1' and axi_wready = '1') then
					case (mem_logic) is
						when b"00" =>
							cpu_we    <= '1';
							cpu_addr  <= "00";
							cpu_wdata <= S_AXI_WDATA(13 downto 0);
						when b"01" =>
							cpu_we    <= '1';
							cpu_addr  <= "01";
							cpu_wdata <= S_AXI_WDATA(13 downto 0);
						when b"10" =>
							cpu_we    <= '1';
							cpu_addr  <= "10";
							cpu_wdata <= (others => '0');
						when others =>
							null;
					end case;
				end if;
			end if;
		end if;
	end process;

end arch_imp;