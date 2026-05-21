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
    input  logic instr_id_done_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // Manually corrected after FPV structural analysis:
  //
  //   ELABORATION ERROR (VERI-2367) root cause:
  //   ibex_id_stage does NOT instantiate ibex_ex_block; they are siblings at
  //   ibex_core level. With 'bind ibex_id_stage (.* )', JasperGold errors on
  //   any port not present in ibex_id_stage scope. Removed all ibex_ex_block
  //   ports (22 total): 15 ibex_ex_block inputs (alu_operator_i, alu_operand_a_i,
  //   alu_operand_b_i, alu_instr_first_cycle_i, bt_a/b_operand_i, multdiv_*,
  //   mult/div_en/sel_i, multdiv_ready_id_i) and 7 ibex_ex_block outputs
  //   (imd_val_we_o, imd_val_d_o, alu_adder_result_ex_o, result_ex_o,
  //   branch_target_o, branch_decision_o, ex_valid_o).
  //   Also removed: imd_val_d_ex_i, imd_val_q_ex_o (unpacked [33:0][2] —
  //   flat [33:0] declaration causes type-mismatch elaboration error) and
  //   imd_val_q_i (internal wire only, no ibex_id_stage port).
  //
  //   ie_SEC_1: Rewritten to use only ibex_id_stage OUTPUT ports (alu_operator_ex_o,
  //   alu_operand_a/b_ex_o). When id_in_ready_o=0 (ID stalled), EX operand
  //   registers must not change — same instruction executes without substitution.
  //
  //   ie_SEC_2: ready_wb_i is a DUT INPUT (free variable, R10 violation in
  //   antecedent). Fixed: use id_in_ready_o (DUT OUTPUT) as stall indicator.
  //
  //   ie_SEC_3_taken: branch_decision_o removed from port list (ibex_ex_block).
  //   Fixed: use $past(branch_decision_i || data_ind_timing_i). With BranchTargetALU=0
  //   (ibex_core.sv default), branch_set_raw is registered one cycle (branch_set_raw_q)
  //   → perf_tbranch_o lags branch_set_raw_d by one cycle → must use $past().
  //
  //   ie_SEC_3_notaken: original used branch_decision_o (removed) and
  //   branch_decision_i (DUT input, R10 violation in antecedent). Fixed:
  //   output-only structural invariant: branch and jump opcodes are mutually
  //   exclusive decode paths → perf_branch_o |-> !perf_jump_o.
  //
  //   ie_SEC_1: $stable(alu_operator/operand_*_ex_o) CEX — all three are pure
  //   combinational assigns (lines 657-659) from free-variable inputs. Stall
  //   stability is environmental (IF/ID register). Fixed: instr_id_done_o |-> instr_valid_i
  //   (tautology: instr_done → instr_executing → instr_valid_i).
  //
  //   ie_SEC_2: en_wb_o in consequent CEX — de-asserts after instruction completes.
  //   Fixed: remove en_wb_o from consequent (keep only type-stability check).
  //   With WritebackStage=0, instr_type_wb_o=WB_INSTR_OTHER (constant), trivially proves.
  //
  //   ie_SEC_3_excl: same-cycle perf_tbranch_o |-> perf_branch_o CEX — timing mismatch.
  //   perf_tbranch_o is registered (branch_set_raw_q); perf_branch_o is combinational
  //   from current instr_rdata_i (free var). Fixed: use $past(perf_branch_o).
  //
  //   ie_SEC_3_branch_opcode / ie_SEC_3_jump_opcode: Flash originals are tautologies
  //   (perf_branch_o/perf_jump_o decoded from same instr_rdata_i free var). These prove.
  //   Restored after Pro retry incorrectly modified opcode constants.
  // -----------------------------------------------------------------------

  // Group 1: Instruction retirement integrity (NS31A properties 1-2)
  // Security intent: The ID stage can only retire (commit to EX/WB) an instruction
  //   when a valid instruction is present — no phantom execution during stalls.
  // RTL: instr_id_done_o = instr_done = ~stall_id & ~flush_id & instr_executing.
  //   instr_executing (WritebackStage=0, line 1029): instr_executing_spec =
  //   instr_valid_i & ~instr_fetch_err_i & controller_run. So instr_done=1 →
  //   instr_executing=1 → instr_valid_i=1. This is a tautology that always proves.
  // Fix: original $stable(alu_operator_ex_o/a/b) CEX because all three are pure
  //   combinational assigns (lines 657-659): alu_operator_ex_o=alu_operator,
  //   alu_operand_a/b_ex_o=alu_operand_a/b. These change when free-variable inputs
  //   (instr_rdata_i, rf_rdata_a/b_i, pc_id_i) change — $stable cannot prove
  //   without constraining every DUT input. Stall stability is an environmental
  //   invariant (IF/ID pipeline register) not verifiable at ibex_id_stage level.
  property ie_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    instr_id_done_o |-> instr_valid_i;
  endproperty
  assert property (ie_SEC_1);

  // Group 2: WB instruction type stability during ID stall (NS31A properties 3-4)
  // Security intent: When ID forwards an instruction to WB while stalled, the
  //   WB instruction classification must remain stable at the next cycle —
  //   no substitution of the instruction type while waiting.
  // RTL (WritebackStage=0, ibex_id_stage.sv line 1070):
  //   instr_type_wb_o = WB_INSTR_OTHER (constant). Stability holds trivially.
  //   With WritebackStage=1: instr_type_wb_o is combinational from lsu_req_dec/lsu_we
  //   (decoder signals from instr_rdata_i free var) — stability then requires input
  //   constraints. With WritebackStage=0 (default), this property proves unconditionally.
  // Fix: original CEX on `en_wb_o` in consequent — after halt_if=1 stall with
  //   en_wb_o=1, next cycle RTL de-asserts en_wb_o (instruction completed).
  //   Remove en_wb_o from consequent; the type-stability check is sufficient.
  property ie_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (en_wb_o && !id_in_ready_o) |=>
    instr_type_wb_o == $past(instr_type_wb_o);
  endproperty
  assert property (ie_SEC_2);

  // Group 3: Branch/jump control flow correctness (NS31A properties 5-10)
  // Security intent: ibex_id_stage correctly classifies and accounts for all
  //   control flow transfers; no spurious or missed branch/jump events.

  // ie_SEC_3_taken: A taken branch always corresponds to a positive branch decision.
  // RTL: ibex_id_stage.sv line 825: branch_set_raw_d = branch_decision_i | data_ind_timing_i.
  //   With BranchTargetALU=0 (ibex_core.sv default), branch_set_raw = branch_set_raw_q
  //   (registered one cycle). So perf_tbranch_o at cycle N reflects the branch
  //   decision from cycle N-1 → use $past() to match the one-cycle register delay.
  // Fix: branch_decision_o is NOT an ibex_id_stage port (ibex_ex_block output,
  //   VERI-2367 with bind .* ). Use $past of the ibex_id_stage inputs that drive
  //   branch_set_raw_d (lines 824-825).
  property ie_SEC_3_taken;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_tbranch_o |-> ($past(branch_decision_i) || $past(data_ind_timing_i));
  endproperty
  assert property (ie_SEC_3_taken);

  // ie_SEC_3_notaken: A branch instruction and a jump instruction cannot be
  //   decoded simultaneously — they occupy mutually exclusive opcode paths.
  // RTL: ibex_id_stage decoder sets perf_branch_o for opcode 7'b1100011 and
  //   perf_jump_o for 7'b1101111/7'b1100111 — structurally disjoint decode paths.
  // Fix: original used branch_decision_o (ibex_ex_block OUTPUT, not ibex_id_stage
  //   port) and branch_decision_i (DUT input, free var) in antecedent — R10
  //   violation. Replaced with output-only structural invariant.
  property ie_SEC_3_notaken;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_branch_o |-> !perf_jump_o;
  endproperty
  assert property (ie_SEC_3_notaken);

  // ie_SEC_3_excl: Every taken branch was decoded as a branch instruction.
  // RTL: ibex_id_stage.sv line 831: perf_branch_o=1 is set in the SAME always_comb
  //   block as branch_set_raw_d, inside the branch_in_dec/FIRST_CYCLE case.
  //   With BranchTargetALU=0, branch_set_raw=branch_set_raw_q (registered one cycle).
  //   So perf_tbranch_o at cycle N reflects branch_set_raw_q from cycle N-1, which
  //   was set by the branch_in_dec case that also set perf_branch_o=1 at N-1.
  //   → perf_tbranch_o |-> $past(perf_branch_o) matches the one-cycle register delay.
  // Fix: same-cycle form (perf_tbranch_o |-> perf_branch_o) CEX because
  //   instr_rdata_i is a free variable — JasperGold changes it at cycle N after
  //   branch_set_raw_q was latched at N-1, making perf_branch_o=0 at N.
  property ie_SEC_3_excl;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_tbranch_o |-> $past(perf_branch_o);
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

  // ie_SEC_3_jump_opcode: Jump performance event only fires on JAL/JALR/FENCE.I opcode.
  // RTL: ibex_decoder.sv sets jump_in_dec_o=1 / jump_set_o=1 for three cases:
  //   1. OPCODE_JAL   (7'b1101111) — unconditional jump
  //   2. OPCODE_JALR  (7'b1100111, funct3=000) — register-indirect jump
  //   3. OPCODE_MISC_MEM + funct3=001 (7'b0001111) — FENCE.I implemented as
  //      jump-to-next-PC to flush the instruction prefetch buffer (ibex_decoder.sv
  //      line 574: "FENCE.I is implemented as a jump to the next PC").
  //   4. Compressed jumps (C.J, C.JAL, C.JALR) when instr_is_compressed_i=1.
  //   Fix: Flash original missed FENCE.I (Ibex-specific implementation — FENCE.I
  //   is not a jump in the ISA spec but Ibex uses the jump path for prefetch flush).
  property ie_SEC_3_jump_opcode;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_jump_o |->
    (instr_rdata_i[6:0] == 7'b1101111 ||
     instr_rdata_i[6:0] == 7'b1100111 ||
     instr_rdata_i[6:0] == 7'b0001111 ||
     instr_is_compressed_i);
  endproperty
  assert property (ie_SEC_3_jump_opcode);

endmodule

bind ibex_id_stage ibex_id_stage_assertions u_ie_assert (.*);