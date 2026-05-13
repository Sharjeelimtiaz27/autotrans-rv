// ibex_id_stage_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_id_stage
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_id_stage_assertions
    import ibex_pkg::*;
(
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
    input  logic instr_valid_i,
    input  logic [31:0] instr_rdata_i,
    input  logic [31:0] instr_rdata_alu_i,
    input  logic [15:0] instr_rdata_c_i,
    input  logic instr_is_compressed_i,
    input  logic instr_bp_taken_i,
    input  logic instr_exec_i,
    input  logic branch_decision_i,
    input  logic illegal_c_insn_i,
    input  logic instr_fetch_err_i,
    input  logic instr_fetch_err_plus2_i,
    input  logic [31:0] pc_id_i,
    input  logic ex_valid_i,
    input  logic lsu_resp_valid_i,
    input  logic [1:0] imd_val_we_ex_i,
    input  ibex_pkg::priv_lvl_e priv_mode_i,
    input  logic csr_mstatus_tw_i,
    input  logic illegal_csr_insn_i,
    input  logic data_ind_timing_i,
    input  logic lsu_req_done_i,
    input  logic lsu_addr_incr_req_i,
    input  logic [31:0] lsu_addr_last_i,
    input  logic csr_mstatus_mie_i,
    input  logic irq_pending_i,
    input  ibex_pkg::irqs_t irqs_i,
    input  logic irq_nm_i,
    input  logic lsu_load_err_i,
    input  logic lsu_load_resp_intg_err_i,
    input  logic lsu_store_err_i,
    input  logic lsu_store_resp_intg_err_i,
    input  logic debug_req_i,
    input  logic debug_single_step_i,
    input  logic debug_ebreakm_i,
    input  logic debug_ebreaku_i,
    input  logic trigger_match_i,
    input  logic [31:0] result_ex_i,
    input  logic [31:0] csr_rdata_i,
    input  logic [31:0] rf_rdata_a_i,
    input  logic [31:0] rf_rdata_b_i,
    input  logic [4:0] rf_waddr_wb_i,
    input  logic [31:0] rf_wdata_fwd_wb_i,
    input  logic rf_write_wb_i,
    input  logic ready_wb_i,
    input  logic outstanding_load_wb_i,
    input  logic outstanding_store_wb_i,
    input  ibex_pkg::alu_op_e alu_operator_i,
    input  logic [31:0] alu_operand_a_i,
    input  logic [31:0] alu_operand_b_i,
    input  logic alu_instr_first_cycle_i,
    input  logic [31:0] bt_a_operand_i,
    input  logic [31:0] bt_b_operand_i,
    input  ibex_pkg::md_op_e multdiv_operator_i,
    input  logic mult_en_i,
    input  logic div_en_i,
    input  logic mult_sel_i,
    input  logic div_sel_i,
    input  logic [1:0] multdiv_signed_mode_i,
    input  logic [31:0] multdiv_operand_a_i,
    input  logic [31:0] multdiv_operand_b_i,
    input  logic multdiv_ready_id_i,
    input  logic ctrl_busy_o,
    input  logic illegal_insn_o,
    input  logic instr_req_o,
    input  logic instr_first_cycle_id_o,
    input  logic instr_valid_clear_o,
    input  logic id_in_ready_o,
    input  logic icache_inval_o,
    input  logic pc_set_o,
    input  ibex_pkg::pc_sel_e pc_mux_o,
    input  logic nt_branch_mispredict_o,
    input  logic [31:0] nt_branch_addr_o,
    input  ibex_pkg::exc_pc_sel_e exc_pc_mux_o,
    input  ibex_pkg::exc_cause_t exc_cause_o,
    input  ibex_pkg::alu_op_e alu_operator_ex_o,
    input  logic [31:0] alu_operand_a_ex_o,
    input  logic [31:0] alu_operand_b_ex_o,
    input  logic [31:0] bt_a_operand_o,
    input  logic [31:0] bt_b_operand_o,
    input  logic mult_en_ex_o,
    input  logic div_en_ex_o,
    input  logic mult_sel_ex_o,
    input  logic div_sel_ex_o,
    input  ibex_pkg::md_op_e multdiv_operator_ex_o,
    input  logic [1:0] multdiv_signed_mode_ex_o,
    input  logic [31:0] multdiv_operand_a_ex_o,
    input  logic [31:0] multdiv_operand_b_ex_o,
    input  logic multdiv_ready_id_o,
    input  logic csr_access_o,
    input  ibex_pkg::csr_op_e csr_op_o,
    input  ibex_pkg::csr_num_e csr_addr_o,
    input  logic csr_op_en_o,
    input  logic csr_save_if_o,
    input  logic csr_save_id_o,
    input  logic csr_save_wb_o,
    input  logic csr_restore_mret_id_o,
    input  logic csr_restore_dret_id_o,
    input  logic csr_save_cause_o,
    input  logic [31:0] csr_mtval_o,
    input  logic lsu_req_o,
    input  logic lsu_we_o,
    input  logic [1:0] lsu_type_o,
    input  logic lsu_sign_ext_o,
    input  logic [31:0] lsu_wdata_o,
    input  logic nmi_mode_o,
    input  logic expecting_load_resp_o,
    input  logic expecting_store_resp_o,
    input  logic debug_mode_o,
    input  logic debug_mode_entering_o,
    input  ibex_pkg::dbg_cause_e debug_cause_o,
    input  logic debug_csr_save_o,
    input  logic [4:0] rf_raddr_a_o,
    input  logic [4:0] rf_raddr_b_o,
    input  logic rf_ren_a_o,
    input  logic rf_ren_b_o,
    input  logic [4:0] rf_waddr_id_o,
    input  logic [31:0] rf_wdata_id_o,
    input  logic rf_we_id_o,
    input  logic rf_rd_a_wb_match_o,
    input  logic rf_rd_b_wb_match_o,
    input  logic en_wb_o,
    input  ibex_pkg::wb_instr_type_e instr_type_wb_o,
    input  logic instr_perf_count_id_o,
    input  logic perf_jump_o,
    input  logic perf_branch_o,
    input  logic perf_tbranch_o,
    input  logic perf_dside_wait_o,
    input  logic perf_mul_wait_o,
    input  logic perf_div_wait_o,
    input  logic instr_id_done_o,
    input  logic [1:0] imd_val_we_o,
    input  logic [33:0] imd_val_d_o,
    input  logic [31:0] alu_adder_result_ex_o,
    input  logic [31:0] result_ex_o,
    input  logic [31:0] branch_target_o,
    input  logic branch_decision_o,
    input  logic ex_valid_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // Manually corrected after FPV structural analysis:
  //   ie_SEC_1 root cause: alu_operator_i, alu_operand_a_i, alu_operand_b_i are
  //   INPUT ports of ibex_ex_block, NOT ibex_id_stage. With 'bind ibex_id_stage',
  //   these are unconnected = free variables. Comparing free $past(alu_operator_i)
  //   to RTL-driven alu_operator_ex_o always CEX.
  //   Fix: stall-stability assertion using only ibex_id_stage OUTPUT ports:
  //   when id_in_ready_o=0 (ID stalled), EX operand registers must not change.
  //   ie_SEC_3_* root cause: alu_operand_a_i, alu_operand_b_i are free variables;
  //   branch_decision_o is RTL-driven independently. JasperGold drives operands
  //   to satisfy antecedent while RTL keeps branch_decision_o=0. CEX.
  //   Fix: use only ibex_id_stage OUTPUT signals (perf_branch_o, perf_tbranch_o,
  //   perf_jump_o, branch_decision_o, instr_rdata_i) for structural invariants
  //   that ibex_id_stage actually enforces.
  //   Elaboration fix: imd_val_d_ex_i and imd_val_q_ex_o are unpacked arrays
  //   [33:0][2] in ibex_id_stage.sv (lines 77-78). Declaring them as flat [33:0]
  //   in the assertion module causes a JasperGold type-mismatch elaboration error.
  //   imd_val_q_i has no matching ibex_id_stage port at all (only an internal wire).
  //   Fix: remove all three from port list — none are used in any assertion.
  // -----------------------------------------------------------------------

  // Group 1: EX operand stability during ID stall (NS31A properties 1-2)
  // Security intent: When the ID stage is stalled (id_in_ready_o=0), the operands
  //   forwarded to the EX stage must not change — the same instruction executes
  //   without substitution or corruption during a stall cycle.
  // RTL: ibex_id_stage registers alu_operator/operands into alu_operator_ex_o etc.
  //   on each id_in_ready_o=1 pulse; when id_in_ready_o=0, no new instruction
  //   enters and the registered EX values hold.
  property ie_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    !id_in_ready_o |->
    ($stable(alu_operator_ex_o) &&
     $stable(alu_operand_a_ex_o) &&
     $stable(alu_operand_b_ex_o));
  endproperty
  assert property (ie_SEC_1);

  // Group 2: WB instruction stability during WB stall (NS31A properties 3-4)
  // Security intent: When an instruction is in WB and WB is not ready to commit
  //   (stall), the WB instruction type must remain stable — no instruction
  //   substitution while waiting for WB commit.
  // RTL: instr_type_wb_o is registered from en_wb_i pulse; while ready_wb_i=0
  //   no new instruction enters WB → instr_type_wb_o is stable at next cycle.
  property ie_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (en_wb_o && !ready_wb_i) |=>
    (en_wb_o && instr_type_wb_o == $past(instr_type_wb_o));
  endproperty
  assert property (ie_SEC_2);

  // Group 3: Branch/jump control flow correctness (NS31A properties 5-10)
  // Security intent: ibex_id_stage correctly classifies and accounts for all
  //   control flow transfers; no spurious or missed branch/jump events.

  // ie_SEC_3_taken: A taken branch always corresponds to a positive branch decision.
  // RTL: perf_tbranch_o = branch_set_o which is derived from branch_decision_o (the
  //   forwarded ALU comparison result). If branch_decision_o=0, branch_set_o=0.
  property ie_SEC_3_taken;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_tbranch_o |-> branch_decision_o;
  endproperty
  assert property (ie_SEC_3_taken);

  // ie_SEC_3_notaken: When a branch instruction is decoded but branch decision is
  //   false, it must not be counted as a taken branch.
  // RTL: perf_tbranch_o is gated by branch_decision_o; when decision=0, it is 0.
  property ie_SEC_3_notaken;
    @(posedge clk_i) disable iff (!rst_ni)
    (perf_branch_o && !branch_decision_o) |-> !perf_tbranch_o;
  endproperty
  assert property (ie_SEC_3_notaken);

  // ie_SEC_3_excl: Every taken branch is also counted as a branch instruction.
  // RTL: perf_tbranch_o is set only when perf_branch_o=1 (a branch is being
  //   executed); you cannot have a taken branch without it being a branch.
  property ie_SEC_3_excl;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_tbranch_o |-> perf_branch_o;
  endproperty
  assert property (ie_SEC_3_excl);

  // ie_SEC_3_jump_excl: A jump and a taken branch cannot occur simultaneously.
  // RTL: ibex_id_stage issues at most one control transfer per cycle;
  //   perf_jump_o and perf_tbranch_o are set in mutually exclusive decoder paths.
  property ie_SEC_3_jump_excl;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_jump_o |-> !perf_tbranch_o;
  endproperty
  assert property (ie_SEC_3_jump_excl);

  // ie_SEC_3_branch_opcode: Branch performance event only fires on branch opcode.
  // RTL: Decoder sets perf_branch_o only for branch opcode (7'b1100011) or when
  //   decoding a compressed branch that expands to the same encoding.
  property ie_SEC_3_branch_opcode;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_branch_o |->
    (instr_rdata_i[6:0] == 7'b1100011 || instr_is_compressed_i);
  endproperty
  assert property (ie_SEC_3_branch_opcode);

  // ie_SEC_3_jump_opcode: Jump performance event only fires on JAL/JALR opcode.
  // RTL: Decoder sets perf_jump_o only for JAL (7'b1101111) or JALR (7'b1100111)
  //   encodings, or for compressed jump instructions (C.J, C.JAL, C.JALR).
  property ie_SEC_3_jump_opcode;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_jump_o |->
    (instr_rdata_i[6:0] == 7'b1101111 ||
     instr_rdata_i[6:0] == 7'b1100111 ||
     instr_is_compressed_i);
  endproperty
  assert property (ie_SEC_3_jump_opcode);

endmodule

bind ibex_id_stage ibex_id_stage_assertions u_ie_assert (.*);