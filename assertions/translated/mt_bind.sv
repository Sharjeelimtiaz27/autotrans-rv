// ibex_controller_mt_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_mt
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_mt_assertions (
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
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
    input  logic ctrl_busy_o,
    input  logic instr_valid_clear_o,
    input  logic id_in_ready_o,
    input  logic controller_run_o,
    input  logic instr_req_o,
    input  logic pc_set_o,
    input  ibex_pkg::pc_sel_e pc_mux_o,
    input  logic nt_branch_mispredict_o,
    input  ibex_pkg::exc_pc_sel_e exc_pc_mux_o,
    input  ibex_pkg::exc_cause_t exc_cause_o,
    input  logic wb_exception_o,
    input  logic id_exception_o,
    input  logic nmi_mode_o,
    input  ibex_pkg::dbg_cause_e debug_cause_o,
    input  logic debug_csr_save_o,
    input  logic debug_mode_o,
    input  logic debug_mode_entering_o,
    input  logic csr_save_if_o,
    input  logic csr_save_id_o,
    input  logic csr_save_wb_o,
    input  logic csr_restore_mret_id_o,
    input  logic csr_restore_dret_id_o,
    input  logic csr_save_cause_o,
    input  logic [31:0] csr_mtval_o,
    input  logic flush_id_o,
    input  logic perf_jump_o,
    input  logic perf_tbranch_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // mt_SEC_1: MRET from machine mode transitions to user mode
  // Security intent: MRET should restore the previous privilege mode (user mode)
  property mt_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (mret_insn_i && (priv_mode_i == PRIV_LVL_M)) |=> 
    (priv_mode_i == PRIV_LVL_U);
  endproperty
  assert property (mt_SEC_1);

  // mt_SEC_2: DRET from debug mode transitions to user mode
  // Security intent: DRET should restore the privilege mode saved before debug entry (user mode)
  property mt_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_restore_dret_id_o && debug_mode_o) |=> 
    (priv_mode_i == PRIV_LVL_U);
  endproperty
  assert property (mt_SEC_2);

  // mt_SEC_3: Exception from user mode transitions to machine mode
  // Security intent: Any exception should cause transition to machine mode
  property mt_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    ((id_exception_o || wb_exception_o) && (priv_mode_i == PRIV_LVL_U)) |=> 
    (priv_mode_i == PRIV_LVL_M);
  endproperty
  assert property (mt_SEC_3);

  // mt_SEC_4: Debug mode exit transitions to machine mode
  // Security intent: When debug mode exits, privilege mode should be machine mode
  property mt_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_mode_o && !$past(debug_mode_o)) |-> 
    (priv_mode_i == PRIV_LVL_M);
  endproperty
  assert property (mt_SEC_4);

  // mt_SEC_5: Reset establishes machine mode with MIE=0
  // Security intent: After reset, processor should be in machine mode with interrupts disabled
  property mt_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    !rst_ni |-> (priv_mode_i == PRIV_LVL_M) && !csr_mstatus_mie_i;
  endproperty
  assert property (mt_SEC_5);

  // mt_SEC_6: Any exception causes transition to machine mode
  // Security intent: Exception handling always elevates privilege to machine mode
  property mt_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (id_exception_o || wb_exception_o) |=> 
    (priv_mode_i == PRIV_LVL_M);
  endproperty
  assert property (mt_SEC_6);

  // mt_SEC_7: Interrupt causes transition to machine mode when conditions met
  // Security intent: When interrupt is pending and enabled, privilege mode becomes machine mode
  property mt_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (irq_pending_i && (csr_mstatus_mie_i || (priv_mode_i != PRIV_LVL_M))) |=> 
    (priv_mode_i == PRIV_LVL_M);
  endproperty
  assert property (mt_SEC_7);

  // mt_SEC_8: Halt request from user mode transitions to debug mode
  // Security intent: Debug halt request should cause entry into debug mode from user mode
  property mt_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_req_i && (priv_mode_i == PRIV_LVL_U)) |=> 
    (debug_mode_o || debug_mode_entering_o);
  endproperty
  assert property (mt_SEC_8);

  // mt_SEC_9: Halt request from machine mode transitions to debug mode
  // Security intent: Debug halt request should cause entry into debug mode from machine mode
  property mt_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_req_i && (priv_mode_i == PRIV_LVL_M)) |=> 
    (debug_mode_o || debug_mode_entering_o);
  endproperty
  assert property (mt_SEC_9);

  // mt_SEC_10: MRET updates privilege mode with previous mode
  // Security intent: MRET should restore the privilege mode that was saved before entering machine mode
  property mt_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (mret_insn_i || csr_restore_mret_id_o) |=> 
    (priv_mode_i != $past(priv_mode_i));
  endproperty
  assert property (mt_SEC_10);

endmodule

bind ibex_controller ibex_controller_mt_assertions u_mt_assert (.*);