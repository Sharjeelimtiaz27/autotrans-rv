// ibex_controller_mt_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_mt
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_mt_assertions
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
  // Manually corrected after FPV structural analysis (two rounds):
  //   Round 1: NS31A MT properties checked priv_mode_i (DUT INPUT = free var).
  //   Round 2 (RTL inspection required):
  //   mt_SEC_1 CEX root cause: ibex_controller FLUSH state sets
  //   csr_restore_mret_id_o=1 with NO debug_mode_q guard (line 801 RTL).
  //   MRET in debug mode is architecturally valid; controller does not block it.
  //   Fix: verify FSM exclusivity — MRET (FLUSH) and debug entry (DBG_TAKEN_*)
  //   are mutually exclusive states; debug_mode_entering_o cannot fire in FLUSH.
  //   mt_SEC_2 CEX root cause: FLUSH dret path sets csr_restore_dret_id_o=1
  //   with NO debug_mode_q check (line 809 RTL). But RTL unconditionally sets
  //   debug_mode_d=0 on DRET, so next cycle debug_mode_o is provably 0.
  //   Fix: use |=> (next-cycle) to check the RTL-enforced post-DRET state.
  //   mt_SEC_8 CEX root cause: DBG_TAKEN_ID sets debug_mode_entering_o=1
  //   ALWAYS (line 723) but debug_csr_save_o=1 only conditionally (line 718,
  //   only when ebreak_into_debug && !debug_mode_q). Re-entry ebreak (already
  //   in debug mode) fires entering without saving CSRs.
  //   Fix: flip implication — debug_csr_save_o |-> debug_mode_entering_o
  //   (save always implies entry; entry does not always imply save).
  //   WritebackStage=0: wb_exception_o always 0 — removed from antecedents.
  // -----------------------------------------------------------------------

  // mt_SEC_1: MRET and debug mode entry are mutually exclusive in the same cycle.
  // Security intent: The M-mode return and a debug mode entry cannot occur
  //   simultaneously — they would leave PC and privilege state undefined.
  // RTL: csr_restore_mret_id_o fires in FLUSH state (special-instruction path);
  //   debug_mode_entering_o fires only in DBG_TAKEN_IF and DBG_TAKEN_ID states.
  //   These FSM states are mutually exclusive; the FLUSH→DBG_TAKEN redirect
  //   only sets ctrl_fsm_ns (next cycle), not current-cycle debug_mode_entering_o.
  property mt_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |-> !debug_mode_entering_o;
  endproperty
  assert property (mt_SEC_1);

  // mt_SEC_2: DRET always exits debug mode (next cycle).
  // Security intent: Executing DRET always transitions out of debug mode —
  //   you cannot DRET and remain in debug mode, preventing debug-privilege lock-in.
  // RTL: FLUSH dret_insn path unconditionally sets debug_mode_d=1'b0 (line 808).
  //   On the following posedge, debug_mode_q=0 and debug_mode_o=0.
  //   Uses |=> (non-overlapping) to check the registered state one cycle later.
  property mt_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_dret_id_o |=> !debug_mode_o;
  endproperty
  assert property (mt_SEC_2);

  // mt_SEC_3: Concurrent exception-save and MRET-restore are impossible.
  // Security intent: You cannot simultaneously take a trap and return from one —
  //   if this fired it would indicate a privilege confusion state.
  // RTL: csr_save_cause_o and csr_restore_mret_id_o are set in mutually
  //   exclusive FLUSH sub-cases (priority encoding prevents both).
  property mt_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_cause_o |-> !csr_restore_mret_id_o;
  endproperty
  assert property (mt_SEC_3);

  // mt_SEC_4: Debug mode entry is always preceded by the entering signal.
  // Security intent: debug_mode_o can only rise if debug_mode_entering_o
  //   was asserted the previous cycle — no stealthy debug escalation.
  // RTL: debug_mode_d=1 is set alongside debug_mode_entering_o=1 in
  //   DBG_TAKEN_IF and DBG_TAKEN_ID; next posedge latches debug_mode_q=1.
  property mt_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    $rose(debug_mode_o) |-> $past(debug_mode_entering_o);
  endproperty
  assert property (mt_SEC_4);

  // mt_SEC_5: After reset deassertion, core is not in debug mode.
  // Security intent: Reset must bring the core to a non-debug privileged state;
  //   booting into debug mode would expose debug registers to untrusted code.
  // RTL: debug_mode_q resets to 0 asynchronously; one cycle after rst_ni
  //   deasserts (BOOT_SET state), debug_mode_o = 0.
  property mt_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    $rose(rst_ni) |-> ##1 !debug_mode_o;
  endproperty
  assert property (mt_SEC_5);

  // mt_SEC_6: Concurrent exception-save and DRET-restore are impossible.
  // Security intent: Cannot simultaneously take a trap and exit debug mode —
  //   would leave privilege state undefined.
  // RTL: Same FLUSH priority encoding prevents both in the same cycle.
  property mt_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_cause_o |-> !csr_restore_dret_id_o;
  endproperty
  assert property (mt_SEC_6);

  // mt_SEC_7: An interrupt cause flag is always accompanied by a trap save.
  // Security intent: When the controller signals an interrupt-caused exception
  //   (irq_int or irq_ext bits in exc_cause_o), it must simultaneously issue
  //   csr_save_cause_o — preventing a silent interrupt that skips trap entry.
  // RTL: In IRQ_TAKEN state, exc_cause_o.irq_int=1 (or irq_ext=1) and
  //   csr_save_cause_o=1 are set together combinationally.
  property mt_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (exc_cause_o.irq_int || exc_cause_o.irq_ext) |-> csr_save_cause_o;
  endproperty
  assert property (mt_SEC_7);

  // mt_SEC_8: Debug CSR save implies debug mode entry (not the reverse).
  // Security intent: debug_csr_save_o commits DPC/DCSR — this can only occur
  //   during an authorised debug entry event (debug_mode_entering_o=1).
  //   The reverse does not hold: re-entry ebreak (already in debug mode) sets
  //   debug_mode_entering_o without saving CSRs, which is architecturally correct.
  // RTL: debug_csr_save_o=1 only in DBG_TAKEN_IF (always, with entering=1) and
  //   DBG_TAKEN_ID (conditional on ebreak_into_debug && !debug_mode_q, but
  //   debug_mode_entering_o=1 is ALWAYS set in DBG_TAKEN_ID regardless).
  property mt_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_csr_save_o |-> debug_mode_entering_o;
  endproperty
  assert property (mt_SEC_8);

  // mt_SEC_9: MRET and DRET cannot be simultaneously restored.
  // Security intent: Only one return path (M-mode or debug) is active per cycle;
  //   simultaneous MRET+DRET would leave PC and privilege state undefined.
  // RTL: FLUSH priority encoding sets exactly one of csr_restore_mret/dret.
  property mt_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |-> !csr_restore_dret_id_o;
  endproperty
  assert property (mt_SEC_9);

  // mt_SEC_10: Debug entry and DRET are mutually exclusive.
  // Security intent: Cannot enter and exit debug mode in the same cycle —
  //   debug_mode_entering_o and csr_restore_dret_id_o must never co-assert.
  // RTL: debug_mode_entering_o fires in DBG_TAKEN states; csr_restore_dret_id_o
  //   fires in FLUSH on dret path; these states are disjoint.
  property mt_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_mode_entering_o |-> !csr_restore_dret_id_o;
  endproperty
  assert property (mt_SEC_10);

endmodule

bind ibex_controller ibex_controller_mt_assertions u_mt_assert (.*);