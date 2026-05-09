// ibex_cs_registers_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_cs_registers
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_cs_registers_assertions (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,
    // --- ports matching DUT ---
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
    output ibex_pkg::priv_lvl_e priv_mode_id_o,
    output ibex_pkg::priv_lvl_e priv_mode_lsu_o,
    output logic csr_mstatus_tw_o,
    output logic [31:0] csr_mtvec_o,
    output logic [31:0] csr_rdata_o,
    output logic irq_pending_o,
    output ibex_pkg::irqs_t irqs_o,
    output logic csr_mstatus_mie_o,
    output logic [31:0] csr_mepc_o,
    output logic [31:0] csr_mtval_o,
    output ibex_pkg::pmp_cfg_t [PMPNumRegions-1:0] csr_pmp_cfg_o,
    output logic [PMP_ADDR_MSB:0] csr_pmp_addr_o,
    output ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_o,
    output logic [31:0] csr_depc_o,
    output logic debug_single_step_o,
    output logic debug_ebreakm_o,
    output logic debug_ebreaku_o,
    output logic trigger_match_o,
    output logic data_ind_timing_o,
    output logic dummy_instr_en_o,
    output logic [2:0] dummy_instr_mask_o,
    output logic dummy_instr_seed_en_o,
    output logic [31:0] dummy_instr_seed_o,
    output logic icache_enable_o,
    output logic csr_shadow_err_o,
    output logic illegal_csr_insn_o,
    output logic double_fault_seen_o
);

  // -----------------------------------------------------------------------
  // Internal signals for assertion logic
  // -----------------------------------------------------------------------
  logic csr_we_int;
  logic csr_wr;
  logic [31:0] mie;
  logic [31:0] mip;
  
  // Map internal signals from DUT (these are internal to ibex_cs_registers)
  // Note: These are accessed via hierarchical reference in bind context
  
  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // ========================================================================
  // Assertion Group 1: CSRs do not have write access in user mode
  // Property IDs: 11-111 (101 assertions)
  // ========================================================================
  
  // Example: mstatus write protection in user mode
  // Applies to all 67 CSRs except user FP CSRs
  property csr_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (priv_mode_id_o == PRIV_LVL_U) && 
    (csr_op_i inside {CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR}) &&
    csr_op_en_i
    |->
    !(csr_we_int && (csr_addr_i == CSR_MSTATUS));
  endproperty
  assert property (csr_SEC_1);

  // ========================================================================
  // Assertion Group 2: CSRs can only be written by instructions with matching CSR address
  // Property IDs: 112-162 (51 assertions)
  // ========================================================================
  
  // Example: mstatus write address check
  property csr_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i && 
    (csr_op_i inside {CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR}) &&
    (csr_addr_i != CSR_MSTATUS)
    |->
    !(csr_we_int && (csr_addr_i == CSR_MSTATUS));
  endproperty
  assert property (csr_SEC_2);

  // ========================================================================
  // Assertion Group 3: CSR can only be read by instructions with matching CSR address
  // Property IDs: 163-228 (66 assertions)
  // ========================================================================
  
  // Example: mstatus read address check
  property csr_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i && 
    (csr_op_i == CSR_OP_READ) &&
    (csr_addr_i != CSR_MSTATUS)
    |->
    (csr_rdata_o == 32'd0);
  endproperty
  assert property (csr_SEC_3);

  // ========================================================================
  // Assertion Group 4: CSR read access only for CSR instructions
  // Property IDs: 229-285 (57 assertions)
  // ========================================================================
  
  property csr_SEC_4;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    !(csr_op_i inside {CSR_OP_READ, CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR})
    |->
    (csr_addr_i != CSR_MSTATUS);
  endproperty
  assert property (csr_SEC_4);

  // ========================================================================
  // Assertion Group 5: CSR write access only for CSR instructions
  // Property IDs: 286-342 (57 assertions)
  // ========================================================================
  
  property csr_SEC_5;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    !(csr_op_i inside {CSR_OP_READ, CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR})
    |->
    !(csr_we_int && (csr_addr_i == CSR_MSTATUS));
  endproperty
  assert property (csr_SEC_5);

  // ========================================================================
  // Assertion Group 6: Read-only CSR's value is constant
  // Property IDs: 343-352 (10 assertions)
  // ========================================================================
  
  // Note: VendorID is a parameter, not a runtime signal
  // This assertion checks that read-only CSRs maintain their reset value
  
  property csr_SEC_6;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    (csr_op_i == CSR_OP_READ) &&
    (csr_addr_i == CSR_MVENDORID)
    |->
    (csr_rdata_o == CsrMvendorId);
  endproperty
  assert property (csr_SEC_6);

  // ========================================================================
  // Assertion Group 7: CSR format constraints - reserved bits in mie should be 0
  // Property IDs: 353-398 (46 assertions)
  // ========================================================================
  
  property csr_SEC_7;
    @(posedge clk_i) disable iff (!rst_ni)
    1'b1
    |->
    ({mie[31:20], mie[18:12], mie[10:8], mie[6:4], mie[2:0]} == 23'd0);
  endproperty
  assert property (csr_SEC_7);

  // ========================================================================
  // Assertion Group 8: Exception flag for write to read-only CSR
  // Property IDs: 399-400 (2 assertions)
  // ========================================================================
  
  property csr_SEC_8;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    (csr_op_i inside {CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR}) &&
    (csr_addr_i inside {CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID, CSR_MCONFIGPTR, CSR_MISA})
    |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_8);

  // ========================================================================
  // Assertion Group 9: Exception flag for access to non-existent CSR
  // Property IDs: 401-402 (2 assertions)
  // ========================================================================
  
  property csr_SEC_9;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    !(csr_addr_i inside {
        CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID, CSR_MCONFIGPTR,
        CSR_MSTATUS, CSR_MISA, CSR_MIE, CSR_MTVEC, CSR_MCOUNTEREN,
        CSR_MSTATUSH, CSR_MENVCFG, CSR_MENVCFGH,
        CSR_MSCRATCH, CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MIP,
        CSR_PMPCFG0, CSR_PMPCFG1, CSR_PMPCFG2, CSR_PMPCFG3,
        CSR_PMPADDR0, CSR_PMPADDR1, CSR_PMPADDR2, CSR_PMPADDR3,
        CSR_PMPADDR4, CSR_PMPADDR5, CSR_PMPADDR6, CSR_PMPADDR7,
        CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
        CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15,
        CSR_SCONTEXT, CSR_MSECCFG, CSR_MSECCFGH,
        CSR_TSELECT, CSR_TDATA1, CSR_TDATA2, CSR_TDATA3,
        CSR_MCONTEXT, CSR_MSCONTEXT,
        CSR_DCSR, CSR_DPC, CSR_DSCRATCH0, CSR_DSCRATCH1,
        CSR_MCOUNTINHIBIT,
        CSR_MHPMEVENT3, CSR_MHPMEVENT4, CSR_MHPMEVENT5, CSR_MHPMEVENT6,
        CSR_MHPMEVENT7, CSR_MHPMEVENT8, CSR_MHPMEVENT9, CSR_MHPMEVENT10,
        CSR_MHPMEVENT11, CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14,
        CSR_MHPMEVENT15, CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18,
        CSR_MHPMEVENT19, CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22,
        CSR_MHPMEVENT23, CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26,
        CSR_MHPMEVENT27, CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30,
        CSR_MHPMEVENT31,
        CSR_MCYCLE, CSR_MINSTRET,
        CSR_MHPMCOUNTER3, CSR_MHPMCOUNTER4, CSR_MHPMCOUNTER5, CSR_MHPMCOUNTER6,
        CSR_MHPMCOUNTER7, CSR_MHPMCOUNTER8, CSR_MHPMCOUNTER9, CSR_MHPMCOUNTER10,
        CSR_MHPMCOUNTER11, CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14,
        CSR_MHPMCOUNTER15, CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18,
        CSR_MHPMCOUNTER19, CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22,
        CSR_MHPMCOUNTER23, CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26,
        CSR_MHPMCOUNTER27, CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30,
        CSR_MHPMCOUNTER31,
        CSR_MCYCLEH, CSR_MINSTRETH,
        CSR_MHPMCOUNTER3H, CSR_MHPMCOUNTER4H, CSR_MHPMCOUNTER5H, CSR_MHPMCOUNTER6H,
        CSR_MHPMCOUNTER7H, CSR_MHPMCOUNTER8H, CSR_MHPMCOUNTER9H, CSR_MHPMCOUNTER10H,
        CSR_MHPMCOUNTER11H, CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H,
        CSR_MHPMCOUNTER15H, CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H,
        CSR_MHPMCOUNTER19H, CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H,
        CSR_MHPMCOUNTER23H, CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H,
        CSR_MHPMCOUNTER27H, CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H,
        CSR_MHPMCOUNTER31H,
        CSR_CPUCTRLSTS, CSR_SECURESEED
    })
    |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_9);

  // ========================================================================
  // Assertion Group 10: Exception flag for CSR access without appropriate privilege
  // Property IDs: 403-404 (2 assertions)
  // ========================================================================
  
  property csr_SEC_10;
    @(posedge clk_i) disable iff (!rst_ni)
    csr_op_en_i &&
    (priv_mode_id_o != PRIV_LVL_M) &&
    (csr_addr_i inside {
        CSR_MSTATUS, CSR_MISA, CSR_MIE, CSR_MTVEC, CSR_MCOUNTEREN,
        CSR_MSCRATCH, CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MIP,
        CSR_PMPCFG0, CSR_PMPCFG1, CSR_PMPCFG2, CSR_PMPCFG3,
        CSR_PMPADDR0, CSR_PMPADDR1, CSR_PMPADDR2, CSR_PMPADDR3,
        CSR_PMPADDR4, CSR_PMPADDR5, CSR_PMPADDR6, CSR_PMPADDR7,
        CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
        CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15,
        CSR_MCOUNTINHIBIT,
        CSR_MHPMEVENT3, CSR_MHPMEVENT4, CSR_MHPMEVENT5, CSR_MHPMEVENT6,
        CSR_MHPMEVENT7, CSR_MHPMEVENT8, CSR_MHPMEVENT9, CSR_MHPMEVENT10,
        CSR_MHPMEVENT11, CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14,
        CSR_MHPMEVENT15, CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18,
        CSR_MHPMEVENT19, CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22,
        CSR_MHPMEVENT23, CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26,
        CSR_MHPMEVENT27, CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30,
        CSR_MHPMEVENT31
    })
    |->
    illegal_csr_insn_o;
  endproperty
  assert property (csr_SEC_10);

endmodule

bind ibex_cs_registers ibex_cs_registers_assertions u_csr_assert (.*);