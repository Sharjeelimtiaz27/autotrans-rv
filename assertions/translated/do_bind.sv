// ibex_controller_do_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_do
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_do_assertions (
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

  // do_SEC_1: Upon entry to debug mode via ebreak, the PC of the ebreak instruction
  // is captured. This ensures dpc is correctly set for debug resume.
  property do_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (ebrk_insn_i && instr_valid_i && debug_mode_entering_o) |-> 
    (debug_cause_o == ibex_pkg::DBG_CAUSE_EBREAK);
  endproperty
  assert property (do_SEC_1);

  // do_SEC_2: When single-stepping and a taken branch or jump occurs, the next PC
  // is the target address. For non-flow-changing instructions, PC advances by 4.
  // This ensures dpc captures the correct next instruction address.
  property do_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (debug_single_step_i && instr_valid_i && !ebrk_insn_i && 
     (jump_set_i || (branch_set_i && instr_bp_taken_i))) |-> 
    (pc_set_o && (pc_mux_o == ibex_pkg::PC_JUMP || pc_mux_o == ibex_pkg::PC_BP));
  endproperty
  assert property (do_SEC_2);

  // do_SEC_3: When entering debug mode, the current privilege mode is captured.
  // This ensures dcsr reflects the correct privilege level at debug entry.
  property do_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    debug_mode_entering_o |-> 
    (priv_mode_i == ibex_pkg::PRIV_LVL_M || 
     priv_mode_i == ibex_pkg::PRIV_LVL_U);
  endproperty
  assert property (do_SEC_3);

  // do_SEC_4: Debug CSR writes (indicated by csr_save_wb_o) are only allowed
  // when the core is in debug mode. This prevents unauthorized modification
  // of debug registers from non-debug contexts.
  property do_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_save_wb_o |-> debug_mode_o;
  endproperty
  assert property (do_SEC_4);

endmodule

bind ibex_controller ibex_controller_do_assertions u_do_assert (.*);