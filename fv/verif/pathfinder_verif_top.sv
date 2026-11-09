`timescale 1ns/1ps

// Verifikacioni top modul.
// Topologija je ista kao u referentnom tb_axi_verify.vhd:
//   - DUT je pathfinder_axi (AXI4-Lite omotac oko akceleratora),
//   - bram_router i 4 x bram cine memorijski harness (port B = strana DUT-a),
//   - UVM okruzenje pristupa memoriji kroz port A (ucitavanje mape i citanje
//     rezultata), uz kombinaciono dekodovanje ravne adrese na 4 banke.
module pathfinder_verif_top;

   import uvm_pkg::*;
 `include "uvm_macros.svh"
   import pathfinder_test_pkg::*;

   localparam int BRAM_DEPTH = 2500;

   // ------------------------------------------------------------------
   // Takt: 100 MHz, kao na ploci (FCLK_CLK0).
   // ------------------------------------------------------------------
   logic clk = 1'b0;
   always #5 clk = ~clk;

   // ------------------------------------------------------------------
   // Interfejs ka UVM okruzenju
   // ------------------------------------------------------------------
   pathfinder_if vif (clk);

   // ------------------------------------------------------------------
   // Signali izmedju DUT-a i bram_router-a
   // ------------------------------------------------------------------
   logic        bram_en, bram_we;
   logic [13:0] bram_addr;
   logic [23:0] bram_din, bram_dout;
   logic        bram_parallel;

   logic        bram1_en, bram2_en, bram3_en, bram4_en;
   logic        bram1_we, bram2_we, bram3_we, bram4_we;
   logic [11:0] bram1_addr, bram2_addr, bram3_addr, bram4_addr;
   logic [23:0] bram1_din,  bram2_din,  bram3_din,  bram4_din;
   logic [23:0] bram1_dout, bram2_dout, bram3_dout, bram4_dout;

   // Signali izmedju bram_router-a i fizickih memorija (port B)
   logic        phys1_en, phys2_en, phys3_en, phys4_en;
   logic        phys1_we, phys2_we, phys3_we, phys4_we;
   logic [11:0] phys1_addr, phys2_addr, phys3_addr, phys4_addr;
   logic [23:0] phys1_din,  phys2_din,  phys3_din,  phys4_din;
   logic [23:0] phys1_dout, phys2_dout, phys3_dout, phys4_dout;

   // ------------------------------------------------------------------
   // DUT
   // ------------------------------------------------------------------
   pathfinder_axi #(
      .GRID_SIZE            (100),
      .ADDR_BITS            (14),
      .DATA_BITS            (24),
      .C_S00_AXI_DATA_WIDTH (32),
      .C_S00_AXI_ADDR_WIDTH (4)
   ) dut (
      .irq_out         (vif.irq_out),

      .bram_en         (bram_en),
      .bram_we         (bram_we),
      .bram_addr       (bram_addr),
      .bram_din        (bram_din),
      .bram_dout       (bram_dout),

      .bram_parallel   (bram_parallel),

      .bram1_en (bram1_en), .bram1_we (bram1_we), .bram1_addr (bram1_addr), .bram1_din (bram1_din), .bram1_dout (bram1_dout),
      .bram2_en (bram2_en), .bram2_we (bram2_we), .bram2_addr (bram2_addr), .bram2_din (bram2_din), .bram2_dout (bram2_dout),
      .bram3_en (bram3_en), .bram3_we (bram3_we), .bram3_addr (bram3_addr), .bram3_din (bram3_din), .bram3_dout (bram3_dout),
      .bram4_en (bram4_en), .bram4_we (bram4_we), .bram4_addr (bram4_addr), .bram4_din (bram4_din), .bram4_dout (bram4_dout),

      .s00_axi_aclk    (clk),
      .s00_axi_aresetn (vif.aresetn),

      .s00_axi_awaddr  (vif.awaddr),
      .s00_axi_awprot  (3'b000),
      .s00_axi_awvalid (vif.awvalid),
      .s00_axi_awready (vif.awready),

      .s00_axi_wdata   (vif.wdata),
      .s00_axi_wstrb   (vif.wstrb),
      .s00_axi_wvalid  (vif.wvalid),
      .s00_axi_wready  (vif.wready),

      .s00_axi_bresp   (vif.bresp),
      .s00_axi_bvalid  (vif.bvalid),
      .s00_axi_bready  (vif.bready),

      .s00_axi_araddr  (vif.araddr),
      .s00_axi_arprot  (3'b000),
      .s00_axi_arvalid (vif.arvalid),
      .s00_axi_arready (vif.arready),

      .s00_axi_rdata   (vif.rdata),
      .s00_axi_rresp   (vif.rresp),
      .s00_axi_rvalid  (vif.rvalid),
      .s00_axi_rready  (vif.rready)
   );

   // ------------------------------------------------------------------
   // Memorijski harness: router + 4 banke
   // ------------------------------------------------------------------
   bram_router #(
      .ADDR_BITS  (14),
      .SUB_BITS   (12),
      .DATA_BITS  (24),
      .BRAM_DEPTH (BRAM_DEPTH)
   ) router_inst (
      .clk           (clk),
      .bram_parallel (bram_parallel),

      .bram_en   (bram_en),
      .bram_we   (bram_we),
      .bram_addr (bram_addr),
      .bram_din  (bram_din),
      .bram_dout (bram_dout),

      .bram1_en (bram1_en), .bram1_we (bram1_we), .bram1_addr (bram1_addr), .bram1_din (bram1_din), .bram1_dout (bram1_dout),
      .bram2_en (bram2_en), .bram2_we (bram2_we), .bram2_addr (bram2_addr), .bram2_din (bram2_din), .bram2_dout (bram2_dout),
      .bram3_en (bram3_en), .bram3_we (bram3_we), .bram3_addr (bram3_addr), .bram3_din (bram3_din), .bram3_dout (bram3_dout),
      .bram4_en (bram4_en), .bram4_we (bram4_we), .bram4_addr (bram4_addr), .bram4_din (bram4_din), .bram4_dout (bram4_dout),

      .phys1_en (phys1_en), .phys1_we (phys1_we), .phys1_addr (phys1_addr), .phys1_din (phys1_din), .phys1_dout (phys1_dout),
      .phys2_en (phys2_en), .phys2_we (phys2_we), .phys2_addr (phys2_addr), .phys2_din (phys2_din), .phys2_dout (phys2_dout),
      .phys3_en (phys3_en), .phys3_we (phys3_we), .phys3_addr (phys3_addr), .phys3_din (phys3_din), .phys3_dout (phys3_dout),
      .phys4_en (phys4_en), .phys4_we (phys4_we), .phys4_addr (phys4_addr), .phys4_din (phys4_din), .phys4_dout (phys4_dout)
   );

   // ------------------------------------------------------------------
   // Dekodovanje ravne UVM adrese (0-9999) na banku i pod-adresu,
   // po istoj podeli kao u bram_router-u: banka k drzi adrese
   // [k*2500, (k+1)*2500).
   // ------------------------------------------------------------------
   logic [1:0]  a_sel;
   logic [1:0]  a_sel_q;
   logic [11:0] a_sub;

   always_comb begin
      if (vif.mem_addr < BRAM_DEPTH) begin
         a_sel = 2'd0;
         a_sub = 12'(vif.mem_addr);
      end
      else if (vif.mem_addr < 2 * BRAM_DEPTH) begin
         a_sel = 2'd1;
         a_sub = 12'(vif.mem_addr - 14'(BRAM_DEPTH));
      end
      else if (vif.mem_addr < 3 * BRAM_DEPTH) begin
         a_sel = 2'd2;
         a_sub = 12'(vif.mem_addr - 14'(2 * BRAM_DEPTH));
      end
      else begin
         a_sel = 2'd3;
         a_sub = 12'(vif.mem_addr - 14'(3 * BRAM_DEPTH));
      end
   end

   // Registrovan izbor banke za citanje (BRAM ima jedan takt latencije).
   always_ff @(posedge clk)
     a_sel_q <= a_sel;

   logic        a_en1, a_en2, a_en3, a_en4;
   logic        a_we1, a_we2, a_we3, a_we4;
   logic [23:0] a_dout1, a_dout2, a_dout3, a_dout4;

   assign a_en1 = vif.mem_en && (a_sel == 2'd0);
   assign a_en2 = vif.mem_en && (a_sel == 2'd1);
   assign a_en3 = vif.mem_en && (a_sel == 2'd2);
   assign a_en4 = vif.mem_en && (a_sel == 2'd3);

   assign a_we1 = vif.mem_we && (a_sel == 2'd0);
   assign a_we2 = vif.mem_we && (a_sel == 2'd1);
   assign a_we3 = vif.mem_we && (a_sel == 2'd2);
   assign a_we4 = vif.mem_we && (a_sel == 2'd3);

   always_comb begin
      case (a_sel_q)
        2'd0    : vif.mem_dout = a_dout1;
        2'd1    : vif.mem_dout = a_dout2;
        2'd2    : vif.mem_dout = a_dout3;
        default : vif.mem_dout = a_dout4;
      endcase
   end

   // Port A = UVM strana, Port B = DUT strana (kroz router).
   bram bram1_inst (
      .clka (clk), .ena (a_en1), .wea (a_we1), .addra (a_sub), .dina (vif.mem_din), .douta (a_dout1),
      .enb (phys1_en), .web (phys1_we), .addrb (phys1_addr), .dinb (phys1_din), .doutb (phys1_dout)
   );

   bram bram2_inst (
      .clka (clk), .ena (a_en2), .wea (a_we2), .addra (a_sub), .dina (vif.mem_din), .douta (a_dout2),
      .enb (phys2_en), .web (phys2_we), .addrb (phys2_addr), .dinb (phys2_din), .doutb (phys2_dout)
   );

   bram bram3_inst (
      .clka (clk), .ena (a_en3), .wea (a_we3), .addra (a_sub), .dina (vif.mem_din), .douta (a_dout3),
      .enb (phys3_en), .web (phys3_we), .addrb (phys3_addr), .dinb (phys3_din), .doutb (phys3_dout)
   );

   bram bram4_inst (
      .clka (clk), .ena (a_en4), .wea (a_we4), .addra (a_sub), .dina (vif.mem_din), .douta (a_dout4),
      .enb (phys4_en), .web (phys4_we), .addrb (phys4_addr), .dinb (phys4_din), .doutb (phys4_dout)
   );

   // ------------------------------------------------------------------
   // Start UVM-a
   // ------------------------------------------------------------------
   initial begin
      uvm_config_db#(virtual pathfinder_if)::set(null, "*", "pathfinder_vif", vif);
      run_test();
   end

endmodule : pathfinder_verif_top
