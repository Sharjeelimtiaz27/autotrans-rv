// ibex_id_stage_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_id_stage
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_id_stage_assertions (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,
    // --- ports matching DUT (copy from signals.json) ---
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
    output logic ctrl_busy_o,
    output logic illegal_insn_o,
    output logic instr_req_o,
    output logic instr_first_cycle_id_o,
    output logic instr_valid_clear_o,
    output logic id_in_ready_o,
    output logic icache_inval_o,
    output logic pc_set_o,
    output ibex_pkg::pc_sel_e pc_mux_o,
    output logic nt_branch_mispredict_o,
    output logic [31:0] nt_branch_addr_o,
    output ibex_pkg::exc_pc_sel_e exc_pc_mux_o,
    output ibex_pkg::exc_cause_t exc_cause_o,
    output ibex_pkg::alu_op_e alu_operator_ex_o,
    output logic [31:0] alu_operand_a_ex_o,
    output logic [31:0] alu_operand_b_ex_o,
    output logic [33:0] imd_val_q_ex_o,
    output logic [31:0] bt_a_operand_o,
    output logic [31:0] bt_b_operand_o,
    output logic mult_en_ex_o,
    output logic div_en_ex_o,
    output logic mult_sel_ex_o,
    output logic div_sel_ex_o,
    output ibex_pkg::md_op_e multdiv_operator_ex_o,
    output logic [1:0] multdiv_signed_mode_ex_o,
    output logic [31:0] multdiv_operand_a_ex_o,
    output logic [31:0] multdiv_operand_b_ex_o,
    output logic multdiv_ready_id_o,
    output logic csr_access_o,
    output ibex_pkg::csr_op_e csr_op_o,
    output ibex_pkg::csr_num_e csr_addr_o,
    output logic csr_op_en_o,
    output logic csr_save_if_o,
    output logic csr_save_id_o,
    output logic csr_save_wb_o,
    output logic csr_restore_mret_id_o,
    output logic csr_restore_dret_id_o,
    output logic csr_save_cause_o,
    output logic [31:0] csr_mtval_o,
    output logic lsu_req_o,
    output logic lsu_we_o,
    output logic [1:0] lsu_type_o,
    output logic lsu_sign_ext_o,
    output logic [31:0] lsu_wdata_o,
    output logic nmi_mode_o,
    output logic expecting_load_resp_o,
    output logic expecting_store_resp_o,
    output logic debug_mode_o,
    output logic debug_mode_entering_o,
    output ibex_pkg::dbg_cause_e debug_cause_o,
    output logic debug_csr_save_o,
    output logic [4:0] rf_raddr_a_o,
    output logic [4:0] rf_raddr_b_o,
    output logic rf_ren_a_o,
    output logic rf_ren_b_o,
    output logic [4:0] rf_waddr_id_o,
    output logic [31:0] rf_wdata_id_o,
    output logic rf_we_id_o,
    output logic rf_rd_a_wb_match_o,
    output logic rf_rd_b_wb_match_o,
    output logic en_wb_o,
    output ibex_pkg::wb_instr_type_e instr_type_wb_o,
    output logic instr_perf_count_id_o,
    output logic perf_jump_o,
    output logic perf_branch_o,
    output logic perf_tbranch_o,
    output logic perf_dside_wait_o,
    output logic perf_mul_wait_o,
    output logic perf_div_wait_o,
    output logic instr_id_done_o,
    output logic [1:0] imd_val_we_o,
    output logic [33:0] imd_val_d_o,
    output logic [31:0] alu_adder_result_ex_o,
    output logic [31:0] result_ex_o,
    output logic [31:0] branch_target_o,
    output logic branch_decision_o,
    output logic ex_valid_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // ie_SEC_1: Instruction moving from ID to EX stage should remain the same
  property ie_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o) |=> (instr_rdata_i == $past(instr_rdata_i));
  endproperty
  assert property (ie_SEC_1);

  // ie_SEC_2: Instruction moving from EX to WB stage should remain the same
  property ie_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (ex_valid_i && ready_wb_i) |=> (instr_rdata_i == $past(instr_rdata_i));
  endproperty
  assert property (ie_SEC_2);

  // ie_SEC_3: Instruction that stays within EX stage should remain the same
  property ie_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (ex_valid_i && !ready_wb_i) |=> (instr_rdata_i == $past(instr_rdata_i));
  endproperty
  assert property (ie_SEC_3);

  // ie_SEC_4: Instruction that stays within ID stage should remain the same
  property ie_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && !id_in_ready_o) |=> (instr_rdata_i == $past(instr_rdata_i));
  endproperty
  assert property (ie_SEC_4);

  // ie_SEC_5: BEQ branch flag should be set correctly
  property ie_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b000) && 
     (rf_rdata_a_i == rf_rdata_b_i)) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_5);

  // ie_SEC_6: BNE branch flag should be set correctly
  property ie_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b001) && 
     (rf_rdata_a_i != rf_rdata_b_i)) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_6);

  // ie_SEC_7: BLT branch flag should be set correctly
  property ie_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b100) && 
     ($signed(rf_rdata_a_i) < $signed(rf_rdata_b_i))) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_7);

  // ie_SEC_8: BGE branch flag should be set correctly
  property ie_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b101) && 
     ($signed(rf_rdata_a_i) >= $signed(rf_rdata_b_i))) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_8);

  // ie_SEC_9: BLTU branch flag should be set correctly
  property ie_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b110) && 
     (rf_rdata_a_i < rf_rdata_b_i)) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_9);

  // ie_SEC_10: BGEU branch flag should be set correctly
  property ie_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && id_in_ready_o && 
     (instr_rdata_i[6:0] == 7'b1100011) && 
     (instr_rdata_i[14:12] == 3'b111) && 
     (rf_rdata_a_i >= rf_rdata_b_i)) |-> branch_decision_i;
  endproperty
  assert property (ie_SEC_10);

endmodule

bind ibex_id_stage ibex_id_stage_assertions u_ie_assert (.*);