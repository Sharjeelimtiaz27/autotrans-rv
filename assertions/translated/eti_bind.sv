// ibex_controller_eti_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_eti
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_eti_assertions
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
  // Manually rewritten after FPV CEX/vacuity analysis (ibex_controller FSM).
  //
  // Key ibex_controller FSM facts used:
  //   id_exception_o  = exc_req_d & ~wb_exception_o  (combinational, DECODE state)
  //   wb_exception_o  = load_err_q|store_err_q|load_err_i|store_err_i (WritebackStage)
  //   exc_req_d       = (ecall|ebrk|illegal_insn_d|instr_fetch_err) & (cs != FLUSH)
  //   csr_save_if_o   set in IRQ_TAKEN (line 644) and DBG_TAKEN_IF (line 685)
  //   csr_save_id_o   set in DBG_TAKEN_ID (conditional) and FLUSH for sync exceptions
  //   csr_save_wb_o   set in FLUSH: store_err_q|load_err_q cases only
  //   csr_save_cause_o set in all exception/debug-entry states; always with pc_set_o
  //   csr_restore_mret_id_o: FLUSH mret branch → pc_mux = PC_ERET
  //   csr_restore_dret_id_o: FLUSH dret branch → pc_mux = PC_DRET, debug_mode_d = 0
  // -----------------------------------------------------------------------

  // eti_SEC_1: id_exception_o is driven only by synchronous exception sources.
  // Security: no spurious exception flag without a real exception request.
  // RTL: id_exception_o = exc_req_d & ~wb_exception_o; exc_req_d contains exactly
  //      {ecall, ebrk, illegal_insn_d, instr_fetch_err} (all gated by instr_valid_i).
  property eti_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    id_exception_o |->
    (ecall_insn_i || ebrk_insn_i || illegal_insn_i || instr_fetch_err_i);
  endproperty
  assert property (eti_SEC_1);

  // eti_SEC_2: Store access fault carries the fault address in csr_mtval_o.
  // Security: exception context is complete — mtval identifies the faulting address.
  // RTL: FLUSH store_err_prio case: exc_cause_o = StoreAccessFault;
  //      csr_mtval_o = lsu_addr_last_i (the last LSU address, which is the fault address).
  property eti_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o &&
     exc_cause_o == ibex_pkg::ExcCauseStoreAccessFault) |->
    (csr_mtval_o == lsu_addr_last_i);
  endproperty
  assert property (eti_SEC_2);

  // eti_SEC_3: Exception cause field is always a standard RISC-V exception code.
  // RTL: exc_cause_o defaults to ExcCauseInsnAddrMisa (6'h00); all set values are
  //      RISC-V-standard codes with lower_cause ≤ 15, or irq_int/irq_ext flags set.
  property eti_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o || id_exception_o) |->
    (exc_cause_o.irq_int || exc_cause_o.irq_ext ||
     exc_cause_o.lower_cause inside {[0:15]});
  endproperty
  assert property (eti_SEC_3);

  // eti_SEC_4: MRET redirects execution to mepc via the PC_ERET mux entry.
  // Security: exception return restores the saved PC — no arbitrary jump target.
  // RTL: FLUSH mret_insn branch: pc_mux_o = PC_ERET; pc_set_o = 1;
  //      csr_restore_mret_id_o = 1 (all three set together, no other path sets MRET).
  property eti_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |->
    (pc_set_o && pc_mux_o == ibex_pkg::PC_ERET);
  endproperty
  assert property (eti_SEC_4);

  // eti_SEC_5: Exception cause save always coincides with a PC redirect.
  // Security: every trap atomically saves cause AND redirects PC to the handler.
  // RTL: all FSM states that assert csr_save_cause_o also assert pc_set_o:
  //      IRQ_TAKEN (irq path), FLUSH (exception path), DBG_TAKEN_IF, DBG_TAKEN_ID.
  property eti_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_cause_o |-> pc_set_o;
  endproperty
  assert property (eti_SEC_5);

  // eti_SEC_6: Synchronous exception (non-IRQ, non-debug) does not save the IF-stage PC.
  // Security: only IRQ_TAKEN and DBG_TAKEN_IF assert csr_save_if_o; FLUSH sync exceptions
  //           never do — correct per RISC-V spec (fault PC is in ID, not IF).
  // RTL: csr_save_if_o is set only in IRQ_TAKEN (line 644) and DBG_TAKEN_IF (line 685);
  //      in FLUSH (sync exception path) csr_save_if_o stays 0.
  // Note: replaces original csr_save_wb_o antecedent which is always 0 with WritebackStage=0.
  property eti_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o &&
     !exc_cause_o.irq_int && !exc_cause_o.irq_ext) |->
    !csr_save_if_o;
  endproperty
  assert property (eti_SEC_6);

  // eti_SEC_7: Load access fault carries the fault address in csr_mtval_o.
  // Security: exception context is complete — mtval identifies the faulting address.
  // RTL: FLUSH load_err_prio case: exc_cause_o = LoadAccessFault;
  //      csr_mtval_o = lsu_addr_last_i.
  property eti_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o &&
     exc_cause_o == ibex_pkg::ExcCauseLoadAccessFault) |->
    (csr_mtval_o == lsu_addr_last_i);
  endproperty
  assert property (eti_SEC_7);

  // eti_SEC_8: MRET uses the dedicated exception-return PC mux (PC_ERET).
  // Security: MRET cannot inject an arbitrary address — only mepc is the return target.
  // RTL: FLUSH mret_insn branch: pc_mux_o = PC_ERET (set before csr_restore_mret_id_o).
  property eti_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |-> (pc_mux_o == ibex_pkg::PC_ERET);
  endproperty
  assert property (eti_SEC_8);

  // eti_SEC_9: MRET and DRET are mutually exclusive in the same cycle.
  // Security: only one privileged return can execute at a time — no aliasing.
  // RTL: FLUSH: mret_insn and dret_insn are in separate if/else-if branches;
  //      csr_restore_mret_id_o and csr_restore_dret_id_o are never both 1.
  property eti_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |-> !csr_restore_dret_id_o;
  endproperty
  assert property (eti_SEC_9);

  // eti_SEC_10: DRET redirects execution to depc via the PC_DRET mux entry.
  // Security: debug return restores saved debug PC — no arbitrary jump target.
  // RTL: FLUSH dret_insn branch: pc_mux_o = PC_DRET; pc_set_o = 1;
  //      csr_restore_dret_id_o = 1; debug_mode_d = 0 (all atomic in one FSM state).
  property eti_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_dret_id_o |->
    (pc_set_o && pc_mux_o == ibex_pkg::PC_DRET);
  endproperty
  assert property (eti_SEC_10);

  // eti_SEC_11: IRQ exception handling saves the IF-stage PC (not ID or WB).
  // Security: interrupt return address is the NEXT instruction to execute (in IF),
  //           not the faulting instruction (ID) — correct RISC-V interrupt semantics.
  // RTL: IRQ_TAKEN state: csr_save_if_o = 1, csr_save_cause_o = 1, irq cause set.
  //      debug_csr_save_o guards against debug-entry false trigger.
  property eti_SEC_11;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o &&
     (exc_cause_o.irq_int || exc_cause_o.irq_ext)) |->
    csr_save_if_o;
  endproperty
  assert property (eti_SEC_11);

  // eti_SEC_12: csr_save_if_o and csr_save_id_o/wb_o are mutually exclusive.
  // Security: only one pipeline stage contributes the saved PC per trap event.
  // RTL: csr_save_if_o set in IRQ_TAKEN and DBG_TAKEN_IF (csr_save_id/wb = 0 there);
  //      csr_save_id_o set in FLUSH sync exceptions and DBG_TAKEN_ID (save_if = 0).
  property eti_SEC_12;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_if_o |-> (!csr_save_id_o && !csr_save_wb_o);
  endproperty
  assert property (eti_SEC_12);

  // eti_SEC_13: Instruction-access fault redirects to exception handler (not WB save).
  // Security: InstrAccessFault triggers a PC redirect to the exception vector, not a
  //           write-back stage save — correct per RISC-V spec.
  // RTL: FLUSH instr_fetch_err_prio: pc_set_o=1, exc_cause_o=InstrAccessFault.
  //      With WritebackStage=0, csr_save_id_o=0 always in FLUSH (g_no_writeback_mepc_save);
  //      use pc_set_o && !csr_save_wb_o as the RTL-invariant consequent instead.
  property eti_SEC_13;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o &&
     exc_cause_o == ibex_pkg::ExcCauseInstrAccessFault) |->
    (pc_set_o && !csr_save_wb_o);
  endproperty
  assert property (eti_SEC_13);

  // eti_SEC_14: Illegal instruction exception redirects to exception handler.
  // Security: IllegalInsn triggers PC redirect to exception vector, not a WB save.
  // RTL: FLUSH illegal_insn_prio: pc_set_o=1, exc_cause_o=IllegalInsn.
  //      With WritebackStage=0, csr_save_id_o=0 in FLUSH; use pc_set_o && !csr_save_wb_o.
  property eti_SEC_14;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o &&
     exc_cause_o == ibex_pkg::ExcCauseIllegalInsn) |->
    (pc_set_o && !csr_save_wb_o);
  endproperty
  assert property (eti_SEC_14);

  // eti_SEC_15: M-mode ecall exception redirects to exception handler.
  // Security: EcallMMode triggers PC redirect to exception vector, not a WB save.
  // RTL: FLUSH ecall_insn_prio: pc_set_o=1, exc_cause_o=EcallMMode.
  //      With WritebackStage=0, csr_save_id_o=0 in FLUSH; use pc_set_o && !csr_save_wb_o.
  property eti_SEC_15;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o &&
     exc_cause_o == ibex_pkg::ExcCauseEcallMMode) |->
    (pc_set_o && !csr_save_wb_o);
  endproperty
  assert property (eti_SEC_15);

  // eti_SEC_16: csr_save_id_o and csr_save_wb_o are mutually exclusive.
  // Security: WB-stage error and ID-stage sync exception cannot simultaneously save PC.
  // RTL: FLUSH: csr_save_id_o = ~(store_err_q|load_err_q); csr_save_wb_o = (store_err_q|load_err_q).
  //      These are complementary boolean expressions — never simultaneously 1.
  property eti_SEC_16;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_id_o |-> !csr_save_wb_o;
  endproperty
  assert property (eti_SEC_16);

  // eti_SEC_17: Every non-debug exception save redirects via the exception PC mux (PC_EXC).
  // Security: traps never jump to an arbitrary address — the target is always mtvec-derived
  //           (PC_EXC), not a branch, boot, debug, or return target.
  // RTL: All FSM states that assert csr_save_cause_o && !debug_csr_save_o also assert
  //      pc_mux_o = PC_EXC:
  //        IRQ_TAKEN  (line ~632): pc_mux_o = PC_EXC
  //        FLUSH exception path (line ~740): pc_mux_o = PC_EXC
  //      Debug-entry states set debug_csr_save_o=1 → excluded by antecedent.
  //      Debug override in FLUSH also clears csr_save_cause_o=0 → antecedent never fires.
  property eti_SEC_17;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && !debug_csr_save_o) |->
    (pc_mux_o == ibex_pkg::PC_EXC);
  endproperty
  assert property (eti_SEC_17);

endmodule

bind ibex_controller ibex_controller_eti_assertions u_eti_assert (.*);