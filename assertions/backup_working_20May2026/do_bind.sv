// ibex_controller_do_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_do
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_do_assertions
    import ibex_pkg::*;
(
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
  // Manually corrected after FPV CEX analysis (ibex_controller FSM semantics)
  // -----------------------------------------------------------------------

  // do_SEC_1: Debug CSR saves (dcsr/dpc writes) occur only when entering debug mode.
  // Security intent: Prevent unauthorized modification of debug registers outside
  // of a legitimate debug entry transition.
  // RTL: debug_csr_save_o is set ONLY in DBG_TAKEN_IF and DBG_TAKEN_ID states,
  //      both of which also assert debug_mode_entering_o.
  property do_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_csr_save_o |-> debug_mode_entering_o;
  endproperty
  assert property (do_SEC_1);

  // do_SEC_2: Once in debug mode, the core stays in debug mode until DRET.
  // Security intent: Debug mode provides isolation — no other mechanism can
  // exit debug mode, preventing privilege escalation via spurious debug exit.
  // RTL: debug_mode_d = 0 only when dret_insn is processed in FLUSH state,
  //      which also asserts csr_restore_dret_id_o.
  property do_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_mode_o && !csr_restore_dret_id_o) |-> ##1 debug_mode_o;
  endproperty
  assert property (do_SEC_2);

  // do_SEC_3: A fresh debug mode entry always results in debug mode being active.
  // Security intent: The debug entry handshake completes atomically — if the
  // controller signals debug_mode_entering_o, debug_mode_o must follow.
  // RTL: debug_mode_d = 1 is set in all DBG_TAKEN states alongside
  //      debug_mode_entering_o = 1; next posedge latches debug_mode_q = 1.
  property do_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_mode_entering_o && !debug_mode_o) |-> ##1 debug_mode_o;
  endproperty
  assert property (do_SEC_3);

  // do_SEC_4: DRET is the exclusive mechanism for exiting debug mode.
  // Security intent: Only an authorised debug return instruction can lower
  // debug_mode_o — no exception, IRQ, or reset (other than rst_ni) bypasses this.
  // RTL: debug_mode_d = 0 is set only when dret_insn is true in FLUSH state,
  //      which is the sole path that also sets csr_restore_dret_id_o = 1.
  property do_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    $fell(debug_mode_o) |-> $past(csr_restore_dret_id_o);
  endproperty
  assert property (do_SEC_4);

endmodule

bind ibex_controller ibex_controller_do_assertions u_do_assert (.*);