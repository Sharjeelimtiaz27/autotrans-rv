// ibex_load_store_unit_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_load_store_unit
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_load_store_unit_assertions (
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
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
    input  logic data_req_o,
    input  logic [31:0] data_addr_o,
    input  logic data_we_o,
    input  logic [3:0] data_be_o,
    input  logic [MemDataWidth-1:0] data_wdata_o,
    input  logic [31:0] lsu_rdata_o,
    input  logic lsu_rdata_valid_o,
    input  logic addr_incr_req_o,
    input  logic [31:0] addr_last_o,
    input  logic lsu_req_done_o,
    input  logic lsu_resp_valid_o,
    input  logic load_err_o,
    input  logic load_resp_intg_err_o,
    input  logic store_err_o,
    input  logic store_resp_intg_err_o,
    input  logic busy_o,
    input  logic perf_load_o,
    input  logic perf_store_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // ma_SEC_1: Store-data correctness
  // Security intent: The value sent to memory for a store is exactly the register value,
  // properly aligned to the byte offset of the target address.
  // Ibex mapping: When a store request is granted (data_gnt_i && lsu_we_i),
  // the data written (data_wdata_o) must match the input data (lsu_wdata_i)
  // shifted according to the byte offset (data_addr_o[1:0]).
  property ma_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (data_gnt_i && lsu_we_i) |-> 
      (data_wdata_o == (lsu_wdata_i << (8 * data_addr_o[1:0])));
  endproperty
  assert property (ma_SEC_1);

  // ma_SEC_2: Load-data correctness
  // Security intent: The value loaded into the register is exactly the value from memory,
  // correctly sign/zero-extended based on the load type.
  // Ibex mapping: When load response is valid (lsu_rdata_valid_o), the output data
  // (lsu_rdata_o) must be correctly extended from the memory data based on type and sign.
  property ma_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    lsu_rdata_valid_o |-> 
      (lsu_rdata_o == (lsu_sign_ext_i ? 
        {{(32-8){data_rdata_i[7]}}, data_rdata_i[7:0]} : // SB sign-extend example
        {{(32-8){1'b0}}, data_rdata_i[7:0]}));           // LBU zero-extend example
  endproperty
  assert property (ma_SEC_2);

  // ma_SEC_3: Address-computation correctness
  // Security intent: The address sent to memory is exactly the effective address
  // computed from GPR values and instruction immediate.
  // Ibex mapping: When a load or store request is made (lsu_req_i),
  // the address output (data_addr_o) must match the ALU result (adder_result_ex_i).
  property ma_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    lsu_req_i |-> (data_addr_o == adder_result_ex_i);
  endproperty
  assert property (ma_SEC_3);

endmodule

bind ibex_load_store_unit ibex_load_store_unit_assertions u_ma_assert (.*);