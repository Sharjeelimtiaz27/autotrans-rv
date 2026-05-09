// ibex_wb_stage_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_wb_stage
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_wb_stage_assertions (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,
    // --- ports matching DUT (copy from signals.json) ---
        input  logic en_wb_i,
    input  ibex_pkg::wb_instr_type_e instr_type_wb_i,
    input  logic [31:0] pc_id_i,
    input  logic instr_is_compressed_id_i,
    input  logic instr_perf_count_id_i,
    input  logic [4:0] rf_waddr_id_i,
    input  logic [31:0] rf_wdata_id_i,
    input  logic rf_we_id_i,
    input  logic dummy_instr_id_i,
    input  logic [31:0] rf_wdata_lsu_i,
    input  logic rf_we_lsu_i,
    input  logic lsu_resp_valid_i,
    input  logic lsu_resp_err_i,
    output logic ready_wb_o,
    output logic rf_write_wb_o,
    output logic outstanding_load_wb_o,
    output logic outstanding_store_wb_o,
    output logic [31:0] pc_wb_o,
    output logic perf_instr_ret_wb_o,
    output logic perf_instr_ret_compressed_wb_o,
    output logic perf_instr_ret_wb_spec_o,
    output logic perf_instr_ret_compressed_wb_spec_o,
    output logic [31:0] rf_wdata_fwd_wb_o,
    output logic [4:0] rf_waddr_wb_o,
    output logic [31:0] rf_wdata_wb_o,
    output logic rf_we_wb_o,
    output logic dummy_instr_wb_o,
    output logic instr_done_wb_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // ru_SEC_1: Target register correctness on write-back
  // When write-back occurs (rf_we_wb_o asserted), the write address must match
  // the target register specified in the ID stage (rf_waddr_id_i)
  property ru_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    rf_we_wb_o |-> (rf_waddr_wb_o == rf_waddr_id_i);
  endproperty
  assert property (ru_SEC_1);

endmodule

bind ibex_wb_stage ibex_wb_stage_assertions u_ru_assert (.*);