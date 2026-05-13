// ibex_pmp_bind.sv
// ai-autotrans-rv -- ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational
//
// QuestaSim 2024.3 rejects unclocked 'assert property' (vlog-1957).
// Combinational assertions use 'always_comb' + immediate 'assert' instead.
// JasperGold 2024 treats immediate assertions in procedural blocks as
// formal safety properties, so this compiles AND runs under FPV.

module ibex_pmp_assertions
    import ibex_pkg::*;
#(
    parameter int unsigned PMPGranularity = 0,
    parameter int unsigned PMPNumChan     = 2,
    parameter int unsigned PMPNumRegions  = 4
) (
    // ALL ports are input -- assertion module observes only, never drives
    input  pmp_cfg_t              csr_pmp_cfg_i    [PMPNumRegions],
    input  logic [PMP_ADDR_MSB:0] csr_pmp_addr_i   [PMPNumRegions],
    input  pmp_mseccfg_t          csr_pmp_mseccfg_i,
    input  logic                  debug_mode_i,
    input  priv_lvl_e             priv_mode_i      [PMPNumChan],
    input  logic [PMP_ADDR_MSB:0] pmp_req_addr_i   [PMPNumChan],
    input  pmp_req_e              pmp_req_type_i   [PMPNumChan],
    input  logic                  pmp_req_err_o    [PMPNumChan]
);

  // -----------------------------------------------------------------------
  // Security assertions -- translated from NS31A by ai-autotrans-rv ATS
  //
  // Correctness basis (from ibex_pmp.sv):
  //   debug_mode_allowed_access[c] = debug_mode_i
  //                                | (priv==M & !mmwp & !mml)
  //   pmp_req_err_o[c] = ~debug_mode_allowed_access[c] & access_fault_check[c]
  // Therefore when debug_mode_allowed_access[c]=1, pmp_req_err_o[c] is always 0.
  // -----------------------------------------------------------------------

  always_comb begin

    // pmp_SEC_1: Debug mode bypasses PMP on channel 0
    // NS31A: debug access must not be blocked by any PMP entry
    a_pmp_SEC_1: assert (!debug_mode_i || !pmp_req_err_o[0])
      else $error("pmp_SEC_1: debug mode must bypass PMP on channel 0");

    // pmp_SEC_2: Debug mode bypasses PMP on channel 1
    a_pmp_SEC_2: assert (!debug_mode_i || !pmp_req_err_o[1])
      else $error("pmp_SEC_2: debug mode must bypass PMP on channel 1");

    // pmp_SEC_3: M-mode bypasses PMP on channel 0 (no MMWP, no MML)
    // NS31A: machine-mode has unrestricted access unless MMWP/MML active
    a_pmp_SEC_3: assert (
      !(priv_mode_i[0] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp       &&
        !csr_pmp_mseccfg_i.mml)       || !pmp_req_err_o[0])
      else $error("pmp_SEC_3: M-mode ch0 must succeed when MMWP=0, MML=0");

    // pmp_SEC_4: M-mode bypasses PMP on channel 1 (no MMWP, no MML)
    a_pmp_SEC_4: assert (
      !(priv_mode_i[1] == PRIV_LVL_M &&
        !csr_pmp_mseccfg_i.mmwp       &&
        !csr_pmp_mseccfg_i.mml)       || !pmp_req_err_o[1])
      else $error("pmp_SEC_4: M-mode ch1 must succeed when MMWP=0, MML=0");

    // pmp_SEC_5: Combined debug+M bypass on channel 0
    // NS31A: privileged/debug access not blocked
    a_pmp_SEC_5: assert (
      !(debug_mode_i ||
        (priv_mode_i[0] == PRIV_LVL_M &&
         !csr_pmp_mseccfg_i.mmwp       &&
         !csr_pmp_mseccfg_i.mml))      || !pmp_req_err_o[0])
      else $error("pmp_SEC_5: debug or M-mode ch0 must not error");

    // pmp_SEC_6: Combined debug+M bypass on channel 1
    a_pmp_SEC_6: assert (
      !(debug_mode_i ||
        (priv_mode_i[1] == PRIV_LVL_M &&
         !csr_pmp_mseccfg_i.mmwp       &&
         !csr_pmp_mseccfg_i.mml))      || !pmp_req_err_o[1])
      else $error("pmp_SEC_6: debug or M-mode ch1 must not error");

    // pmp_SEC_7: M-mode READ succeeds on channel 0 (no MMWP/MML)
    // NS31A: M-mode read access must not be restricted by unlocked PMP
    a_pmp_SEC_7: assert (
      !(priv_mode_i[0] == PRIV_LVL_M   &&
        !csr_pmp_mseccfg_i.mmwp         &&
        !csr_pmp_mseccfg_i.mml          &&
        pmp_req_type_i[0] == PMP_ACC_READ) || !pmp_req_err_o[0])
      else $error("pmp_SEC_7: M-mode READ ch0 must succeed");

    // pmp_SEC_8: M-mode WRITE succeeds on channel 0 (no MMWP/MML)
    // NS31A: M-mode write access must not be restricted by unlocked PMP
    a_pmp_SEC_8: assert (
      !(priv_mode_i[0] == PRIV_LVL_M   &&
        !csr_pmp_mseccfg_i.mmwp         &&
        !csr_pmp_mseccfg_i.mml          &&
        pmp_req_type_i[0] == PMP_ACC_WRITE) || !pmp_req_err_o[0])
      else $error("pmp_SEC_8: M-mode WRITE ch0 must succeed");

    // pmp_SEC_9: M-mode EXEC succeeds on channel 0 (no MMWP/MML)
    // NS31A: M-mode execute access must not be restricted by unlocked PMP
    a_pmp_SEC_9: assert (
      !(priv_mode_i[0] == PRIV_LVL_M   &&
        !csr_pmp_mseccfg_i.mmwp         &&
        !csr_pmp_mseccfg_i.mml          &&
        pmp_req_type_i[0] == PMP_ACC_EXEC) || !pmp_req_err_o[0])
      else $error("pmp_SEC_9: M-mode EXEC ch0 must succeed");

    // pmp_SEC_10: Debug mode clears errors on all channels simultaneously
    // NS31A: debug access unrestricted across the full PMP unit
    a_pmp_SEC_10: assert (
      !debug_mode_i || (!pmp_req_err_o[0] && !pmp_req_err_o[1]))
      else $error("pmp_SEC_10: debug mode must bypass PMP on all channels");

  end

endmodule

bind ibex_pmp ibex_pmp_assertions #(
    .PMPGranularity (PMPGranularity),
    .PMPNumChan     (PMPNumChan),
    .PMPNumRegions  (PMPNumRegions)
) u_pmp_assert (
    .csr_pmp_cfg_i    (csr_pmp_cfg_i),
    .csr_pmp_addr_i   (csr_pmp_addr_i),
    .csr_pmp_mseccfg_i(csr_pmp_mseccfg_i),
    .debug_mode_i     (debug_mode_i),
    .priv_mode_i      (priv_mode_i),
    .pmp_req_addr_i   (pmp_req_addr_i),
    .pmp_req_type_i   (pmp_req_type_i),
    .pmp_req_err_o    (pmp_req_err_o)
);
