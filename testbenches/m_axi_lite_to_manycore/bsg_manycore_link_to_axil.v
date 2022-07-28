// Copyright (c) 2019, University of Washington All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// Neither the name of the copyright holder nor the names of its contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
// ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


/*
 *  bsg_manycore_link_to_axil.v
 *
 * This is an open-source module to bridge the manycore symmetric links with the
 * AXI-Lite master interface.
 * It handles the AXIL transactions differently based on the w/r address.
 * Write -> tx_FIFO -> SIPO -> host_request
 * Read  <- PISO <- rx_FIFO <- mc_response
 *       <- PISO <- rx_FIFO <- mc_request
 *       <- ROM
 *       <- vacancy of tx_FIFO + SIPO
 *       <- endpoint out credits
 *       <- occupancy of rx_FIFO (mc_request)
 * And it shall always complete the AXIL transaction if gets invalid address.
 *
 * Google doc:
 * https://docs.google.com/document/d/1-jSBELaYREEqtGOUD4_yAnl4EJRAZ0hOJfu-_1ZQllw
 *
 */

module bsg_manycore_link_to_axil
  import bsg_manycore_pkg::*;
   import bsg_manycore_link_to_axil_pkg::*;
   #(
     // Width of the host packets
     parameter host_io_pkt_width_p = "inv"
     // Number of packet entries in the host TRANSMIT FIFO
     , parameter host_io_pkts_tx_p = "inv"
     // Number of packet entries in the host RECEIVE FIFO
     , parameter host_io_pkts_rx_p = "inv"
     // AXI-Lite parameters
     , localparam axil_data_width_lp = axil_data_width_gp
     , localparam axil_addr_width_lp = axil_addr_width_gp
     // endpoint params
     , parameter x_cord_width_p = "inv"
     , parameter y_cord_width_p = "inv"
     , parameter addr_width_p = "inv"
     , parameter data_width_p = "inv"
     , parameter cycle_width_p = "inv"
     , localparam credit_counter_width_lp = `BSG_WIDTH(bsg_machine_io_ep_credits_gp)
     , localparam ep_fifo_els_lp = 4
     , localparam rev_fifo_els_lp = 3
     , localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
     ) 
   (
    input clk_i
    ,input reset_i
    // axil signals
    ,input axil_awvalid_i
    ,input [ axil_addr_width_lp-1:0] axil_awaddr_i
    ,output axil_awready_o
    ,input axil_wvalid_i
    ,input [ axil_data_width_lp-1:0] axil_wdata_i
    ,input [(axil_data_width_gp>>3)-1:0] axil_wstrb_i // unused
    ,output axil_wready_o
    ,output [ 1:0] axil_bresp_o
    ,output axil_bvalid_o
    ,input axil_bready_i
    ,input [ axil_addr_width_lp-1:0] axil_araddr_i
    ,input axil_arvalid_i
    ,output axil_arready_o
    ,output [ axil_data_width_lp-1:0] axil_rdata_o
    ,output [ 1:0] axil_rresp_o
    ,output axil_rvalid_o
    ,input axil_rready_i
    // manycore link signals
    ,input [ link_sif_width_lp-1:0] link_sif_i
    ,output [ link_sif_width_lp-1:0] link_sif_o
    ,input [ x_cord_width_p-1:0] global_x_i
    ,input [ y_cord_width_p-1:0] global_y_i
    // cycle counter
    ,input [ cycle_width_p-1:0] cycle_ctr_i
    );


   // Dependencies between channel handshake signals
   // -------------------------------------------------------
   // axil write channels
   // bvalid : must wait for wvalid & wready
   // bresp: must be signaled only after the write data

   // See details in ARM's DOC:
   // https://developer.arm.com/docs/ihi0022/d ,A3.3.1
   // -------------------------------------------------------


   // axil write data path
   // -----------------------

  logic awvalid_li, awyumi_lo;
  logic [axil_addr_width_lp-1:0] awaddr_li;
  logic wvalid_li, wyumi_lo;
  logic [axil_data_width_lp-1:0] wdata_li;
  logic bvalid_lo, bready_li;

  bsg_two_fifo
 #(.width_p(axil_addr_width_lp)
  ) aw_twofer
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (axil_awvalid_i)
  ,.data_i (axil_awaddr_i)
  ,.ready_o(axil_awready_o)
  ,.v_o    (awvalid_li)
  ,.data_o (awaddr_li)
  ,.yumi_i (awyumi_lo)
  );

  bsg_two_fifo
 #(.width_p(axil_data_width_lp)
  ) w_twofer
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (axil_wvalid_i)
  ,.data_i (axil_wdata_i)
  ,.ready_o(axil_wready_o)
  ,.v_o    (wvalid_li)
  ,.data_o (wdata_li)
  ,.yumi_i (wyumi_lo)
  );

  bsg_two_fifo
 #(.width_p(1)
  ) b_twofer
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (bvalid_lo)
  ,.data_i (1'b0)
  ,.ready_o(bready_li)
  ,.v_o    (axil_bvalid_o)
  ,.data_o ()
  ,.yumi_i (axil_bvalid_o & axil_bready_i)
  );
  assign axil_bresp_o = axil_resp_OKAY_gp;

  // host request
  logic [axil_data_width_lp-1:0] tx_axil_req_li;
  logic                          tx_axil_req_v_li;
  logic                          tx_axil_req_ready_lo;

  wire is_write_to_tdr = (awaddr_li == mcl_fifo_base_addr_gp + mcl_ofs_tdr_gp);

  assign wyumi_lo  = awyumi_lo;
  assign bvalid_lo = awyumi_lo;

  always_comb
  begin
   awyumi_lo = 1'b0;
   tx_axil_req_v_li = 1'b0;
   tx_axil_req_li = '0;
   if (awvalid_li & wvalid_li & bready_li)
     begin
       if (is_write_to_tdr)
         begin
           tx_axil_req_v_li = 1'b1;
           awyumi_lo = tx_axil_req_ready_lo;
           tx_axil_req_li = wdata_li;
         end
       else
         begin
           awyumi_lo = 1'b1;
         end
     end
   end


  // axil read data paths
  // -----------------------

  logic arvalid_li, aryumi_lo;
  logic [axil_addr_width_lp-1:0] araddr_li;
  logic rvalid_lo, rready_li;
  logic [axil_data_width_lp-1:0] rdata_lo;

  bsg_two_fifo
 #(.width_p(axil_addr_width_lp)
  ) ar_twofer
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (axil_arvalid_i)
  ,.data_i (axil_araddr_i)
  ,.ready_o(axil_arready_o)
  ,.v_o    (arvalid_li)
  ,.data_o (araddr_li)
  ,.yumi_i (aryumi_lo)
  );

  bsg_two_fifo
 #(.width_p(axil_data_width_lp)
  ) r_twofer
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (rvalid_lo)
  ,.data_i (rdata_lo)
  ,.ready_o(rready_li)
  ,.v_o    (axil_rvalid_o)
  ,.data_o (axil_rdata_o)
  ,.yumi_i (axil_rvalid_o & axil_rready_i)
  );
  assign axil_rresp_o = axil_resp_OKAY_gp;

  // 1. tx response
  logic [axil_data_width_lp-1:0]            tx_axil_rsp_lo;
  logic                                     tx_axil_rsp_v_lo;
  logic                                     tx_axil_rsp_ready_li;

  // 2. credit registers
  localparam ratio_lp = host_io_pkt_width_p/axil_data_width_lp;
  localparam tx_req_width_lp = `BSG_WIDTH(ratio_lp*host_io_pkts_tx_p);
  localparam rx_req_width_lp = `BSG_WIDTH(ratio_lp*host_io_pkts_rx_p);

  logic [tx_req_width_lp-1:0] tx_req_credits_lo;
  logic [rx_req_width_lp-1:0] rx_req_credits_lo;
  logic [credit_counter_width_lp-1:0] ep_out_credits_used_lo;

  // 3. tx request
  logic [axil_data_width_lp-1:0]            rx_axil_req_lo;
  logic                                     rx_axil_req_v_lo;
  logic                                     rx_axil_req_ready_li;

  // 4. rom
  logic [axil_addr_width_lp-1:0]            rx_rom_addr_li;
  logic [axil_data_width_lp-1:0]            rx_rom_data_lo;

  wire is_read_counter_low   = (araddr_li == mcl_ofs_counter_low_gp);
  wire is_read_counter_high  = (araddr_li == mcl_ofs_counter_high_gp);
  wire is_read_credit        = (araddr_li == mcl_ofs_credits_gp);
  wire is_read_rdr_rsp       = (araddr_li == mcl_fifo_base_addr_gp + mcl_ofs_rdr_rsp_gp);
  wire is_read_tdfv_host_req = (araddr_li == mcl_fifo_base_addr_gp + mcl_ofs_tdfv_req_gp);
  wire is_read_rdfo_mc_req   = (araddr_li == mcl_fifo_base_addr_gp + mcl_ofs_rdfo_req_gp);
  wire is_read_rdr_req       = (araddr_li == mcl_fifo_base_addr_gp + mcl_ofs_rdr_req_gp);
  wire is_read_rom           = (araddr_li >= mcl_rom_base_addr_gp) &&
       (araddr_li < mcl_rom_base_addr_gp + (1<<$clog2(bsg_machine_rom_els_gp*bsg_machine_rom_width_gp/8)));

  assign rvalid_lo = aryumi_lo;

  always_comb
  begin
    aryumi_lo = 1'b0;
    rdata_lo = '0;
    tx_axil_rsp_ready_li = 1'b0;
    rx_axil_req_ready_li = 1'b0;
    rx_rom_addr_li = '0;
    if (arvalid_li & rready_li)
      begin
        if (is_read_credit)
          begin  // always accept and return the manycore endpoint out credits
            aryumi_lo = 1'b1;
            rdata_lo = axil_data_width_lp'(ep_out_credits_used_lo);
          end
        else if (is_read_rdr_rsp)
          begin  // accept the read address only when fifo data is valid
            tx_axil_rsp_ready_li = 1'b1;
            aryumi_lo = tx_axil_rsp_v_lo;
            rdata_lo = tx_axil_rsp_lo;
          end
        else if (is_read_tdfv_host_req)
          begin  // always accept and return the vacancy of host req fifo in words
            aryumi_lo = 1'b1;
            rdata_lo = axil_data_width_lp'(tx_req_credits_lo);
          end
        else if (is_read_rdfo_mc_req)
          begin  // always accept and return the occupancy of rx words
            aryumi_lo = 1'b1;
            rdata_lo = axil_data_width_lp'(rx_req_credits_lo);
          end
        else if (is_read_rdr_req)
          begin  // accept the read address only when fifo data is valid
            rx_axil_req_ready_li = 1'b1;
            aryumi_lo = rx_axil_req_v_lo;
            rdata_lo = rx_axil_req_lo;
          end
        else if (is_read_rom)
          begin
            aryumi_lo = 1'b1;
            rdata_lo = axil_data_width_lp'(rx_rom_data_lo);
            rx_rom_addr_li = (araddr_li - mcl_rom_base_addr_gp);
          end
        else if (is_read_counter_low)
          begin
            aryumi_lo = 1'b1;
            rdata_lo = cycle_ctr_i[axil_data_width_lp-1:0];
          end
        else if (is_read_counter_high)
          begin
            aryumi_lo = 1'b1;
            rdata_lo = cycle_ctr_i[axil_data_width_lp+: axil_data_width_lp];
          end
        else
          begin
            aryumi_lo = 1'b1;
            rdata_lo = axil_data_width_lp'(32'hdead_beef);
          end
      end
  end


   // ----------------------------
   // bladerunner rom
   // ----------------------------
   // The rom not necessarily in the mcl, so we put its parameters in other package.
   localparam rom_addr_width_lp = `BSG_SAFE_CLOG2(bsg_machine_rom_els_gp);

   wire [rom_addr_width_lp-1:0] br_rom_addr_li = rx_rom_addr_li[$clog2(bsg_machine_rom_width_gp/8)+:rom_addr_width_lp];

   logic [bsg_machine_rom_width_gp-1:0]     br_rom_data_lo;

   assign rx_rom_data_lo = axil_data_width_lp'(br_rom_data_lo);

   bsg_bladerunner_configuration 
     #(
       .width_p     (bsg_machine_rom_width_gp),
       .addr_width_p(rom_addr_width_lp)
       ) 
   configuration_rom 
     (
      .addr_i(br_rom_addr_li),
      .data_o(br_rom_data_lo)
      );


   // --------------------------------------------
   // axil fifo data stream
   // --------------------------------------------

   // host ---packet---> mc
   logic [host_io_pkt_width_p-1:0] tx_fifo_req_lo;
   logic                           tx_fifo_req_v_lo;
   logic                           tx_fifo_req_ready_li;

   logic [host_io_pkt_width_p-1:0] tx_ep_req_li;
   logic                           tx_ep_req_v_li;
   logic                           tx_ep_req_ready_lo;

   // host <---credit--- mc
   logic [host_io_pkt_width_p-1:0] tx_fifo_rsp_li;
   logic                           tx_fifo_rsp_v_li;
   logic                           tx_fifo_rsp_ready_lo;

   // mc ---packet---> host
   logic [host_io_pkt_width_p-1:0] rx_fifo_req_li;
   logic                           rx_fifo_req_v_li;
   logic                           rx_fifo_req_ready_lo;

   bsg_mcl_axil_fifos_tx
  #(.x_cord_width_p   (x_cord_width_p)
   ,.y_cord_width_p   (y_cord_width_p)
   ,.addr_width_p     (addr_width_p)
   ,.data_width_p     (data_width_p)
   ,.fifo_width_p     (host_io_pkt_width_p)
   ,.req_credits_p    (host_io_pkts_tx_p)
   ,.read_credits_p   (host_io_pkts_tx_p)
   ,.axil_data_width_p(axil_data_width_lp)
   ) tx
   (.clk_i            (clk_i)
   ,.reset_i          (reset_i)

   ,.axil_req_i       (tx_axil_req_li)
   ,.axil_req_v_i     (tx_axil_req_v_li)
   ,.axil_req_ready_o (tx_axil_req_ready_lo)
   ,.axil_rsp_o       (tx_axil_rsp_lo)
   ,.axil_rsp_v_o     (tx_axil_rsp_v_lo)
   ,.axil_rsp_ready_i (tx_axil_rsp_ready_li)
   ,.fifo_req_o       (tx_fifo_req_lo)
   ,.fifo_req_v_o     (tx_fifo_req_v_lo)
   ,.fifo_req_ready_i (tx_fifo_req_ready_li)
   ,.fifo_rsp_i       (tx_fifo_rsp_li)
   ,.fifo_rsp_v_i     (tx_fifo_rsp_v_li)
   ,.fifo_rsp_ready_o (tx_fifo_rsp_ready_lo)
   ,.req_credits_o    (tx_req_credits_lo)
   );

   bsg_mcl_axil_fifos_rx
  #(.fifo_width_p     (host_io_pkt_width_p)
   ,.req_credits_p    (host_io_pkts_rx_p)
   ,.axil_data_width_p(axil_data_width_lp)
   ) rx
   (.clk_i            (clk_i)
   ,.reset_i          (reset_i)

   ,.axil_req_o       (rx_axil_req_lo)
   ,.axil_req_v_o     (rx_axil_req_v_lo)
   ,.axil_req_ready_i (rx_axil_req_ready_li)
   ,.fifo_req_i       (rx_fifo_req_li)
   ,.fifo_req_v_i     (rx_fifo_req_v_li)
   ,.fifo_req_ready_o (rx_fifo_req_ready_lo)
   ,.req_credits_o    (rx_req_credits_lo)
   );

   // See reference below for how to attach modules to the manycore endpoint:
   // Xie, S, Taylor, M. B. (2018). The BaseJump Manycore Accelerator Network. arXiv:1808.00650.

   logic [link_sif_width_lp-1:0] link_sif_credit_li;
   logic [link_sif_width_lp-1:0] link_sif_credit_lo;

   bsg_manycore_link_resp_credit_to_ready_and_handshake
    #(.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      )
    rev_c2r
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.credit_link_sif_i(link_sif_credit_lo)
      ,.credit_link_sif_o(link_sif_credit_li)

      ,.ready_and_link_sif_i(link_sif_i)
      ,.ready_and_link_sif_o(link_sif_o)
      );

   // --------------------------------------------
   // fifo to manycore endpoint standard
   // --------------------------------------------

   bsg_manycore_endpoint_to_fifos 
     #(
       .fifo_width_p     (host_io_pkt_width_p),
       .x_cord_width_p   (x_cord_width_p),
       .y_cord_width_p   (y_cord_width_p),
       .addr_width_p     (addr_width_p),
       .data_width_p     (data_width_p),
       .ep_fifo_els_p    (ep_fifo_els_lp),
       .rev_fifo_els_p   (rev_fifo_els_lp),
       .credit_counter_width_p(credit_counter_width_lp)
       )
   mc_ep_to_fifos
     (
      .clk_i           (clk_i),
      .reset_i         (reset_i),

      // fifo interface
      .mc_req_o        (rx_fifo_req_li),
      .mc_req_v_o      (rx_fifo_req_v_li),
      .mc_req_ready_i  (rx_fifo_req_ready_lo),

      .endpoint_req_i      (tx_ep_req_li),
      .endpoint_req_v_i    (tx_ep_req_v_li),
      .endpoint_req_ready_o(tx_ep_req_ready_lo),

      .mc_rsp_o        (tx_fifo_rsp_li),
      .mc_rsp_v_o      (tx_fifo_rsp_v_li),
      .mc_rsp_ready_i  (tx_fifo_rsp_ready_lo),

      .endpoint_rsp_i      ('0),
      .endpoint_rsp_v_i    (1'b0),
      .endpoint_rsp_ready_o(),

      // manycore link
      .link_sif_i      (link_sif_credit_li),
      .link_sif_o      (link_sif_credit_lo),
      .global_x_i          (global_x_i),
      .global_y_i          (global_y_i),
      .out_credits_used_o   (ep_out_credits_used_lo)
      );

  assign tx_ep_req_li = tx_fifo_req_lo;
  assign tx_ep_req_v_li = tx_fifo_req_v_lo & (ep_out_credits_used_lo < bsg_machine_io_ep_credits_gp);
  assign tx_fifo_req_ready_li = tx_ep_req_ready_lo & (ep_out_credits_used_lo < bsg_machine_io_ep_credits_gp);

endmodule
