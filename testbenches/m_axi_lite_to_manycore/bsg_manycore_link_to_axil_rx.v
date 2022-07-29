
/*
 *  bsg_manycore_link_to_axil_rx.v
 *
 */

`include "bsg_defines.v"

module bsg_manycore_link_to_axil_rx

  import bsg_manycore_link_to_axil_pkg::*;

 #(parameter axil_data_width_p = "inv"

  ,localparam ratio_lp = host_fifo_width_gp/axil_data_width_p
  ,localparam req_credits_width_lp = `BSG_WIDTH(ratio_lp*rx_req_credits_gp)
  )

  (input                          clk_i
  ,input                          reset_i

  ,output [axil_data_width_p-1:0] axil_req_o
  ,output                         axil_req_v_o
  ,input                          axil_req_ready_i

  ,input  [host_fifo_width_gp-1:0]      fifo_req_i
  ,input                          fifo_req_v_i
  ,output                         fifo_req_ready_o

  ,output [req_credits_width_lp-1:0] req_credits_o
  );

  logic req_piso_v_lo, req_piso_ready_li;
  logic [axil_data_width_p-1:0] req_piso_data_lo;

  bsg_parallel_in_serial_out
 #(.width_p    (axil_data_width_p)
  ,.els_p      (ratio_lp)
  ) req_piso
  (.clk_i      (clk_i)
  ,.reset_i    (reset_i)
  ,.valid_i    (fifo_req_v_i)
  ,.data_i     (fifo_req_i)
  ,.ready_and_o(fifo_req_ready_o)
  ,.valid_o    (req_piso_v_lo)
  ,.data_o     (req_piso_data_lo)
  ,.yumi_i     (req_piso_v_lo & req_piso_ready_li)
  );

  bsg_fifo_1r1w_small
 #(.width_p(axil_data_width_p)
  ,.els_p  (ratio_lp*rx_req_credits_gp)
  ) req_buf
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (req_piso_v_lo)
  ,.data_i (req_piso_data_lo)
  ,.ready_o(req_piso_ready_li)
  ,.v_o    (axil_req_v_o)
  ,.data_o (axil_req_o)
  ,.yumi_i (axil_req_v_o & axil_req_ready_i)
  );

  bsg_flow_counter
 #(.els_p       (ratio_lp*rx_req_credits_gp)
  ,.count_free_p(0)
  ) req_cnt
  (.clk_i       (clk_i)
  ,.reset_i     (reset_i)
  ,.v_i         (req_piso_v_lo)
  ,.ready_i     (req_piso_ready_li)
  ,.yumi_i      (axil_req_v_o & axil_req_ready_i)
  ,.count_o     (req_credits_o)
  );

endmodule