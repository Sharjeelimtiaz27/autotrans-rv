// ibex_pmp_bind.sv
// ai-autotrans-rv -- ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational

module ibex_pmp_assertions
    import ibex_pkg::*;
#(
    parameter int unsigned PMPGranularity = 0,
    parameter int unsigned PMPNumChan     = 2,
    parameter int unsigned PMPNumRegions  = 4
) (
    // ALL ports are input -- assertion module observes only, never drives
    // NO clock or reset -- combinational module
    // Port types mirror ibex_pmp exactly (import ibex_pkg::* brings in PMP_ADDR_MSB)
    input  pmp_cfg_t     csr_pmp_cfg_i    [PMPNumRegions],
    input  logic [PMP_ADDR_MSB:0] csr_pmp_addr_i   [PMPNumRegions],
    input  pmp_mseccfg_t csr_pmp_mseccfg_i,
    input  logic         debug_mode_i,
    input  priv_lvl_e    priv_mode_i      [PMPNumChan],
    input  logic [PMP_ADDR_MSB:0] pmp_req_addr_i   [PMPNumChan],
    input  pmp_req_e     pmp_req_type_i   [PMPNumChan],
    input  logic         pmp_req_err_o    [PMPNumChan]
);

  // -----------------------------------------------------------------------
  // Security assertions -- translated from NS31A by ai-autotrans-rv ATS
  // Combinational: generate blocks at module scope, no temporal operators.
  // All properties use port signals only.
  // Key correctness fact used: debug_mode_i and M-mode (without MMWP/MML)
  // both set debug_mode_allowed_access=1, which forces pmp_req_err_o=0.
  // -----------------------------------------------------------------------

  // pmp_SEC_1: Debug mode bypasses PMP for channel 0
  // NS31A: debug access must not be blocked by PMP -> Ibex: debug_mode_i forces no error
  assert property (debug_mode_i |-> !pmp_req_err_o[0])
    else $error("pmp_SEC_1: debug mode must bypass PMP on channel 0");

  // pmp_SEC_2: Debug mode bypasses PMP for channel 1
  // NS31A: debug access must not be blocked -> Ibex: debug_mode_i forces no error
  assert property (debug_mode_i |-> !pmp_req_err_o[1])
    else $error("pmp_SEC_2: debug mode must bypass PMP on channel 1");

  // pmp_SEC_3: M-mode bypass -- channel 0 (no MMWP, no MML)
  // NS31A: M-mode has full access unless restricted -> Ibex: M without MMWP/MML never errors
  assert property (
    (priv_mode_i[0] == PRIV_LVL_M &&
     !csr_pmp_mseccfg_i.mmwp      &&
     !csr_pmp_mseccfg_i.mml)      |-> !pmp_req_err_o[0])
    else $error("pmp_SEC_3: M-mode ch0 must succeed when MMWP=0 and MML=0");

  // pmp_SEC_4: M-mode bypass -- channel 1 (no MMWP, no MML)
  // NS31A: M-mode has full access unless restricted -> Ibex: same rule for channel 1
  assert property (
    (priv_mode_i[1] == PRIV_LVL_M &&
     !csr_pmp_mseccfg_i.mmwp      &&
     !csr_pmp_mseccfg_i.mml)      |-> !pmp_req_err_o[1])
    else $error("pmp_SEC_4: M-mode ch1 must succeed when MMWP=0 and MML=0");

  // pmp_SEC_5: pmp_req_err_o[0] is always fully driven (no X/Z)
  // NS31A: PMP must produce a definite allow/deny decision -> Ibex: output always valid
  assert property (!$isunknown(pmp_req_err_o[0]))
    else $error("pmp_SEC_5: pmp_req_err_o[0] must never be X or Z");

  // pmp_SEC_6: pmp_req_err_o[1] is always fully driven (no X/Z)
  // NS31A: PMP must produce a definite allow/deny decision -> Ibex: output always valid
  assert property (!$isunknown(pmp_req_err_o[1]))
    else $error("pmp_SEC_6: pmp_req_err_o[1] must never be X or Z");

  // pmp_SEC_7: M-mode READ request on channel 0 succeeds without MMWP/MML
  // NS31A: M-mode READ not blocked by unlocked PMP -> Ibex: M+READ+no-restrict = no error
  assert property (
    (priv_mode_i[0] == PRIV_LVL_M &&
     !csr_pmp_mseccfg_i.mmwp      &&
     !csr_pmp_mseccfg_i.mml       &&
     pmp_req_type_i[0] == PMP_ACC_READ) |-> !pmp_req_err_o[0])
    else $error("pmp_SEC_7: M-mode READ ch0 must not error without MMWP/MML");

  // pmp_SEC_8: M-mode WRITE request on channel 0 succeeds without MMWP/MML
  // NS31A: M-mode WRITE not blocked -> Ibex: M+WRITE+no-restrict = no error
  assert property (
    (priv_mode_i[0] == PRIV_LVL_M &&
     !csr_pmp_mseccfg_i.mmwp      &&
     !csr_pmp_mseccfg_i.mml       &&
     pmp_req_type_i[0] == PMP_ACC_WRITE) |-> !pmp_req_err_o[0])
    else $error("pmp_SEC_8: M-mode WRITE ch0 must not error without MMWP/MML");

  // pmp_SEC_9: M-mode EXEC request on channel 0 succeeds without MMWP/MML
  // NS31A: M-mode EXEC not blocked -> Ibex: M+EXEC+no-restrict = no error
  assert property (
    (priv_mode_i[0] == PRIV_LVL_M &&
     !csr_pmp_mseccfg_i.mmwp      &&
     !csr_pmp_mseccfg_i.mml       &&
     pmp_req_type_i[0] == PMP_ACC_EXEC) |-> !pmp_req_err_o[0])
    else $error("pmp_SEC_9: M-mode EXEC ch0 must not error without MMWP/MML");

  // pmp_SEC_10: Debug mode bypasses PMP on both channels simultaneously
  // NS31A: debug access unrestricted across all channels -> Ibex: debug clears all errors
  assert property (debug_mode_i |-> (!pmp_req_err_o[0] && !pmp_req_err_o[1]))
    else $error("pmp_SEC_10: debug mode must bypass PMP on all channels");

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
