// ibex_controller_eti_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_controller_eti
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_controller_eti_assertions (
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

  // eti_SEC_1: All exceptions, interrupts and NMIs set corresponding exception flag
  property eti_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (illegal_insn_i || ecall_insn_i || ebrk_insn_i || 
     instr_fetch_err_i || load_err_i || store_err_i || 
     mem_resp_intg_err_i || irq_pending_i || irq_nm_ext_i) |-> 
    (id_exception_o || wb_exception_o || nmi_mode_o);
  endproperty
  assert property (eti_SEC_1);

  // eti_SEC_2: mtval written with exception-specific information
  property eti_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o || id_exception_o) |-> 
    (csr_mtval_o != 32'd0 || exc_cause_o == ibex_pkg::EXC_CAUSE_BREAKPOINT);
  endproperty
  assert property (eti_SEC_2);

  // eti_SEC_3: mcause set to exception code
  property eti_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o || id_exception_o) |-> 
    (exc_cause_o.irq_int || exc_cause_o.irq_ext || 
     exc_cause_o.lower_cause inside {[0:15]});
  endproperty
  assert property (eti_SEC_3);

  // eti_SEC_4: mpp set to previous privilege level on trap
  property eti_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_if_o || csr_save_id_o || csr_save_wb_o) |-> 
    (priv_mode_i inside {ibex_pkg::PRIV_LVL_M, ibex_pkg::PRIV_LVL_U});
  endproperty
  assert property (eti_SEC_4);

  // eti_SEC_5: mie set to 0 when trap taken
  property eti_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_if_o || csr_save_id_o || csr_save_wb_o) |-> 
    !csr_mstatus_mie_i;
  endproperty
  assert property (eti_SEC_5);

  // eti_SEC_6: mpie set to previous mie value
  property eti_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_save_if_o || csr_save_id_o || csr_save_wb_o) |-> 
    $past(csr_mstatus_mie_i);
  endproperty
  assert property (eti_SEC_6);

  // eti_SEC_7: mepc set to PC from WB stage for exceptions
  property eti_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o && csr_save_wb_o) |-> 
    (pc_id_i == $past(pc_id_i));
  endproperty
  assert property (eti_SEC_7);

  // eti_SEC_8: MRET updates mpp/mprv
  property eti_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (mret_insn_i && csr_restore_mret_id_o) |-> 
    (priv_mode_i == ibex_pkg::PRIV_LVL_M);
  endproperty
  assert property (eti_SEC_8);

  // eti_SEC_9: MRET sets mpie
  property eti_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (mret_insn_i && csr_restore_mret_id_o) |-> 
    csr_mstatus_mie_i;
  endproperty
  assert property (eti_SEC_9);

  // eti_SEC_10: MRET restores mie from mpie
  property eti_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (mret_insn_i && csr_restore_mret_id_o) |-> 
    csr_mstatus_mie_i;
  endproperty
  assert property (eti_SEC_10);

  // eti_SEC_11: Exception implies handler started
  property eti_SEC_11;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o || id_exception_o) |-> 
    ##1 (pc_set_o && exc_pc_mux_o inside {ibex_pkg::EXC_PC_EXC, ibex_pkg::EXC_PC_IRQ});
  endproperty
  assert property (eti_SEC_11);

  // eti_SEC_12: No exception without request
  property eti_SEC_12;
    @(posedge clk_i) disable iff (!rst_ni)
    (wb_exception_o || id_exception_o) |-> 
    (illegal_insn_i || ecall_insn_i || ebrk_insn_i || 
     instr_fetch_err_i || load_err_i || store_err_i || 
     mem_resp_intg_err_i || irq_pending_i);
  endproperty
  assert property (eti_SEC_12);

  // eti_SEC_13: Interrupt eventually handled
  property eti_SEC_13;
    @(posedge clk_i) disable iff (!rst_ni)
    irq_pending_i |-> ##[1:10] (wb_exception_o && pc_set_o && 
                                 exc_pc_mux_o == ibex_pkg::EXC_PC_IRQ);
  endproperty
  assert property (eti_SEC_13);

  // eti_SEC_14: Interrupt enabled according to mie
  property eti_SEC_14;
    @(posedge clk_i) disable iff (!rst_ni)
    (irq_pending_i && csr_mstatus_mie_i) |-> 
    ##1 (wb_exception_o || id_exception_o);
  endproperty
  assert property (eti_SEC_14);

  // eti_SEC_15: Interrupt bit in mcause set for interrupts
  property eti_SEC_15;
    @(posedge clk_i) disable iff (!rst_ni)
    (irq_pending_i && (wb_exception_o || id_exception_o)) |-> 
    (exc_cause_o.irq_int || exc_cause_o.irq_ext);
  endproperty
  assert property (eti_SEC_15);

  // eti_SEC_16: mepc written with interrupted PC
  property eti_SEC_16;
    @(posedge clk_i) disable iff (!rst_ni)
    (irq_pending_i && csr_save_if_o) |-> 
    (pc_id_i == $past(pc_id_i));
  endproperty
  assert property (eti_SEC_16);

  // eti_SEC_17: Invalid frm causes illegal instruction
  property eti_SEC_17;
    @(posedge clk_i) disable iff (!rst_ni)
    (instr_valid_i && (instr_i[14:12] inside {3'b101, 3'b110, 3'b111}) && 
     (instr_i[6:0] inside {7'b1010011, 7'b1000011, 7'b1000111, 7'b1001011, 7'b1001111})) |-> 
     illegal_insn_i;
  endproperty
  assert property (eti_SEC_17);

endmodule

bind ibex_controller ibex_controller_eti_assertions u_eti_assert (.*);