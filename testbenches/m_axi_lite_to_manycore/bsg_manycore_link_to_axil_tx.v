
/*
 *  bsg_manycore_link_to_axil_tx.v
 *
 */

`include "bsg_defines.v"

module bsg_manycore_link_to_axil_tx

  import bsg_manycore_pkg::*;
  import bsg_manycore_link_to_axil_pkg::*;

 #(parameter x_cord_width_p    = "inv"
  ,parameter y_cord_width_p    = "inv"
  ,parameter addr_width_p      = "inv"
  ,parameter data_width_p      = "inv"
  ,parameter axil_data_width_p = "inv"

  ,localparam x_cord_width_pad_lp = `BSG_CDIV(x_cord_width_p,8)*8
  ,localparam y_cord_width_pad_lp = `BSG_CDIV(y_cord_width_p,8)*8
  ,localparam addr_width_pad_lp   = `BSG_CDIV(addr_width_p,8)*8
  ,localparam data_width_pad_lp   = `BSG_CDIV(data_width_p,8)*8

  ,localparam ratio_lp = host_fifo_width_gp/axil_data_width_p
  ,localparam req_credits_width_lp  = `BSG_WIDTH(ratio_lp*tx_req_credits_gp)
  ,localparam read_credits_width_lp = `BSG_WIDTH(tx_read_credits_gp)
  )

  (input                          clk_i
  ,input                          reset_i

  ,input  [axil_data_width_p-1:0] axil_req_i
  ,input                          axil_req_v_i
  ,output                         axil_req_ready_o

  ,output [axil_data_width_p-1:0] axil_rsp_o
  ,output                         axil_rsp_v_o
  ,input                          axil_rsp_ready_i

  ,output [host_fifo_width_gp-1:0]      fifo_req_o
  ,output                         fifo_req_v_o
  ,input                          fifo_req_ready_i

  ,input  [host_fifo_width_gp-1:0]      fifo_rsp_i
  ,input                          fifo_rsp_v_i
  ,output                         fifo_rsp_ready_o

  ,output [req_credits_width_lp-1:0] req_credits_o
  );

  // --------------------------------------------------------
  //                          req
  // --------------------------------------------------------

  logic req_sipo_v_li, req_sipo_ready_lo;
  logic [axil_data_width_p-1:0] req_sipo_data_li;

  logic req_sipo_v_lo, req_sipo_ready_li;
  logic [host_fifo_width_gp-1:0] req_sipo_data_lo;

  bsg_fifo_1r1w_small
 #(.width_p(axil_data_width_p)
  ,.els_p  (ratio_lp*tx_req_credits_gp)
  ) req_buf
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (axil_req_v_i)
  ,.data_i (axil_req_i)
  ,.ready_o(axil_req_ready_o)
  ,.v_o    (req_sipo_v_li)
  ,.data_o (req_sipo_data_li)
  ,.yumi_i (req_sipo_v_li & req_sipo_ready_lo)
  );

  bsg_serial_in_parallel_out_full
 #(.width_p(axil_data_width_p)
  ,.els_p  (ratio_lp)
  ) req_sipo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (req_sipo_v_li)
  ,.data_i (req_sipo_data_li)
  ,.ready_o(req_sipo_ready_lo)
  ,.v_o    (req_sipo_v_lo)
  ,.data_o (req_sipo_data_lo)
  ,.yumi_i (req_sipo_v_lo & req_sipo_ready_li)
  );

  // --------------------------------------------------------
  //                          rsp
  // --------------------------------------------------------

  logic rsp_piso_v_li, rsp_piso_ready_lo;
  logic [host_fifo_width_gp-1:0] rsp_piso_data_li;

  bsg_fifo_1r1w_small
 #(.width_p(host_fifo_width_gp)
  ,.els_p  (tx_read_credits_gp)
  ) rsp_buf
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (fifo_rsp_v_i)
  ,.data_i (fifo_rsp_i)
  ,.ready_o(fifo_rsp_ready_o)
  ,.v_o    (rsp_piso_v_li)
  ,.data_o (rsp_piso_data_li)
  ,.yumi_i (rsp_piso_v_li & rsp_piso_ready_lo)
  );

  bsg_parallel_in_serial_out
 #(.width_p    (axil_data_width_p)
  ,.els_p      (ratio_lp)
  ) rsp_piso
  (.clk_i      (clk_i)
  ,.reset_i    (reset_i)
  ,.valid_i    (rsp_piso_v_li)
  ,.data_i     (rsp_piso_data_li)
  ,.ready_and_o(rsp_piso_ready_lo)
  ,.valid_o    (axil_rsp_v_o)
  ,.data_o     (axil_rsp_o)
  ,.yumi_i     (axil_rsp_ready_i)
  );

  // --------------------------------------------------------
  //                      Flow Control
  // --------------------------------------------------------

  // Host will read this vacancy and update its request credits

  bsg_flow_counter
 #(.els_p       (ratio_lp*tx_req_credits_gp)
  ,.count_free_p(1)
  ) req_cnt
  (.clk_i       (clk_i)
  ,.reset_i     (reset_i)
  ,.v_i         (axil_req_v_i)
  ,.ready_i     (axil_req_ready_o)
  ,.yumi_i      (req_sipo_v_li & req_sipo_ready_lo)
  ,.count_o     (req_credits_o)
  );

  // pause the host request if:
  // 1) endpoint is out of credits (this is implemented outside)
  // 2) this module is out of read credits

  `declare_bsg_manycore_packet_aligned_s(host_fifo_width_gp, addr_width_pad_lp, data_width_pad_lp, x_cord_width_pad_lp, y_cord_width_pad_lp);
  bsg_manycore_packet_aligned_s req_sipo_data_cast;
  assign req_sipo_data_cast = req_sipo_data_lo;

  logic [read_credits_width_lp-1:0] read_credits_lo;

  wire is_read_req = req_sipo_data_cast.op_v2 == 8'(e_remote_load);
  wire pause_read_req = is_read_req && (read_credits_lo == 0);

  assign fifo_req_o = req_sipo_data_lo;
  assign fifo_req_v_o = ~pause_read_req & req_sipo_v_lo;
  assign req_sipo_ready_li = ~pause_read_req & fifo_req_ready_i;

  bsg_flow_counter
 #(.els_p       (tx_read_credits_gp)
  ,.count_free_p(1)
  ) read_cnt
  (.clk_i       (clk_i)
  ,.reset_i     (reset_i)
  ,.v_i         (is_read_req & req_sipo_v_lo)
  ,.ready_i     (req_sipo_ready_li)
  ,.yumi_i      (rsp_piso_v_li & rsp_piso_ready_lo)
  ,.count_o     (read_credits_lo)
  );

endmodule
