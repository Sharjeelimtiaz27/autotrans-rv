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
    input  logic [33:0] imd_val_d_ex_i,
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
    input  logic [33:0] imd_val_q_i,
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
    input  logic [33:0] imd_val_q_ex_o,
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
  // -----------------------------------------------------------------------

  // Group 1: Instruction integrity ID->EX (NS31A properties 1-2)
  // Security intent: An instruction decoded in ID must not be corrupted when
  // it moves to EX. This prevents instruction substitution attacks.
  property ie_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    // When instruction is valid in ID and ID is ready to pass to EX
    (instr_valid_i && id_in_ready_o) |=>
    // Next cycle, the EX stage outputs must match what was decoded in ID
    (alu_operator_ex_o == $past(alu_operator_i) &&
     alu_operand_a_ex_o == $past(alu_operand_a_i) &&
     alu_operand_b_ex_o == $past(alu_operand_b_i));
  endproperty
  assert property (ie_SEC_1);

  // Group 2: Instruction integrity during WB stall (NS31A properties 3-4)
  // Security intent: When WB stage is stalled, the instruction must remain
  // unchanged. This prevents data corruption during pipeline stalls.
  property ie_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    // When WB stage is valid but not ready (stalled)
    (en_wb_o && !ready_wb_i) |=>
    // The instruction type and result must remain stable
    ($past(instr_type_wb_o) == instr_type_wb_o &&
     $past(result_ex_o) == result_ex_o);
  endproperty
  assert property (ie_SEC_2);

  // Group 3: Branch condition flags correctness (NS31A properties 5-10)
  // Security intent: For branch instructions, the ALU must correctly compute
  // the branch condition. This prevents control flow hijacking via incorrect
  // branch decisions.
  
  // Helper: Detect branch instructions by opcode (opcode[6:0] == 7'b1100011)
  // and funct3 field (instr_rdata_i[14:12])
  wire is_branch = (instr_rdata_i[6:0] == 7'b1100011);
  
  // BEQ: funct3 == 3'b000, branch when operands equal
  property ie_SEC_3_beq;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b000) &&
     (alu_operand_a_i == alu_operand_b_i)) |=>
    // Branch should be taken (branch_decision_o asserted)
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_beq);

  // BNE: funct3 == 3'b001, branch when operands not equal
  property ie_SEC_3_bne;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b001) &&
     (alu_operand_a_i != alu_operand_b_i)) |=>
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_bne);

  // BLT: funct3 == 3'b100, branch when signed less than
  property ie_SEC_3_blt;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b100) &&
     ($signed(alu_operand_a_i) < $signed(alu_operand_b_i))) |=>
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_blt);

  // BGE: funct3 == 3'b101, branch when signed greater or equal
  property ie_SEC_3_bge;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b101) &&
     ($signed(alu_operand_a_i) >= $signed(alu_operand_b_i))) |=>
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_bge);

  // BLTU: funct3 == 3'b110, branch when unsigned less than
  property ie_SEC_3_bltu;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b110) &&
     (alu_operand_a_i < alu_operand_b_i)) |=>
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_bltu);

  // BGEU: funct3 == 3'b111, branch when unsigned greater or equal
  property ie_SEC_3_bgeu;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && is_branch && 
     (instr_rdata_i[14:12] == 3'b111) &&
     (alu_operand_a_i >= alu_operand_b_i)) |=>
    branch_decision_o;
  endproperty
  assert property (ie_SEC_3_bgeu);

endmodule

bind ibex_id_stage ibex_id_stage_assertions u_ie_assert (.*);