// ibex_pmp_fpv.sv
// JasperGold FPV wrapper — ai-autotrans-rv ATS pipeline
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational
//
// This wrapper instantiates ibex_pmp directly so JasperGold constrains
// pmp_req_err_o through DUT combinational logic rather than treating it
// as a free variable (which happens with bind-based FPV via PRE engine).
//
// All inputs are free variables; pmp_req_err_o is driven by the DUT.

module ibex_pmp_fpv
    import ibex_pkg::*;
#(
    parameter int unsigned DmBaseAddr     = 32'h1A110000,
    parameter int unsigned DmAddrMask     = 32'h00000FFF,
    parameter int unsigned PMPGranularity = 0,
    parameter int unsigned PMPNumChan     = 2,
    parameter int unsigned PMPNumRegions  = 4
);

  // Free inputs — JasperGold drives these unconstrained
  pmp_cfg_t              csr_pmp_cfg_i    [PMPNumRegions];
  logic [PMP_ADDR_MSB:0] csr_pmp_addr_i   [PMPNumRegions];
  pmp_mseccfg_t          csr_pmp_mseccfg_i;
  logic                  debug_mode_i;
  priv_lvl_e             priv_mode_i      [PMPNumChan];
  logic [PMP_ADDR_MSB:0] pmp_req_addr_i   [PMPNumChan];
  pmp_req_e              pmp_req_type_i   [PMPNumChan];

  // DUT output — constrained by combinational logic in ibex_pmp
  logic                  pmp_req_err_o    [PMPNumChan];

  // Instantiate the DUT
  ibex_pmp #(
      .DmBaseAddr     (DmBaseAddr),
      .DmAddrMask     (DmAddrMask),
      .PMPGranularity (PMPGranularity),
      .PMPNumChan     (PMPNumChan),
      .PMPNumRegions  (PMPNumRegions)
  ) u_dut (
      .csr_pmp_cfg_i    (csr_pmp_cfg_i),
      .csr_pmp_addr_i   (csr_pmp_addr_i),
      .csr_pmp_mseccfg_i(csr_pmp_mseccfg_i),
      .debug_mode_i     (debug_mode_i),
      .priv_mode_i      (priv_mode_i),
      .pmp_req_addr_i   (pmp_req_addr_i),
      .pmp_req_type_i   (pmp_req_type_i),
      .pmp_req_err_o    (pmp_req_err_o)
  );

  always_comb begin

    // pmp_SEC_1: Debug mode + DM address range (0x1A110xxx) bypasses PMP ch0
    // RTL: debug_mode_allowed_access[0] = debug_mode_i & ((addr & ~DmAddrMask) == DmBaseAddr)
    a_pmp_SEC_1: assert (
      !(debug_mode_i &&
        ((pmp_req_addr_i[0][31:0] & 32'hFFFFF000) == 32'h1A110000)) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_1: debug+DM range must bypass PMP ch0");

    // pmp_SEC_2: Debug mode + DM address range bypasses PMP ch1
    a_pmp_SEC_2: assert (
      !(debug_mode_i &&
        ((pmp_req_addr_i[1][31:0] & 32'hFFFFF000) == 32'h1A110000)) ||
      !pmp_req_err_o[1])
      else $error("pmp_SEC_2: debug+DM range must bypass PMP ch1");

    // pmp_SEC_3: M-mode ch0 succeeds when all 4 regions OFF, no MMWP, no MML
    a_pmp_SEC_3: assert (
      !(priv_mode_i[0] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_3: M-mode ch0 must succeed when all regions OFF");

    // pmp_SEC_4: M-mode ch1 succeeds when all 4 regions OFF, no MMWP, no MML
    a_pmp_SEC_4: assert (
      !(priv_mode_i[1] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      !pmp_req_err_o[1])
      else $error("pmp_SEC_4: M-mode ch1 must succeed when all regions OFF");

    // pmp_SEC_5: Debug+DM clears both channels simultaneously
    a_pmp_SEC_5: assert (
      !(debug_mode_i &&
        ((pmp_req_addr_i[0][31:0] & 32'hFFFFF000) == 32'h1A110000) &&
        ((pmp_req_addr_i[1][31:0] & 32'hFFFFF000) == 32'h1A110000)) ||
      (!pmp_req_err_o[0] && !pmp_req_err_o[1]))
      else $error("pmp_SEC_5: debug+DM must clear both channels");

    // pmp_SEC_6: M-mode READ ch0 succeeds when all regions OFF, no MMWP, no MML
    a_pmp_SEC_6: assert (
      !(priv_mode_i[0] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        pmp_req_type_i[0] == PMP_ACC_READ &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_6: M-mode READ ch0 must succeed when all regions OFF");

    // pmp_SEC_7: M-mode WRITE ch0 succeeds when all regions OFF, no MMWP, no MML
    a_pmp_SEC_7: assert (
      !(priv_mode_i[0] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        pmp_req_type_i[0] == PMP_ACC_WRITE &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_7: M-mode WRITE ch0 must succeed when all regions OFF");

    // pmp_SEC_8: M-mode EXEC ch0 succeeds when all regions OFF, no MMWP, no MML
    a_pmp_SEC_8: assert (
      !(priv_mode_i[0] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        pmp_req_type_i[0] == PMP_ACC_EXEC &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_8: M-mode EXEC ch0 must succeed when all regions OFF");

    // pmp_SEC_9: M-mode both channels succeed when all regions OFF, no MMWP, no MML
    a_pmp_SEC_9: assert (
      !(priv_mode_i[0] == PRIV_LVL_M && priv_mode_i[1] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml &&
        csr_pmp_cfg_i[0].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[1].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[2].mode == PMP_MODE_OFF &&
        csr_pmp_cfg_i[3].mode == PMP_MODE_OFF) ||
      (!pmp_req_err_o[0] && !pmp_req_err_o[1]))
      else $error("pmp_SEC_9: M-mode must succeed on both channels when all regions OFF");

    // pmp_SEC_10: Debug+DM on ch0 never errors (restatement of SEC_1)
    a_pmp_SEC_10: assert (
      !(debug_mode_i &&
        ((pmp_req_addr_i[0][31:0] & 32'hFFFFF000) == 32'h1A110000)) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_10: debug+DM ch0 must never error");

  end

endmodule
