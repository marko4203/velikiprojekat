set SCRIPT_DIR [file dirname [file normalize [info script]]]
set PROJ_ROOT  [file dirname $SCRIPT_DIR]

set SRC_DIR      "$PROJ_ROOT/hdl"
set IP_REPO_DIR  "$PROJ_ROOT/build/ip_repo"
set PKG_WORK_DIR "$PROJ_ROOT/build/_pkg_tmp"
set BD_PROJ_NAME "system_block_design"
set BD_PROJ_DIR  "$PROJ_ROOT/build/$BD_PROJ_NAME"
set BD_NAME      "sysbd"
set FPGA_PART    "xc7z010clg400-1"
# *** IZMENA *** obicni Zybo (ne Z7). Isti cip, drugaciji PS preset: 50 MHz kristal, 512 MB DDR.
# BOARD_PART se odredjuje automatski pri kreiranju projekta (najnovija instalirana
# verzija digilentinc.com:zybo:part0:*).
set XSA_OUTPUT   "$PROJ_ROOT/build/block_design_wrapper.xsa"

file mkdir $PKG_WORK_DIR
file mkdir $IP_REPO_DIR

# ============================================================================
# DEO 1: PAKOVANJE IP-ova
# ============================================================================

proc package_single_ip {top_entity src_files display_name work_dir repo_dir} {
    set proj_name "pkg_${top_entity}"
    set proj_dir  "$work_dir/$proj_name"

    puts "Pakujem $display_name..."

    create_project $proj_name $proj_dir -part $::FPGA_PART -force

    foreach f $src_files {
        if {![file exists $f]} {
            error "nedostaje izvorni fajl: $f"
        }
        add_files -norecurse $f
    }

    update_compile_order -fileset sources_1
    set_property top $top_entity [current_fileset]
    update_compile_order -fileset sources_1

    ipx::package_project -root_dir "$repo_dir/$display_name" \
        -vendor xilinx.com -library user -taxonomy /UserIP \
        -import_files -force

    set core [ipx::current_core]
    set_property NAME $display_name $core
    set_property DISPLAY_NAME $display_name $core

    if {$top_entity eq "pathfinder_axi"} {
        ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s00_axi_aclk -of_objects $core] -quiet
        if {[llength [ipx::get_ports irq_out -of_objects $core -quiet]] > 0} {
            ipx::infer_bus_interface irq_out xilinx.com:signal:interrupt_rtl:1.0 $core
        }
    }

    ipx::update_checksums $core
    ipx::save_core $core
    close_project

    puts "$display_name upakovan."
}

package_single_ip "bram_router" \
    [list "$SRC_DIR/bram_router.vhd"] \
    "bram_router" $PKG_WORK_DIR $IP_REPO_DIR

package_single_ip "bram_controller_router" \
    [list "$SRC_DIR/bram_controller_router.vhd"] \
    "bram_controller_router" $PKG_WORK_DIR $IP_REPO_DIR

package_single_ip "bram_controller_width_adapter" \
    [list "$SRC_DIR/bram_controller_width_adapter.vhd"] \
    "bram_controller_width_adapter" $PKG_WORK_DIR $IP_REPO_DIR

package_single_ip "pathfinder_axi" \
    [list "$SRC_DIR/pathfinder_axi.vhd" \
          "$SRC_DIR/pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd" \
          "$SRC_DIR/pathfinder_ip.vhd"] \
    "gbfs_hardware_accelerator" $PKG_WORK_DIR $IP_REPO_DIR

puts "Pakovanje IP-ova zavrseno."

# ============================================================================
# DEO 2: KREIRANJE PROJEKTA I BLOCK DESIGN-a
# ============================================================================

create_project $BD_PROJ_NAME $BD_PROJ_DIR -part $FPGA_PART -force

# *** IZMENA *** izbor ploce - mora PRE kreiranja PS7 bloka da bi preset bio dostupan.
# Uzima se najnovija instalirana verzija Digilent board fajla za obicni Zybo.
set zybo_parts [get_board_parts -quiet digilentinc.com:zybo:part0:*]
if {[llength $zybo_parts] == 0} {
    error "Board fajl za obicni Zybo (digilentinc.com:zybo:part0:*) nije instaliran u Vivadu. Instalirajte Digilent board files (Tools > Settings > Boards, ili XilinxBoardStore) pa ponovite."
}
set BOARD_PART [lindex $zybo_parts end]
set_property board_part $BOARD_PART [current_project]
puts "Board part: [get_property board_part [current_project]]"

