// ibex_load_store_unit_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_load_store_unit
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_load_store_unit_assertions (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,
    // --- ports matching DUT (copy from signals.json) ---
    input  logic data_gnt_i,
    input  logic data_rvalid_i,
    input  logic data_bus_err_i,
    input  logic data_pmp_err_i,
    input  logic [MemDataWidth-1:0] data_rdata_i,
    input  logic lsu_we_i,
    input  logic [1:0] lsu_type_i,
    input  logic [31:0] lsu_wdata_i,
    input  logic lsu_sign_ext_i,
    input  logic lsu_req_i,
    input  logic [31:0] adder_result_ex_i,
    output logic data_req_o,
    output logic [31:0] data_addr_o,
    output logic data_we_o,
    output logic [3:0] data_be_o,
    output logic [MemDataWidth-1:0] data_wdata_o,
    output logic [31:0] lsu_rdata_o,
    output logic lsu_rdata_valid_o,
    output logic addr_incr_req_o,
    output logic [31:0] addr_last_o,
    output logic lsu_req_done_o,
    output logic lsu_resp_valid_o,
    output logic load_err_o,
    output logic load_resp_intg_err_o,
    output logic store_err_o,
    output logic store_resp_intg_err_o,
    output logic busy_o,
    output logic perf_load_o,
    output logic perf_store_o
);

  // Internal signals needed for assertions
  logic [1:0] data_offset;
  logic [31:0] data_addr;
  logic [3:0] data_be;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata_ext;
  logic [31:0] rdata_w_ext;
  logic [31:0] rdata_h_ext;
  logic [31:0] rdata_b_ext;
  logic [1:0] data_type_q;
  logic data_sign_ext_q;
  logic [1:0] rdata_offset_q;
  logic [23:0] rdata_q;
  logic split_misaligned_access;
  logic [1:0] ecc_err;
  logic [MemDataWidth-1:0] data_rdata_buf;

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // ma_SEC_1: Store-data correctness for word stores at offset 0
  // When a word store is requested with offset 0, the write data matches the input data
  property ma_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b10 && data_offset == 2'b00) |-> 
    (data_wdata_o[31:0] == lsu_wdata_i[31:0]);
  endproperty
  assert property (ma_SEC_1);

  // ma_SEC_2: Store-data correctness for halfword stores at offset 0
  // When a halfword store is requested with offset 0, the write data matches the lower 16 bits
  property ma_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b01 && data_offset == 2'b00) |-> 
    (data_wdata_o[15:0] == lsu_wdata_i[15:0] && data_wdata_o[31:16] == 16'h0000);
  endproperty
  assert property (ma_SEC_2);

  // ma_SEC_3: Store-data correctness for byte stores at offset 0
  // When a byte store is requested with offset 0, the write data matches the lower 8 bits
  property ma_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b00 && data_offset == 2'b00) |-> 
    (data_wdata_o[7:0] == lsu_wdata_i[7:0] && data_wdata_o[31:8] == 24'h000000);
  endproperty
  assert property (ma_SEC_3);

  // ma_SEC_4: Store-data correctness for halfword stores at offset 1
  // When a halfword store is requested with offset 1, the write data matches the lower 16 bits shifted
  property ma_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b01 && data_offset == 2'b01) |-> 
    (data_wdata_o[23:8] == lsu_wdata_i[15:0] && data_wdata_o[7:0] == 8'h00 && data_wdata_o[31:24] == 8'h00);
  endproperty
  assert property (ma_SEC_4);

  // ma_SEC_5: Store-data correctness for byte stores at offset 1
  // When a byte store is requested with offset 1, the write data matches the lower 8 bits shifted
  property ma_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b00 && data_offset == 2'b01) |-> 
    (data_wdata_o[15:8] == lsu_wdata_i[7:0] && data_wdata_o[7:0] == 8'h00 && data_wdata_o[31:16] == 16'h0000);
  endproperty
  assert property (ma_SEC_5);

  // ma_SEC_6: Store-data correctness for byte stores at offset 2
  // When a byte store is requested with offset 2, the write data matches the lower 8 bits shifted
  property ma_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i && lsu_we_i && lsu_type_i == 2'b00 && data_offset == 2'b10) |-> 
    (data_wdata_o[23:16] == lsu_wdata_i[7:0] && data_wdata_o[15:0] == 16'h0000 && data_wdata_o[31:24] == 8'h00);
  endproperty
  assert property (ma_SEC_6);

  // ma_SEC_7: Load-data correctness for word loads
  // When a word load completes, the returned data matches the memory data
  property ma_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_resp_valid_o && !lsu_we_i && data_type_q == 2'b10) |-> 
    (lsu_rdata_o == data_rdata_ext);
  endproperty
  assert property (ma_SEC_7);

  // ma_SEC_8: Load-data correctness for halfword loads (sign-extended)
  // When a signed halfword load completes, the returned data is sign-extended from 16 bits
  property ma_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_resp_valid_o && !lsu_we_i && data_type_q == 2'b01 && data_sign_ext_q) |-> 
    (lsu_rdata_o == rdata_h_ext);
  endproperty
  assert property (ma_SEC_8);

  // ma_SEC_9: Load-data correctness for byte loads (sign-extended)
  // When a signed byte load completes, the returned data is sign-extended from 8 bits
  property ma_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_resp_valid_o && !lsu_we_i && data_type_q == 2'b00 && data_sign_ext_q) |-> 
    (lsu_rdata_o == rdata_b_ext);
  endproperty
  assert property (ma_SEC_9);

  // ma_SEC_10: Load-data correctness for halfword loads (unsigned)
  // When an unsigned halfword load completes, the returned data is zero-extended from 16 bits
  property ma_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_resp_valid_o && !lsu_we_i && data_type_q == 2'b01 && !data_sign_ext_q) |-> 
    (lsu_rdata_o == rdata_w_ext);
  endproperty
  assert property (ma_SEC_10);

  // ma_SEC_11: Load-data correctness for byte loads (unsigned)
  // When an unsigned byte load completes, the returned data is zero-extended from 8 bits
  property ma_SEC_11;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_resp_valid_o && !lsu_we_i && data_type_q == 2'b00 && !data_sign_ext_q) |-> 
    (lsu_rdata_o == rdata_w_ext);
  endproperty
  assert property (ma_SEC_11);

  // ma_SEC_12: Address computation correctness
  // The address sent to memory matches the computed effective address
  property ma_SEC_12;
    @(posedge clk_i) disable iff (!rst_ni)
    (lsu_req_i) |-> 
    (data_addr_o == adder_result_ex_i);
  endproperty
  assert property (ma_SEC_12);

endmodule

bind ibex_load_store_unit ibex_load_store_unit_assertions u_ma_assert (.*);