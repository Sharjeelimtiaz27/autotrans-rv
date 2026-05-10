// ibex_controller_cf_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_cf
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_cf_assertions (
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

  // cf_SEC_1: First instruction after reset must set PC to boot vector
  property cf_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    $rose(controller_run_o) && ready_wb_i && !irq_pending_i |-> pc_set_o && pc_mux_o == PC_BOOT;
  endproperty
  assert property (cf_SEC_1);

  // cf_SEC_2: Normal sequential execution increments PC by 4
  property cf_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    controller_run_o && ready_wb_i && !irq_pending_i && !wb_exception_o && 
    !jump_set_i && !branch_set_i && !csr_restore_mret_id_o && 
    !csr_restore_dret_id_o && !debug_mode_o |-> !pc_set_o;
  endproperty
  assert property (cf_SEC_2);

  // cf_SEC_3: Interrupt entry sets PC to interrupt vector
  property cf_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    ready_wb_i && irq_pending_i && csr_mstatus_mie_i |-> pc_set_o && pc_mux_o == PC_EXC;
  endproperty
  assert property (cf_SEC_3);

  // cf_SEC_4: Exception entry sets PC to exception vector
  property cf_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    ready_wb_i && wb_exception_o |-> pc_set_o && pc_mux_o == PC_EXC;
  endproperty
  assert property (cf_SEC_4);

  // cf_SEC_5: Debug return sets PC to DPC
  property cf_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    ready_wb_i && csr_restore_dret_id_o |-> pc_set_o && pc_mux_o == PC_DRET;
  endproperty
  assert property (cf_SEC_5);

  // cf_SEC_6: After JAL, PC set to jump target
  property cf_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    controller_run_o && ready_wb_i && jump_set_i |-> pc_set_o && pc_mux_o == PC_JUMP;
  endproperty
  assert property (cf_SEC_6);

  // cf_SEC_7: After JALR, PC set to jump target
  property cf_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    controller_run_o && ready_wb_i && jump_set_i |-> pc_set_o && pc_mux_o == PC_JUMP;
  endproperty
  assert property (cf_SEC_7);

  // cf_SEC_8: After taken branch, PC set to branch target
  property cf_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    controller_run_o && ready_wb_i && branch_set_i |-> pc_set_o && pc_mux_o == PC_BP;
  endproperty
  assert property (cf_SEC_8);

  // cf_SEC_9: After MRET, PC set to return address
  property cf_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    controller_run_o && ready_wb_i && csr_restore_mret_id_o |-> pc_set_o && pc_mux_o == PC_ERET;
  endproperty
  assert property (cf_SEC_9);

endmodule

bind ibex_controller ibex_controller_cf_assertions u_cf_assert (.*);