set_property ip_repo_paths $IP_REPO_DIR [current_project]
update_ip_catalog

create_bd_design $BD_NAME
current_bd_design [get_bd_designs $BD_NAME]

puts "Projekat i block design kreirani."

# ============================================================================
# DEO 3: DODAVANJE I KONFIGURISANJE SVIH BLOKOVA
# ============================================================================

# --- Zynq7 Processing System ---
# *** IZMENA *** Umesto ~300 eksplicitnih PCW_* vrednosti (koje su bile preset za Zybo Z7:
# 33.333 MHz, MT41K256M16 1 GB, CD na MIO 47) PS7 dobija konfiguraciju iz preseta ploce.
# Block automation uz "apply_board_preset" ujedno kreira i povezuje DDR i FIXED_IO portove.
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]

  apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
      -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
      $processing_system7_0

  # Samo ono sto je specificno za nas dizajn, primenjeno POSLE preseta:
  set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_IRQ_F2P_MODE {DIRECT} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
  ] $processing_system7_0

  # Provera da je preset zaista za obicni Zybo (50 MHz kristal, 512 MB DDR). Ako nije - stani odmah.
  set ps_clk  [get_property CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ $processing_system7_0]
  set ddr_pn  [get_property CONFIG.PCW_UIPARAM_DDR_PARTNO         $processing_system7_0]
  set ddr_hi  [get_property CONFIG.PCW_DDR_RAM_HIGHADDR            $processing_system7_0]
  set uart_io [get_property CONFIG.PCW_UART1_UART1_IO              $processing_system7_0]
  set sd_cd   [get_property CONFIG.PCW_SD0_GRP_CD_IO               $processing_system7_0]
  puts "PS7 preset: PS_CLK=$ps_clk MHz, DDR=$ddr_pn, DDR_HIGHADDR=$ddr_hi, UART1=$uart_io, SD0_CD=$sd_cd"
  if {abs($ps_clk - 50.0) > 0.01} {
      error "PS_CLK je $ps_clk MHz, ocekivano 50 MHz za obicni Zybo - preset ploce nije primenjen."
  }

