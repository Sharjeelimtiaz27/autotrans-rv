// ibex_controller_cf_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_cf
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_cf_assertions
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
  // Manually corrected after FPV CEX analysis (two rounds):
  //   Round 1: antecedents used DUT INPUTS (free vars): ready_wb_i, irq_pending_i,
  //   branch_set_i, jump_set_i. Fix: use DUT OUTPUT signals only.
  //   Round 2 (RTL inspection required):
  //   cf_SEC_7 CEX: ibex_controller.sv line 573 sets pc_mux_o=PC_JUMP
  //   unconditionally for the entire DECODE state (timing optimization).
  //   A taken branch (branch_set_i=1, jump_set_i=0) sets pc_set_o=1 and
  //   perf_tbranch_o=1, but perf_jump_o=0 and nt_branch_mispredict_o=0.
  //   Fix: add perf_tbranch_o to the PC_JUMP consequent disjunction.
  //   cf_SEC_8 CEX: PC_BP is NEVER assigned in ibex_controller.sv. Ibex uses
  //   PC_JUMP (not PC_BP) for taken branch redirects. Fix: PC_BP → PC_JUMP.
  //   WritebackStage=0: csr_save_id_o=0 in FLUSH, csr_save_wb_o=0 always.
  // -----------------------------------------------------------------------

  // cf_SEC_1: First instruction after reset must set PC to boot vector.
  // Security intent: Boot vector is loaded exactly once, immediately after reset.
  // RTL: RESET→BOOT_SET transition: pc_set_o=1, pc_mux_o=PC_BOOT on the first
  //      posedge after rst_ni deasserts.
  property cf_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    $rose(rst_ni) |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_BOOT);
  endproperty
  assert property (cf_SEC_1);

  // cf_SEC_2: Every PC redirect has a legitimate, RTL-observable cause.
  // Security intent: No spontaneous PC change — every redirect is tied to an
  //   instruction event, exception, interrupt, debug entry, or boot.
  // RTL: pc_set_o=1 only in BOOT_SET (PC_BOOT), DECODE (jump/branch/mispredict),
  //   IRQ_TAKEN (csr_save_cause_o=1), FLUSH (csr_save_cause_o/restore/debug_csr_save_o),
  //   DBG_TAKEN_IF/ID (debug_mode_entering_o=1).
  property cf_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    pc_set_o |->
      (csr_save_cause_o || debug_csr_save_o ||
       csr_restore_mret_id_o || csr_restore_dret_id_o ||
       debug_mode_entering_o ||
       perf_jump_o || perf_tbranch_o || nt_branch_mispredict_o ||
       pc_mux_o == ibex_pkg::PC_BOOT);
  endproperty
  assert property (cf_SEC_2);

  // cf_SEC_3: Interrupt taken always redirects to the interrupt vector.
  // Security intent: An accepted interrupt always enters at mtvec, not at an
  //   arbitrary address — prevents interrupt hijacking.
  // RTL: IRQ_TAKEN state: csr_save_cause_o=1, exc_cause_o.irq_int=1 (or irq_ext),
  //   pc_set_o=1, pc_mux_o=PC_EXC. debug_csr_save_o=0 in IRQ_TAKEN.
  property cf_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_cause_o && (exc_cause_o.irq_int || exc_cause_o.irq_ext) &&
     !debug_csr_save_o) |->
    (pc_set_o && pc_mux_o == ibex_pkg::PC_EXC);
  endproperty
  assert property (cf_SEC_3);

  // cf_SEC_4: Any exception save always redirects to the exception vector.
  // Security intent: All synchronous exceptions (illegal, ecall, fetch fault,
  //   ebreak software) redirect PC to the programmed mtvec — no escape.
  // RTL: FLUSH state exception cases + IRQ_TAKEN: csr_save_cause_o=1, pc_set_o=1,
  //   pc_mux_o=PC_EXC in the SAME clock cycle.
  property cf_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_cause_o |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_EXC);
  endproperty
  assert property (cf_SEC_4);

  // cf_SEC_5: Debug return (DRET) always restores PC from DPC register.
  // Security intent: Exiting debug mode returns to exactly the saved program
  //   counter — no hijacking of the resume address.
  // RTL: FLUSH state dret_insn path: csr_restore_dret_id_o=1, pc_set_o=1,
  //   pc_mux_o=PC_DRET, all in the same cycle.
  property cf_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_dret_id_o |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_DRET);
  endproperty
  assert property (cf_SEC_5);

  // cf_SEC_6: Every jump instruction causes a PC_JUMP redirect (forward direction).
  // Security intent: Jump instructions (JAL/JALR) always redirect — not silently
  //   skipped, ensuring jump targets are reached.
  // RTL: DECODE state jump_set_i=1: pc_set_o=1, pc_mux_o=PC_JUMP, perf_jump_o=1.
  property cf_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_jump_o |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_JUMP);
  endproperty
  assert property (cf_SEC_6);

  // cf_SEC_7: PC_JUMP redirects occur only on jumps, taken branches, or mispredicts.
  // Security intent: No spurious PC_JUMP redirect — only JAL/JALR (perf_jump_o),
  //   a taken conditional branch (perf_tbranch_o), or a branch-predictor mispredict
  //   correction (nt_branch_mispredict_o) may use the PC_JUMP mux.
  // RTL: ibex_controller.sv line 573 sets pc_mux_o=PC_JUMP unconditionally for the
  //   entire DECODE state (timing optimization). pc_set_o=1 only fires when
  //   branch_set_i||jump_set_i (lines 594-600), at which point perf_tbranch_o=branch_set_i
  //   and perf_jump_o=jump_set_i — at least one is always 1.
  property cf_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (pc_set_o && pc_mux_o == ibex_pkg::PC_JUMP) |->
    (perf_jump_o || perf_tbranch_o || nt_branch_mispredict_o);
  endproperty
  assert property (cf_SEC_7);

  // cf_SEC_8: Taken branch always redirects using the PC_JUMP mux.
  // Security intent: A taken conditional branch always causes a PC redirect to the
  //   branch target — the branch cannot be silently suppressed.
  // RTL: PC_BP is not used by ibex_controller. Ibex uses PC_JUMP for both jump and
  //   taken-branch targets (ibex_controller.sv line 573: pc_mux_o=PC_JUMP in DECODE).
  //   When branch_set_i=1: pc_set_o=1 and perf_tbranch_o=1 together (lines 596-598).
  property cf_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    perf_tbranch_o |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_JUMP);
  endproperty
  assert property (cf_SEC_8);

  // cf_SEC_9: Machine return (MRET) always restores PC from MEPC register.
  // Security intent: Returning from an M-mode trap always resumes at the saved
  //   exception PC — prevents MRET from jumping to an attacker-chosen address.
  // RTL: FLUSH state mret_insn path: csr_restore_mret_id_o=1, pc_set_o=1,
  //   pc_mux_o=PC_ERET, all in the same cycle.
  property cf_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_restore_mret_id_o |-> (pc_set_o && pc_mux_o == ibex_pkg::PC_ERET);
  endproperty
  assert property (cf_SEC_9);

endmodule

bind ibex_controller ibex_controller_cf_assertions u_cf_assert (.*);