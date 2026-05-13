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
    input  ibex_pkg::pmp_cfg_t[15:0] csr_pmp_cfg_o,
    input  logic [31:0] csr_pmp_addr_o,
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
  // -----------------------------------------------------------------------

  // csr_SEC_1: CSRs do not have write access in user mode
  // Security intent: Prevent unauthorized CSR modification from user mode
  property csr_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_id_o == PRIV_LVL_U && csr_op_en_i && 
     (csr_op_i == ibex_pkg::CSR_OP_WRITE || 
      csr_op_i == ibex_pkg::CSR_OP_SET || 
      csr_op_i == ibex_pkg::CSR_OP_CLEAR)) |-> 
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_1);

  // csr_SEC_2: CSRs can only be written by instructions with matching CSR address
  // Security intent: Ensure write operations target the correct CSR
  property csr_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && 
     (csr_op_i == ibex_pkg::CSR_OP_WRITE || 
      csr_op_i == ibex_pkg::CSR_OP_SET || 
      csr_op_i == ibex_pkg::CSR_OP_CLEAR) && 
     csr_addr_i != ibex_pkg::CSR_MSTATUS) |-> 
    $stable(csr_rdata_o) || illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_2);

  // csr_SEC_3: CSR can only be read by instructions with matching CSR address
  // Security intent: Ensure read operations target the correct CSR
  property csr_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && csr_op_i == ibex_pkg::CSR_OP_READ && 
     csr_addr_i != ibex_pkg::CSR_MSTATUS) |-> 
    csr_rdata_o == 32'd0 || illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_3);

  // csr_SEC_4: CSR read access is done only for CSR instructions
  // Security intent: Prevent unintended CSR reads from non-CSR instructions
  property csr_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    (!csr_op_en_i) |-> 
    (csr_addr_i != ibex_pkg::CSR_MSTATUS);
  endproperty
  assert property (csr_SEC_4);

  // csr_SEC_5: CSR write access is done only for CSR instructions
  // Security intent: Prevent unintended CSR writes from non-CSR instructions
  property csr_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    (!csr_op_en_i) |-> 
    !(csr_op_i == ibex_pkg::CSR_OP_WRITE || 
      csr_op_i == ibex_pkg::CSR_OP_SET || 
      csr_op_i == ibex_pkg::CSR_OP_CLEAR);
  endproperty
  assert property (csr_SEC_5);

  // csr_SEC_6: Read-only CSR's value is constant
  // Security intent: Verify read-only CSRs maintain their constant values
  property csr_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && csr_op_i == ibex_pkg::CSR_OP_READ && 
     (csr_addr_i == ibex_pkg::CSR_MVENDORID || 
      csr_addr_i == ibex_pkg::CSR_MARCHID || 
      csr_addr_i == ibex_pkg::CSR_MIMPID || 
      csr_addr_i == ibex_pkg::CSR_MHARTID)) |-> 
    $stable(csr_rdata_o);
  endproperty
  assert property (csr_SEC_6);

  // csr_SEC_7: Reserved bits in mie should be 0
  // Security intent: Ensure reserved fields in mie CSR are not modified
  property csr_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && csr_op_i == ibex_pkg::CSR_OP_READ && 
     csr_addr_i == ibex_pkg::CSR_MIE) |-> 
    ({csr_rdata_o[31:20], csr_rdata_o[18:12], csr_rdata_o[10:8], 
      csr_rdata_o[6:4], csr_rdata_o[2:0]} == 23'd0);
  endproperty
  assert property (csr_SEC_7);

  // csr_SEC_8: Exception flag is set for write to a read-only CSR register
  // Security intent: Detect and prevent writes to read-only CSRs
  property csr_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && 
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

  // csr_SEC_9: Exception flag is set for attempts to access a non-existent CSR
  // Security intent: Detect and prevent access to undefined CSR addresses
  property csr_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && 
     !(csr_addr_i inside {ibex_pkg::CSR_MVENDORID, ibex_pkg::CSR_MARCHID, 
                          ibex_pkg::CSR_MIMPID, ibex_pkg::CSR_MHARTID,
                          ibex_pkg::CSR_MSTATUS, ibex_pkg::CSR_MISA,
                          ibex_pkg::CSR_MIE, ibex_pkg::CSR_MTVEC,
                          ibex_pkg::CSR_MSCRATCH, ibex_pkg::CSR_MEPC,
                          ibex_pkg::CSR_MCAUSE, ibex_pkg::CSR_MTVAL,
                          ibex_pkg::CSR_MIP, ibex_pkg::CSR_DCSR,
                          ibex_pkg::CSR_DPC, ibex_pkg::CSR_DSCRATCH0,
                          ibex_pkg::CSR_DSCRATCH1})) |-> 
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_9);

  // csr_SEC_10: Exception flag is set for attempts to access a CSR without appropriate privilege level
  // Security intent: Enforce privilege level restrictions on CSR access
  property csr_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    (csr_op_en_i && priv_mode_id_o != PRIV_LVL_M && 
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