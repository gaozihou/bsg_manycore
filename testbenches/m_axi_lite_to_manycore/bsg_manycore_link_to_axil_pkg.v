`ifndef BSG_MANYCORE_LINK_TO_AXIL_PKG_V
`define BSG_MANYCORE_LINK_TO_AXIL_PKG_V

package bsg_manycore_link_to_axil_pkg;

  localparam axil_data_width_gp   = 32 ;
  localparam axil_addr_width_gp   = 32 ;

  localparam axil_resp_OKAY_gp = 2'b00;

  parameter mcl_rom_base_addr_gp   = 32'h0000_0000;
  parameter mcl_fifo_base_addr_gp  = 32'h0000_1000;

  // fifo registers
  //
  parameter mcl_ofs_width_gp    = 8    ;

  parameter mcl_ofs_tdfv_req_gp = 8'h00;
  parameter mcl_ofs_tdr_gp      = 8'h04;

  parameter mcl_ofs_rdr_rsp_gp  = 8'h0C;

  parameter mcl_ofs_rdr_req_gp  = 8'h1C;
  parameter mcl_ofs_rdfo_req_gp = 8'h18;

  parameter mcl_ofs_counter_low_gp   = 32'h1FF0;
  parameter mcl_ofs_counter_high_gp  = 32'h1FF4;
  parameter mcl_ofs_credits_gp  = 32'h2000;

  parameter bsg_machine_rom_width_gp = 32;
  parameter bsg_machine_rom_els_gp = 38;
  parameter bsg_machine_io_ep_credits_gp = 32;

endpackage : bsg_manycore_link_to_axil_pkg

`endif // BSG_MANYCORE_LINK_TO_AXIL_PKG_V
