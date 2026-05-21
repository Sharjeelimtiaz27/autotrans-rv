// ibex_cs_registers_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_cs_registers
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_cs_registers_assertions
    import ibex_pkg::*;
(
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
    input  logic [31:0] hart_id_i,
    input  logic csr_mtvec_init_i,
    input  logic [31:0] boot_addr_i,
    input  logic csr_access_i,
    input  ibex_pkg::csr_num_e csr_addr_i,
    input  logic [31:0] csr_wdata_i,
    input  ibex_pkg::csr_op_e csr_op_i,
    input  logic csr_op_en_i,
    input  logic irq_software_i,
    input  logic irq_timer_i,
    input  logic irq_external_i,
    input  logic [14:0] irq_fast_i,
    input  logic nmi_mode_i,
    input  logic debug_mode_i,
    input  logic debug_mode_entering_i,
    input  ibex_pkg::dbg_cause_e debug_cause_i,
    input  logic debug_csr_save_i,
    input  logic [31:0] pc_if_i,
    input  logic [31:0] pc_id_i,
    input  logic [31:0] pc_wb_i,
    input  logic ic_scr_key_valid_i,
    input  logic csr_save_if_i,
    input  logic csr_save_id_i,
    input  logic csr_save_wb_i,
    input  logic csr_restore_mret_i,
    input  logic csr_restore_dret_i,
    input  logic csr_save_cause_i,
    input  ibex_pkg::exc_cause_t csr_mcause_i,
    input  logic [31:0] csr_mtval_i,
    input  logic instr_ret_i,
    input  logic instr_ret_compressed_i,
    input  logic instr_ret_spec_i,
    input  logic instr_ret_compressed_spec_i,
    input  logic iside_wait_i,
    input  logic jump_i,
    input  logic branch_i,
    input  logic branch_taken_i,
    input  logic mem_load_i,
    input  logic mem_store_i,
    input  logic dside_wait_i,
    input  logic mul_wait_i,
    input  logic div_wait_i,
    input  ibex_pkg::priv_lvl_e priv_mode_id_o,
    input  ibex_pkg::priv_lvl_e priv_mode_lsu_o,
    input  logic csr_mstatus_tw_o,
    input  logic [31:0] csr_mtvec_o,
    input  logic [31:0] csr_rdata_o,
    input  logic irq_pending_o,
    input  ibex_pkg::irqs_t irqs_o,
    input  logic csr_mstatus_mie_o,
    input  logic [31:0] csr_mepc_o,
    input  logic [31:0] csr_mtval_o,
    input  ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_o,
    input  logic [31:0] csr_depc_o,
    input  logic debug_single_step_o,
    input  logic debug_ebreakm_o,
    input  logic debug_ebreaku_o,
    input  logic trigger_match_o,
    input  logic data_ind_timing_o,
    input  logic dummy_instr_en_o,
    input  logic [2:0] dummy_instr_mask_o,
    input  logic dummy_instr_seed_en_o,
    input  logic [31:0] dummy_instr_seed_o,
    input  logic icache_enable_o,
    input  logic csr_shadow_err_o,
    input  logic illegal_csr_insn_o,
    input  logic double_fault_seen_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // Manually corrected after FPV CEX analysis:
  //   Root cause: illegal_csr_insn_o = csr_access_i & (...), NOT csr_op_en_i & (...)
  //   All preconditions must use csr_access_i, not csr_op_en_i.
  //   SEC_2/3/4/5: original logic was wrong (csr_op_i/csr_addr_i are free variables
  //   from JasperGold's perspective at ibex_cs_registers boundary).
  //   SEC_6: $stable across different-address reads is always false; use direct value check.
  //   SEC_7: original wrongly included MFIX bits [30:16] in reserved-zero check.
  //   SEC_9: incomplete CSR list caused CEX; replaced with debug-CSR gate check.
  //   SEC_10: priv_mode_id_o != PRIV_LVL_M allows fake H/S enum values; use == PRIV_LVL_U.
  // -----------------------------------------------------------------------

  // csr_SEC_1: User-mode write to any CSR is illegal.
  // Security intent: All Ibex CSRs require M-mode; user-mode writes are always rejected.
  // RTL: illegal_csr_priv = (csr_addr[9:8] > priv_lvl_q). All Ibex CSR addresses
  //      have addr[9:8] = 2'b11; priv_lvl_q = 2'b00 for U-mode → always illegal.
  property csr_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_id_o == PRIV_LVL_U && csr_access_i &&
     (csr_op_i == ibex_pkg::CSR_OP_WRITE ||
      csr_op_i == ibex_pkg::CSR_OP_SET ||
      csr_op_i == ibex_pkg::CSR_OP_CLEAR)) |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_1);

  // csr_SEC_2: M-mode write to CSR_MEPC is a legal (non-illegal) operation.
  // Security intent: Valid M-mode writes to writable CSRs are accepted, not rejected.
  // RTL: CSR_MEPC (0x341) has addr[9:8]=01 ≤ priv_lvl_q=11 (M-mode), addr[11:10]=00
  //      (writable), defined case in read logic → illegal_csr=0, all illegal flags=0.
  property csr_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_id_o == PRIV_LVL_M && csr_access_i &&
     csr_op_i == ibex_pkg::CSR_OP_WRITE &&
     csr_addr_i == ibex_pkg::CSR_MEPC) |->
    !illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_2);

  // csr_SEC_3: Reading CSR_MHARTID returns the hardware thread ID input.
  // Security intent: Read data is correctly sourced from the addressed register.
  // RTL: CSR_MHARTID case: csr_rdata_int = hart_id_i (direct combinational assignment).
  property csr_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i && csr_addr_i == ibex_pkg::CSR_MHARTID) |->
    (csr_rdata_o == hart_id_i);
  endproperty
  assert property (csr_SEC_3);

  // csr_SEC_4: illegal_csr_insn_o can only be raised when csr_access_i is asserted.
  // Security intent: The exception flag is only triggered by actual CSR instructions.
  // RTL: illegal_csr_insn_o = csr_access_i & (...) → zero when csr_access_i = 0.
  property csr_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (!csr_access_i) |-> (!illegal_csr_insn_o);
  endproperty
  assert property (csr_SEC_4);

  // csr_SEC_5: M-mode access to CSR_MSCRATCH is legal.
  // Security intent: Scratch register is freely accessible in M-mode (no false illegal).
  // RTL: CSR_MSCRATCH (0x340) addr[9:8]=01 ≤ priv_lvl=11, addr[11:10]=00 writable,
  //      has a defined case → all illegal flags = 0.
  property csr_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_id_o == PRIV_LVL_M && csr_access_i &&
     csr_addr_i == ibex_pkg::CSR_MSCRATCH) |->
    !illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_5);

  // csr_SEC_6: Reading CSR_MARCHID always returns the constant architecture ID.
  // Security intent: Read-only machine info CSRs return their hardwired constant values.
  // RTL: CSR_MARCHID case: csr_rdata_int = CSR_MARCHID_VALUE (ibex_pkg localparam = 32'd22).
  property csr_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i && csr_addr_i == ibex_pkg::CSR_MARCHID) |->
    (csr_rdata_o == ibex_pkg::CSR_MARCHID_VALUE);
  endproperty
  assert property (csr_SEC_6);

  // csr_SEC_7: Reserved bits in MIE CSR read-data are always zero.
  // Security intent: Reserved fields must not carry information or leak state.
  // RTL: csr_rdata_int starts as '0; only bits 3 (MSIX), 7 (MTIX), 11 (MEIX),
  //      and [30:16] (MFIX) are driven for CSR_MIE; all other bits remain 0.
  property csr_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i && csr_addr_i == ibex_pkg::CSR_MIE) |->
    ({csr_rdata_o[2:0], csr_rdata_o[6:4], csr_rdata_o[10:8],
      csr_rdata_o[15:12], csr_rdata_o[31]} == 14'd0);
  endproperty
  assert property (csr_SEC_7);

  // csr_SEC_8: Write attempt to a read-only CSR raises the illegal instruction flag.
  // Security intent: Hardware-enforced read-only CSRs (addr[11:10]=11) reject writes.
  // RTL: illegal_csr_write = (csr_addr[11:10] == 2'b11) && csr_wr.
  property csr_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i &&
     (csr_op_i == ibex_pkg::CSR_OP_WRITE ||
      csr_op_i == ibex_pkg::CSR_OP_SET ||
      csr_op_i == ibex_pkg::CSR_OP_CLEAR) &&
     (csr_addr_i == ibex_pkg::CSR_MVENDORID ||
      csr_addr_i == ibex_pkg::CSR_MARCHID ||
      csr_addr_i == ibex_pkg::CSR_MIMPID ||
      csr_addr_i == ibex_pkg::CSR_MHARTID)) |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_8);

  // csr_SEC_9: Access to debug CSRs outside of debug mode raises illegal instruction.
  // Security intent: Debug registers (DCSR, DPC, DSCRATCH) are protected from
  // non-debug access — prevents debug state tampering from normal execution.
  // RTL: illegal_csr_dbg = dbg_csr & ~debug_mode_i; dbg_csr is set for all
  //      debug CSR addresses in the read-logic case statement.
  property csr_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i && !debug_mode_i &&
     (csr_addr_i == ibex_pkg::CSR_DCSR ||
      csr_addr_i == ibex_pkg::CSR_DPC ||
      csr_addr_i == ibex_pkg::CSR_DSCRATCH0 ||
      csr_addr_i == ibex_pkg::CSR_DSCRATCH1)) |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_9);

  // csr_SEC_10: U-mode access to M-mode CSRs raises the illegal instruction flag.
  // Security intent: M-mode privilege level CSRs (addr[9:8] > U-mode level) must
  // be inaccessible from user mode.
  // RTL: illegal_csr_priv = (csr_addr[9:8] > priv_lvl_q). For M-mode CSRs addr[9:8]=11
  //      and U-mode priv_lvl_q=00: 11 > 00 = true → illegal. Use == PRIV_LVL_U to
  //      avoid fake H/S enum values being driven by JasperGold as free variables.
  property csr_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_access_i && priv_mode_id_o == PRIV_LVL_U &&
     (csr_addr_i == ibex_pkg::CSR_MSTATUS ||
      csr_addr_i == ibex_pkg::CSR_MIE ||
      csr_addr_i == ibex_pkg::CSR_MTVEC ||
      csr_addr_i == ibex_pkg::CSR_MSCRATCH ||
      csr_addr_i == ibex_pkg::CSR_MEPC ||
      csr_addr_i == ibex_pkg::CSR_MCAUSE ||
      csr_addr_i == ibex_pkg::CSR_MTVAL ||
      csr_addr_i == ibex_pkg::CSR_MIP)) |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_10);

endmodule

bind ibex_cs_registers ibex_cs_registers_assertions u_csr_assert (.*);