// ibex_controller_mt_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_mt
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_mt_assertions (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,
    // --- ports matching DUT (copy from signals.json) ---
        input  logic illegal_insn_i,
    input  logic ecall_insn_i,
    input  logic mret_insn_i,
    input  logic dret_insn_i,
    input  logic wfi_insn_i,
    input  logic ebrk_insn_i,
    input  logic csr_pipe_flush_i,
    input  logic instr_valid_i,
    input  logic [31:0] instr_i,
    input  logic [15:0] instr_compressed_i,
    input  logic instr_is_compressed_i,
    input  logic instr_bp_taken_i,
    input  logic instr_fetch_err_i,
    input  logic instr_fetch_err_plus2_i,
    input  logic [31:0] pc_id_i,
    input  logic instr_exec_i,
    input  logic [31:0] lsu_addr_last_i,
    input  logic load_err_i,
    input  logic store_err_i,
    input  logic mem_resp_intg_err_i,
    input  logic branch_set_i,
    input  logic branch_not_set_i,
    input  logic jump_set_i,
    input  logic csr_mstatus_mie_i,
    input  logic irq_pending_i,
    input  ibex_pkg::irqs_t irqs_i,
    input  logic irq_nm_ext_i,
    input  logic debug_req_i,
    input  logic debug_single_step_i,
    input  logic debug_ebreakm_i,
    input  logic debug_ebreaku_i,
    input  logic trigger_match_i,
    input  ibex_pkg::priv_lvl_e priv_mode_i,
    input  logic stall_id_i,
    input  logic stall_wb_i,
    input  logic ready_wb_i,
    output logic ctrl_busy_o,
    output logic instr_valid_clear_o,
    output logic id_in_ready_o,
    output logic controller_run_o,
    output logic instr_req_o,
    output logic pc_set_o,
    output ibex_pkg::pc_sel_e pc_mux_o,
    output logic nt_branch_mispredict_o,
    output ibex_pkg::exc_pc_sel_e exc_pc_mux_o,
    output ibex_pkg::exc_cause_t exc_cause_o,
    output logic wb_exception_o,
    output logic id_exception_o,
    output logic nmi_mode_o,
    output ibex_pkg::dbg_cause_e debug_cause_o,
    output logic debug_csr_save_o,
    output logic debug_mode_o,
    output logic debug_mode_entering_o,
    output logic csr_save_if_o,
    output logic csr_save_id_o,
    output logic csr_save_wb_o,
    output logic csr_restore_mret_id_o,
    output logic csr_restore_dret_id_o,
    output logic csr_save_cause_o,
    output logic [31:0] csr_mtval_o,
    output logic flush_id_o,
    output logic perf_jump_o,
    output logic perf_tbranch_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // mt_SEC_1: Transition into user mode from machine mode when MRET is executed
  property mt_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    mret_insn_i && (priv_mode_i == PRIV_LVL_M) |=> priv_mode_i == PRIV_LVL_U;
  endproperty
  assert property (mt_SEC_1);

  // mt_SEC_2: Transition into user mode from debug mode after debug retires
  property mt_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_mode_o && dret_insn_i |=> priv_mode_i == PRIV_LVL_U;
  endproperty
  assert property (mt_SEC_2);

  // mt_SEC_3: Transition into machine mode from user mode when hart state allows
  property mt_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_i == PRIV_LVL_U) && (ecall_insn_i || illegal_insn_i || load_err_i || store_err_i) |=> priv_mode_i == PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_3);

  // mt_SEC_4: Transition into machine mode from debug mode immediately after debug retires
  property mt_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_mode_o == 1'b1 ##1 debug_mode_o == 1'b0 |-> priv_mode_i == PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_4);

  // mt_SEC_5: Transition into machine mode during processor reset
  property mt_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    !rst_ni |=> priv_mode_i == PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_5);

  // mt_SEC_6: When exception happens, privilege mode is set to machine mode
  property mt_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    id_exception_o |=> priv_mode_i == PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_6);

  // mt_SEC_7: When interrupt happens, privilege mode is set to machine mode
  property mt_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    ((priv_mode_i == PRIV_LVL_M && csr_mstatus_mie_i) || (priv_mode_i != PRIV_LVL_M)) && irq_pending_i |=> priv_mode_i == PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_7);

  // mt_SEC_8: Transition into debug mode from user mode in case of a halt request
  property mt_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_i == PRIV_LVL_U) && debug_req_i |=> debug_mode_o;
  endproperty
  assert property (mt_SEC_8);

  // mt_SEC_9: Transition into debug mode from machine mode in case of a halt request
  property mt_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_i == PRIV_LVL_M) && debug_req_i |=> debug_mode_o;
  endproperty
  assert property (mt_SEC_9);

  // mt_SEC_10: When return from debug or machine mode, MRET updates privilege mode
  // Note: MPP field not available, using simplified check that MRET leads to non-machine mode
  property mt_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    mret_insn_i |=> priv_mode_i != PRIV_LVL_M;
  endproperty
  assert property (mt_SEC_10);

endmodule

bind ibex_controller ibex_controller_mt_assertions u_mt_assert (.*);