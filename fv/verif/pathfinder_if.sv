`timescale 1ns/1ps

`ifndef PATHFINDER_IF_SV
 `define PATHFINDER_IF_SV

// Interfejs obuhvata kompletnu granicu DUT-a:
//  - AXI4-Lite slave interfejs (registri START/END/CONTROL/STATUS)
//  - prekidni signal irq_out
//  - port A memorije (ravan pristup; dekodovanje na 4 banke radi verif_top)
interface pathfinder_if (input logic clk);

   // Reset, aktivan nizak. Njime upravlja drajver.
   logic        aresetn = 1'b0;

   // AXI4-Lite write kanali
   logic [3:0]  awaddr  = '0;
   logic        awvalid = 1'b0;
   logic        awready;
   logic [31:0] wdata   = '0;
   logic [3:0]  wstrb   = 4'hF;
   logic        wvalid  = 1'b0;
   logic        wready;
   logic [1:0]  bresp;
   logic        bvalid;
   logic        bready  = 1'b0;

   // AXI4-Lite read kanali
   logic [3:0]  araddr  = '0;
   logic        arvalid = 1'b0;
   logic        arready;
   logic [31:0] rdata;
   logic [1:0]  rresp;
   logic        rvalid;
   logic        rready  = 1'b0;

   // Prekid ka procesoru
   logic        irq_out;

   // Port A memorije mape (ravna adresa 0 - 9999)
   logic        mem_en   = 1'b0;
   logic        mem_we   = 1'b0;
   logic [13:0] mem_addr = '0;
   logic [23:0] mem_din  = '0;
   logic [23:0] mem_dout;

endinterface : pathfinder_if

`endif