# --- Ostali IP blokovi ---
  set hardware_accelerator_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:gbfs_hardware_accelerator:1.0 hardware_accelerator_0 ]

  # Create instance: axi_bram_controller_0, and set properties
  set axi_bram_controller_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_controller_0 ]
  set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] $axi_bram_controller_0

  # Create instance: bram_controller_router_0, and set properties
  set bram_controller_router_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:bram_controller_router:1.0 bram_controller_router_0 ]

  # Create instance: bram_router_0, and set properties
  set bram_router_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:bram_router:1.0 bram_router_0 ]

  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {2500} \
    CONFIG.Write_Width_A {24} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_0

  # Create instance: blk_mem_gen_1, and set properties
  set blk_mem_gen_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_1 ]
  set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {2500} \
    CONFIG.Write_Width_A {24} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_1

  # Create instance: blk_mem_gen_2, and set properties
  set blk_mem_gen_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_2 ]
  set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {2500} \
    CONFIG.Write_Width_A {24} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_2

  # Create instance: blk_mem_gen_3, and set properties
  set blk_mem_gen_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_3 ]
  set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Write_Depth_A {2500} \
    CONFIG.Write_Width_A {24} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_3

  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property -dict [list \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {1} \
  ] $axi_smc

  # Create instance: rst_ps7_0_50M, and set properties
  set rst_ps7_0_50M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M ]

  # Create instance: bram_controller_width_adapter_0, and set properties
  set bram_controller_width_adapter_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:bram_controller_width_adapter:1.0 bram_controller_width_adapter_0 ]

  # --- Sve veze (interface + port connections) i adresni prostor ---
  # (DDR i FIXED_IO portove je vec kreirao i povezao apply_bd_automation)

  connect_bd_intf_net -intf_net axi_smc_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_bram_controller_0/S_AXI]
  connect_bd_intf_net -intf_net axi_smc_M01_AXI [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins hardware_accelerator_0/s00_axi]
  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_smc/S00_AXI]

  # Create port connections
  connect_bd_net -net axi_bram_controller_0_bram_addr_a [get_bd_pins axi_bram_controller_0/bram_addr_a] [get_bd_pins bram_controller_width_adapter_0/bram_addr_a]
  connect_bd_net -net axi_bram_controller_0_bram_clk_a [get_bd_pins axi_bram_controller_0/bram_clk_a] [get_bd_pins blk_mem_gen_0/clka] [get_bd_pins blk_mem_gen_1/clka] [get_bd_pins blk_mem_gen_2/clka] [get_bd_pins blk_mem_gen_3/clka]
  connect_bd_net -net axi_bram_controller_0_bram_en_a [get_bd_pins axi_bram_controller_0/bram_en_a] [get_bd_pins bram_controller_width_adapter_0/bram_en_a]
  connect_bd_net -net axi_bram_controller_0_bram_we_a [get_bd_pins axi_bram_controller_0/bram_we_a] [get_bd_pins bram_controller_width_adapter_0/bram_we_a]
  connect_bd_net -net axi_bram_controller_0_bram_wrdata_a [get_bd_pins axi_bram_controller_0/bram_wrdata_a] [get_bd_pins bram_controller_width_adapter_0/bram_wrdata_a]
  connect_bd_net -net blk_mem_gen_0_douta [get_bd_pins blk_mem_gen_0/douta] [get_bd_pins bram_controller_router_0/phys1_dout]
  connect_bd_net -net blk_mem_gen_0_doutb [get_bd_pins blk_mem_gen_0/doutb] [get_bd_pins bram_router_0/phys1_dout]
  connect_bd_net -net blk_mem_gen_1_douta [get_bd_pins blk_mem_gen_1/douta] [get_bd_pins bram_controller_router_0/phys2_dout]
  connect_bd_net -net blk_mem_gen_1_doutb [get_bd_pins blk_mem_gen_1/doutb] [get_bd_pins bram_router_0/phys2_dout]
  connect_bd_net -net blk_mem_gen_2_douta [get_bd_pins blk_mem_gen_2/douta] [get_bd_pins bram_controller_router_0/phys3_dout]
  connect_bd_net -net blk_mem_gen_2_doutb [get_bd_pins blk_mem_gen_2/doutb] [get_bd_pins bram_router_0/phys3_dout]
  connect_bd_net -net blk_mem_gen_3_douta [get_bd_pins blk_mem_gen_3/douta] [get_bd_pins bram_controller_router_0/phys4_dout]
  connect_bd_net -net blk_mem_gen_3_doutb [get_bd_pins blk_mem_gen_3/doutb] [get_bd_pins bram_router_0/phys4_dout]
  connect_bd_net -net bram_controller_router_0_ctrl_dout [get_bd_pins bram_controller_router_0/ctrl_dout] [get_bd_pins bram_controller_width_adapter_0/ctrl_dout]
  connect_bd_net -net bram_controller_router_0_phys1_addr [get_bd_pins bram_controller_router_0/phys1_addr] [get_bd_pins blk_mem_gen_0/addra]
  connect_bd_net -net bram_controller_router_0_phys1_din [get_bd_pins bram_controller_router_0/phys1_din] [get_bd_pins blk_mem_gen_0/dina]
  connect_bd_net -net bram_controller_router_0_phys1_en [get_bd_pins bram_controller_router_0/phys1_en] [get_bd_pins blk_mem_gen_0/ena]
  connect_bd_net -net bram_controller_router_0_phys1_we [get_bd_pins bram_controller_router_0/phys1_we] [get_bd_pins blk_mem_gen_0/wea]
  connect_bd_net -net bram_controller_router_0_phys2_addr [get_bd_pins bram_controller_router_0/phys2_addr] [get_bd_pins blk_mem_gen_1/addra]
  connect_bd_net -net bram_controller_router_0_phys2_din [get_bd_pins bram_controller_router_0/phys2_din] [get_bd_pins blk_mem_gen_1/dina]
  connect_bd_net -net bram_controller_router_0_phys2_en [get_bd_pins bram_controller_router_0/phys2_en] [get_bd_pins blk_mem_gen_1/ena]
  connect_bd_net -net bram_controller_router_0_phys2_we [get_bd_pins bram_controller_router_0/phys2_we] [get_bd_pins blk_mem_gen_1/wea]
  connect_bd_net -net bram_controller_router_0_phys3_addr [get_bd_pins bram_controller_router_0/phys3_addr] [get_bd_pins blk_mem_gen_2/addra]
  connect_bd_net -net bram_controller_router_0_phys3_din [get_bd_pins bram_controller_router_0/phys3_din] [get_bd_pins blk_mem_gen_2/dina]
  connect_bd_net -net bram_controller_router_0_phys3_en [get_bd_pins bram_controller_router_0/phys3_en] [get_bd_pins blk_mem_gen_2/ena]
  connect_bd_net -net bram_controller_router_0_phys3_we [get_bd_pins bram_controller_router_0/phys3_we] [get_bd_pins blk_mem_gen_2/wea]
  connect_bd_net -net bram_controller_router_0_phys4_addr [get_bd_pins bram_controller_router_0/phys4_addr] [get_bd_pins blk_mem_gen_3/addra]
  connect_bd_net -net bram_controller_router_0_phys4_din [get_bd_pins bram_controller_router_0/phys4_din] [get_bd_pins blk_mem_gen_3/dina]
  connect_bd_net -net bram_controller_router_0_phys4_en [get_bd_pins bram_controller_router_0/phys4_en] [get_bd_pins blk_mem_gen_3/ena]
  connect_bd_net -net bram_controller_router_0_phys4_we [get_bd_pins bram_controller_router_0/phys4_we] [get_bd_pins blk_mem_gen_3/wea]
  connect_bd_net -net bram_controller_width_adapter_0_bram_rddata_a [get_bd_pins bram_controller_width_adapter_0/bram_rddata_a] [get_bd_pins axi_bram_controller_0/bram_rddata_a]
  connect_bd_net -net bram_controller_width_adapter_0_ctrl_addr [get_bd_pins bram_controller_width_adapter_0/ctrl_addr] [get_bd_pins bram_controller_router_0/ctrl_addr]
  connect_bd_net -net bram_controller_width_adapter_0_ctrl_din [get_bd_pins bram_controller_width_adapter_0/ctrl_din] [get_bd_pins bram_controller_router_0/ctrl_din]
  connect_bd_net -net bram_controller_width_adapter_0_ctrl_en [get_bd_pins bram_controller_width_adapter_0/ctrl_en] [get_bd_pins bram_controller_router_0/ctrl_en]
  connect_bd_net -net bram_controller_width_adapter_0_ctrl_we [get_bd_pins bram_controller_width_adapter_0/ctrl_we] [get_bd_pins bram_controller_router_0/ctrl_we]
  connect_bd_net -net bram_router_0_bram1_dout [get_bd_pins bram_router_0/bram1_dout] [get_bd_pins hardware_accelerator_0/bram1_dout]
  connect_bd_net -net bram_router_0_bram2_dout [get_bd_pins bram_router_0/bram2_dout] [get_bd_pins hardware_accelerator_0/bram2_dout]
  connect_bd_net -net bram_router_0_bram3_dout [get_bd_pins bram_router_0/bram3_dout] [get_bd_pins hardware_accelerator_0/bram3_dout]
  connect_bd_net -net bram_router_0_bram4_dout [get_bd_pins bram_router_0/bram4_dout] [get_bd_pins hardware_accelerator_0/bram4_dout]
  connect_bd_net -net bram_router_0_bram_dout [get_bd_pins bram_router_0/bram_dout] [get_bd_pins hardware_accelerator_0/bram_dout]
  connect_bd_net -net bram_router_0_phys1_addr [get_bd_pins bram_router_0/phys1_addr] [get_bd_pins blk_mem_gen_0/addrb]
  connect_bd_net -net bram_router_0_phys1_din [get_bd_pins bram_router_0/phys1_din] [get_bd_pins blk_mem_gen_0/dinb]
  connect_bd_net -net bram_router_0_phys1_en [get_bd_pins bram_router_0/phys1_en] [get_bd_pins blk_mem_gen_0/enb]
  connect_bd_net -net bram_router_0_phys1_we [get_bd_pins bram_router_0/phys1_we] [get_bd_pins blk_mem_gen_0/web]
  connect_bd_net -net bram_router_0_phys2_addr [get_bd_pins bram_router_0/phys2_addr] [get_bd_pins blk_mem_gen_1/addrb]
  connect_bd_net -net bram_router_0_phys2_din [get_bd_pins bram_router_0/phys2_din] [get_bd_pins blk_mem_gen_1/dinb]
  connect_bd_net -net bram_router_0_phys2_en [get_bd_pins bram_router_0/phys2_en] [get_bd_pins blk_mem_gen_1/enb]
  connect_bd_net -net bram_router_0_phys2_we [get_bd_pins bram_router_0/phys2_we] [get_bd_pins blk_mem_gen_1/web]
  connect_bd_net -net bram_router_0_phys3_addr [get_bd_pins bram_router_0/phys3_addr] [get_bd_pins blk_mem_gen_2/addrb]
  connect_bd_net -net bram_router_0_phys3_din [get_bd_pins bram_router_0/phys3_din] [get_bd_pins blk_mem_gen_2/dinb]
  connect_bd_net -net bram_router_0_phys3_en [get_bd_pins bram_router_0/phys3_en] [get_bd_pins blk_mem_gen_2/enb]
  connect_bd_net -net bram_router_0_phys3_we [get_bd_pins bram_router_0/phys3_we] [get_bd_pins blk_mem_gen_2/web]
  connect_bd_net -net bram_router_0_phys4_addr [get_bd_pins bram_router_0/phys4_addr] [get_bd_pins blk_mem_gen_3/addrb]
  connect_bd_net -net bram_router_0_phys4_din [get_bd_pins bram_router_0/phys4_din] [get_bd_pins blk_mem_gen_3/dinb]
  connect_bd_net -net bram_router_0_phys4_en [get_bd_pins bram_router_0/phys4_en] [get_bd_pins blk_mem_gen_3/enb]
  connect_bd_net -net bram_router_0_phys4_we [get_bd_pins bram_router_0/phys4_we] [get_bd_pins blk_mem_gen_3/web]
  connect_bd_net -net hardware_accelerator_0_bram1_addr [get_bd_pins hardware_accelerator_0/bram1_addr] [get_bd_pins bram_router_0/bram1_addr]
  connect_bd_net -net hardware_accelerator_0_bram1_din [get_bd_pins hardware_accelerator_0/bram1_din] [get_bd_pins bram_router_0/bram1_din]
  connect_bd_net -net hardware_accelerator_0_bram1_en [get_bd_pins hardware_accelerator_0/bram1_en] [get_bd_pins bram_router_0/bram1_en]
  connect_bd_net -net hardware_accelerator_0_bram1_we [get_bd_pins hardware_accelerator_0/bram1_we] [get_bd_pins bram_router_0/bram1_we]
  connect_bd_net -net hardware_accelerator_0_bram2_addr [get_bd_pins hardware_accelerator_0/bram2_addr] [get_bd_pins bram_router_0/bram2_addr]
  connect_bd_net -net hardware_accelerator_0_bram2_din [get_bd_pins hardware_accelerator_0/bram2_din] [get_bd_pins bram_router_0/bram2_din]
  connect_bd_net -net hardware_accelerator_0_bram2_en [get_bd_pins hardware_accelerator_0/bram2_en] [get_bd_pins bram_router_0/bram2_en]
  connect_bd_net -net hardware_accelerator_0_bram2_we [get_bd_pins hardware_accelerator_0/bram2_we] [get_bd_pins bram_router_0/bram2_we]
  connect_bd_net -net hardware_accelerator_0_bram3_addr [get_bd_pins hardware_accelerator_0/bram3_addr] [get_bd_pins bram_router_0/bram3_addr]
  connect_bd_net -net hardware_accelerator_0_bram3_din [get_bd_pins hardware_accelerator_0/bram3_din] [get_bd_pins bram_router_0/bram3_din]
  connect_bd_net -net hardware_accelerator_0_bram3_en [get_bd_pins hardware_accelerator_0/bram3_en] [get_bd_pins bram_router_0/bram3_en]
  connect_bd_net -net hardware_accelerator_0_bram3_we [get_bd_pins hardware_accelerator_0/bram3_we] [get_bd_pins bram_router_0/bram3_we]
  connect_bd_net -net hardware_accelerator_0_bram4_addr [get_bd_pins hardware_accelerator_0/bram4_addr] [get_bd_pins bram_router_0/bram4_addr]
  connect_bd_net -net hardware_accelerator_0_bram4_din [get_bd_pins hardware_accelerator_0/bram4_din] [get_bd_pins bram_router_0/bram4_din]
  connect_bd_net -net hardware_accelerator_0_bram4_en [get_bd_pins hardware_accelerator_0/bram4_en] [get_bd_pins bram_router_0/bram4_en]
  connect_bd_net -net hardware_accelerator_0_bram4_we [get_bd_pins hardware_accelerator_0/bram4_we] [get_bd_pins bram_router_0/bram4_we]
  connect_bd_net -net hardware_accelerator_0_bram_addr [get_bd_pins hardware_accelerator_0/bram_addr] [get_bd_pins bram_router_0/bram_addr]
  connect_bd_net -net hardware_accelerator_0_bram_din [get_bd_pins hardware_accelerator_0/bram_din] [get_bd_pins bram_router_0/bram_din]
  connect_bd_net -net hardware_accelerator_0_bram_en [get_bd_pins hardware_accelerator_0/bram_en] [get_bd_pins bram_router_0/bram_en]
  connect_bd_net -net hardware_accelerator_0_bram_parallel [get_bd_pins hardware_accelerator_0/bram_parallel] [get_bd_pins bram_router_0/bram_parallel]
  connect_bd_net -net hardware_accelerator_0_bram_we [get_bd_pins hardware_accelerator_0/bram_we] [get_bd_pins bram_router_0/bram_we]
  connect_bd_net -net hardware_accelerator_0_irq_out [get_bd_pins hardware_accelerator_0/irq_out] [get_bd_pins processing_system7_0/IRQ_F2P]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_pins axi_smc/aclk] [get_bd_pins axi_bram_controller_0/s_axi_aclk] [get_bd_pins rst_ps7_0_50M/slowest_sync_clk] [get_bd_pins bram_router_0/clk] [get_bd_pins hardware_accelerator_0/s00_axi_aclk]
  connect_bd_net -net processing_system7_0_FCLK_RESET0_N [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
  connect_bd_net -net rst_ps7_0_50M_peripheral_aresetn [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_bram_controller_0/s_axi_aresetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins hardware_accelerator_0/s00_axi_aresetn]

  assign_bd_address -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_bram_controller_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x40010000 -range 0x00001000 -with_name SEG_gbfs_hardware_accelerator_0_reg0 -target_address_space [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs hardware_accelerator_0/s00_axi/reg0] -force

puts "Block design zavrsen."

validate_bd_design
save_bd_design

puts "Validacija uspesna."

make_wrapper -files [get_files $BD_NAME.bd] -top
add_files -norecurse [glob $BD_PROJ_DIR/$BD_PROJ_NAME.gen/sources_1/bd/$BD_NAME/hdl/${BD_NAME}_wrapper.v]
update_compile_order -fileset sources_1

puts "HDL Wrapper generisan."

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Sinteza nije uspela."
}

puts "Sinteza zavrsena."

set_property strategy Performance_Retiming [get_runs impl_1]

launch_runs impl_1 -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "route_design Complete!"} {
    error "Implementacija nije uspela."
}

puts "Implementacija zavrsena."

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Bitstream generisan."

write_hw_platform -fixed -include_bit -force -file $XSA_OUTPUT

puts "Zavrseno. XSA: $XSA_OUTPUT"

file delete -force $PKG_WORK_DIR
