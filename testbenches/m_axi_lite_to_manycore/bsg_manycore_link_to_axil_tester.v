
module bsg_manycore_link_to_axil_tester

 #(parameter max_nbf_p = 16384
  ,parameter nbf_addr_width_lp = `BSG_SAFE_CLOG2(max_nbf_p)
  ,parameter axil_addr_width_p = 32
  ,parameter axil_data_width_p = 32
  )

  (input  pcie_clk_i
  ,input  pcie_reset_i
  ,input  pcie_en_i

  ,output logic                        io_axi_lite_awvalid
  ,output [ axil_addr_width_p-1:0]     io_axi_lite_awaddr
  ,input                               io_axi_lite_awready
  ,output logic                        io_axi_lite_wvalid
  ,output [ axil_data_width_p-1:0]     io_axi_lite_wdata
  ,output [(axil_data_width_p>>3)-1:0] io_axi_lite_wstrb
  ,input                               io_axi_lite_wready
  ,input  [ 1:0]                       io_axi_lite_bresp
  ,input                               io_axi_lite_bvalid
  ,output                              io_axi_lite_bready
  ,output [ axil_addr_width_p-1:0]     io_axi_lite_araddr
  ,output logic                        io_axi_lite_arvalid
  ,input                               io_axi_lite_arready
  ,input  [ axil_data_width_p-1:0]     io_axi_lite_rdata
  ,input  [ 1:0]                       io_axi_lite_rresp
  ,input                               io_axi_lite_rvalid
  ,output                              io_axi_lite_rready
  );

  typedef struct packed {
    logic [3:0]  opcode;
    logic [31:0] addr;
    logic [31:0] data;
  } bsg_nbf_s;

  logic [67:0] nbf [max_nbf_p-1:0];
  logic [nbf_addr_width_lp-1:0] nbf_addr_r, nbf_addr_n;
  logic [7:0] nbf_counter_r, nbf_counter_n;

  bsg_nbf_s curr_nbf;
  assign curr_nbf = nbf[nbf_addr_r];

  assign io_axi_lite_awaddr = curr_nbf.addr;
  assign io_axi_lite_araddr = curr_nbf.addr;
  assign io_axi_lite_wdata  = curr_nbf.data;
  assign io_axi_lite_wstrb  = '1;
  assign io_axi_lite_bready = 1'b1;
  assign io_axi_lite_rready = 1'b1;

  initial begin
    $readmemh("../../../testbenches/m_axi_lite_to_manycore/bsg_manycore_link_to_axil_tester.nbf", nbf);
  end

  wire is_read   = (curr_nbf.opcode == 4'h0);
  wire is_write  = (curr_nbf.opcode == 4'h1);
  wire is_finish = (curr_nbf.opcode == 4'hF);
 
  always_comb
  begin
    nbf_addr_n = nbf_addr_r;
    nbf_counter_n = nbf_counter_r + pcie_en_i;
    io_axi_lite_arvalid = 1'b0;
    io_axi_lite_awvalid = 1'b0;
    io_axi_lite_wvalid  = 1'b0;
    if (nbf_counter_r == 127)
      begin
        nbf_counter_n = '0;
        if (is_finish)
          begin 
            // do nothing
          end
        else if (is_read)
          begin
            io_axi_lite_arvalid = 1'b1;
            if (io_axi_lite_arready)
                nbf_addr_n = nbf_addr_r + 1;
          end
        else if (is_write)
          begin
            io_axi_lite_awvalid = 1'b1;
            io_axi_lite_wvalid = 1'b1;
            if (io_axi_lite_awready & io_axi_lite_wready)
                nbf_addr_n = nbf_addr_r + 1;
          end
      end
  end

  always_ff @(posedge pcie_clk_i)
  begin
    if (pcie_reset_i)
      begin
        nbf_addr_r <= '0;
        nbf_counter_r <= '0;
      end
    else
      begin
        nbf_addr_r <= nbf_addr_n;
        nbf_counter_r <= nbf_counter_n;
      end
  end

endmodule
