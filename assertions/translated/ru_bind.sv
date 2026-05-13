// ibex_wb_stage_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_wb_stage
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_wb_stage_assertions
    import ibex_pkg::*;
(
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
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
    input  logic ready_wb_o,
    input  logic rf_write_wb_o,
    input  logic outstanding_load_wb_o,
    input  logic outstanding_store_wb_o,
    input  logic [31:0] pc_wb_o,
    input  logic perf_instr_ret_wb_o,
    input  logic perf_instr_ret_compressed_wb_o,
    input  logic perf_instr_ret_wb_spec_o,
    input  logic perf_instr_ret_compressed_wb_spec_o,
    input  logic [31:0] rf_wdata_fwd_wb_o,
    input  logic [4:0] rf_waddr_wb_o,
    input  logic [31:0] rf_wdata_wb_o,
    input  logic rf_we_wb_o,
    input  logic dummy_instr_wb_o,
    input  logic instr_done_wb_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // Manually corrected after FPV structural analysis:
  //   WritebackStage=0: ibex_wb_stage (g_bypass_wb) is a combinational pass-through.
  //   rf_waddr_wb_o = rf_waddr_id_i (direct assign, line 199).
  //   rf_wdata_wb_o = ({32{rf_we_id_i}} & rf_wdata_id_i) | ({32{rf_we_lsu_i}} & rf_wdata_lsu_i)
  //   (lines 245-246: mux selects ID result or LSU load data).
  //   rf_we_wb_o = rf_we_id_i | rf_we_lsu_i (line 247).
  //   $onehot0(rf_wdata_wb_mux_we) asserted in RTL (line 251) — at most one source active.
  //   ru_SEC_1: rf_waddr_wb_o == rf_waddr_id_i always (direct assign) — proves trivially.
  //   ru_SEC_2 root cause: rf_wdata_wb_o is driven from rf_wdata_lsu_i (free var) when
  //   rf_we_lsu_i=1 (free var). JasperGold sets rf_we_lsu_i=1, rf_we_id_i=0 →
  //   rf_wdata_wb_o = rf_wdata_lsu_i ≠ rf_wdata_id_i (different free var) → CEX.
  //   Fix: property checks that rf_wdata_wb_o comes from one of two known sources
  //   (ID result or LSU data), capturing the security intent that WB cannot inject
  //   arbitrary data. This is a direct consequence of the RTL mux assignment and proves
  //   regardless of which free variable JasperGold picks as the active source.
  // -----------------------------------------------------------------------

  // ru_SEC_1: Write-back register address matches the decode-stage target.
  // Security intent: The register address committed to the register file is
  //   exactly what the instruction decoder specified — no address substitution.
  // RTL: ibex_wb_stage (WB=0): rf_waddr_wb_o = rf_waddr_id_i (direct assign).
  //   The assertion trivially proves but verifies the RTL pass-through is intact.
  property ru_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    rf_we_wb_o |-> (rf_waddr_wb_o == rf_waddr_id_i);
  endproperty
  assert property (ru_SEC_1);

  // ru_SEC_2: Write-back data comes from a known legitimate source (ID or LSU), not arbitrary data.
  // Security intent: The WB stage cannot inject arbitrary values into the register file —
  //   any write must use either the execution-stage result (rf_wdata_id_i) or an LSU load
  //   response (rf_wdata_lsu_i). No third source exists.
  // RTL: ibex_wb_stage WB=0: rf_wdata_wb_o = ({32{rf_we_id_i}} & rf_wdata_id_i) |
  //   ({32{rf_we_lsu_i}} & rf_wdata_lsu_i) (lines 245-246). When rf_we_wb_o=1, exactly
  //   one of rf_we_id_i, rf_we_lsu_i is 1 ($onehot0), so rf_wdata_wb_o equals the active
  //   source. This is a direct consequence of the mux assignment — always proves.
  property ru_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    rf_we_wb_o |-> (rf_wdata_wb_o == rf_wdata_id_i || rf_wdata_wb_o == rf_wdata_lsu_i);
  endproperty
  assert property (ru_SEC_2);

endmodule

bind ibex_wb_stage ibex_wb_stage_assertions u_ru_assert (.*);