
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
  ,output logic [ axil_addr_width_p-1:0] io_axi_lite_awaddr
  ,input                               io_axi_lite_awready
  ,output logic                        io_axi_lite_wvalid
  ,output logic [ axil_data_width_p-1:0] io_axi_lite_wdata
  ,output [(axil_data_width_p>>3)-1:0] io_axi_lite_wstrb
  ,input                               io_axi_lite_wready
  ,input  [ 1:0]                       io_axi_lite_bresp
  ,input                               io_axi_lite_bvalid
  ,output                              io_axi_lite_bready
  ,output logic [ axil_addr_width_p-1:0] io_axi_lite_araddr
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

  typedef enum logic [3:0] {
    RESET
   ,REMOTE_LOAD
   ,AR_REMOTE_LOAD
   ,R_REMOTE_LOAD
   ,LOAD_NBF
   ,AR_OCCUPACY
   ,R_OCCUPACY
   ,AR_MC_REQ
   ,R_MC_REQ
  } nbf_state_e;

  logic [67:0] nbf [max_nbf_p-1:0];
  logic [nbf_addr_width_lp-1:0] nbf_addr_r, nbf_addr_n;
  logic [31:0] nbf_counter_r, nbf_counter_n;
  nbf_state_e nbf_state_r, nbf_state_n;
  logic nbf_drain_done_r, nbf_drain_done_n;

  bsg_nbf_s curr_nbf;
  assign curr_nbf = nbf[nbf_addr_r];

  assign io_axi_lite_wstrb  = '1;
  assign io_axi_lite_bready = 1'b1;
  assign io_axi_lite_rready = 1'b1;

  initial begin
    $readmemh("../../../testbenches/m_axi_lite_to_manycore/bsg_manycore_link_to_axil_tester.rom", nbf);
  end

  wire is_read   = (curr_nbf.opcode == 4'h0);
  wire is_write  = (curr_nbf.opcode == 4'h1);
  wire is_finish = (curr_nbf.opcode == 4'hF);

  wire [3:0][31:0] remote_load_buf = {{32'h00000040},{32'h02a90000},{32'h00000004},{32'h00100810}};
 
  always_comb
  begin
    nbf_addr_n = nbf_addr_r;
    nbf_counter_n = nbf_counter_r;
    nbf_state_n = nbf_state_r;
    nbf_drain_done_n = nbf_drain_done_r;
    io_axi_lite_arvalid = 1'b0;
    io_axi_lite_awvalid = 1'b0;
    io_axi_lite_wvalid  = 1'b0;
    io_axi_lite_araddr  = curr_nbf.addr;
    io_axi_lite_awaddr  = curr_nbf.addr;
    io_axi_lite_wdata   = curr_nbf.data;
    if (nbf_state_r == RESET)
      begin
        if (pcie_en_i)
          begin
            nbf_state_n = REMOTE_LOAD;
          end
      end
    else if (nbf_state_r == REMOTE_LOAD)
      begin
        io_axi_lite_awvalid = 1'b1;
        io_axi_lite_wvalid = 1'b1;
        io_axi_lite_awaddr = 16'h1004;
        io_axi_lite_wdata  = remote_load_buf[nbf_counter_r];
        if (io_axi_lite_awready & io_axi_lite_wready)
          begin
            nbf_counter_n = nbf_counter_r + 1;
            if (nbf_counter_r == 3)
              begin
                nbf_counter_n = '0;
                nbf_state_n = AR_REMOTE_LOAD;
              end
          end
      end
    else if (nbf_state_r == AR_REMOTE_LOAD)
      begin
        io_axi_lite_arvalid = 1'b1;
        io_axi_lite_araddr  = 16'h100C;
        if (io_axi_lite_arready)
            nbf_state_n = R_REMOTE_LOAD;
      end
    else if (nbf_state_r == R_REMOTE_LOAD)
      begin
        if (io_axi_lite_rvalid)
          begin
            nbf_counter_n = nbf_counter_r + 1;
            nbf_state_n = AR_REMOTE_LOAD;
            if (nbf_counter_r == 3)
              begin
                nbf_counter_n = '0;
                nbf_state_n = AR_OCCUPACY;
              end
          end
      end
    else if (nbf_state_r == LOAD_NBF)
      begin
        nbf_counter_n = nbf_counter_r + 1'b1;
        if (nbf_counter_r == 127)
          begin
            nbf_counter_n = 0;
            if (is_finish)
              begin
                nbf_state_n = AR_OCCUPACY;
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
    else if (nbf_state_r == AR_OCCUPACY)
      begin
        io_axi_lite_arvalid = 1'b1;
        io_axi_lite_araddr  = 16'h1018;
        if (io_axi_lite_arready)
            nbf_state_n = R_OCCUPACY;
      end
    else if (nbf_state_r == R_OCCUPACY)
      begin
        if (io_axi_lite_rvalid)
          begin
            nbf_counter_n = io_axi_lite_rdata;
            nbf_state_n = AR_MC_REQ;
          end
      end
    else if (nbf_state_r == AR_MC_REQ)
      begin
        if (nbf_counter_r == 0)
          begin
            if (nbf_drain_done_r == 1'b1)
              begin
                nbf_state_n = AR_OCCUPACY;
              end
            else
              begin
                nbf_drain_done_n = 1'b1;
                nbf_state_n = LOAD_NBF;
              end
          end
        else
          begin
            io_axi_lite_arvalid = 1'b1;
            io_axi_lite_araddr  = 16'h101C;
            if (io_axi_lite_arready)
                nbf_state_n = R_MC_REQ;
          end
      end
    else if (nbf_state_r == R_MC_REQ)
      begin
        if (io_axi_lite_rvalid)
          begin
            nbf_counter_n = nbf_counter_r - 1;
            nbf_state_n = AR_MC_REQ;
            if (io_axi_lite_rdata[16+:16] == 16'h3AB4)
              begin
                if (nbf_drain_done_r == 1'b1) $finish;
              end
          end
      end
  end

  always_ff @(posedge pcie_clk_i)
  begin
    if (pcie_reset_i)
      begin
        nbf_addr_r <= '0;
        nbf_counter_r <= '0;
        nbf_state_r <= RESET;
        nbf_drain_done_r <= '0;
      end
    else
      begin
        nbf_addr_r <= nbf_addr_n;
        nbf_counter_r <= nbf_counter_n;
        nbf_state_r <= nbf_state_n;
        nbf_drain_done_r <= nbf_drain_done_n;
      end
  end

endmodule
