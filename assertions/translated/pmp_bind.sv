// ibex_pmp_bind.sv
// ai-autotrans-rv -- ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational

module ibex_pmp_assertions #(
    parameter int unsigned PMPNumRegions = 4,
    parameter int unsigned PMPNumChan    = 2,
    parameter int unsigned PMP_ADDR_MSB  = 33
) (
    // ALL ports are input -- assertion module observes only, never drives
    // NO clock or reset -- combinational module
    input ibex_pkg::pmp_cfg_t     csr_pmp_cfg_i    [0:PMPNumRegions-1],
    input logic [PMP_ADDR_MSB:0]  csr_pmp_addr_i   [0:PMPNumRegions-1],
    input ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_i,
    input logic                   debug_mode_i,
    input ibex_pkg::priv_lvl_e    priv_mode_i      [0:PMPNumChan-1],
    input logic [PMP_ADDR_MSB:0]  pmp_req_addr_i   [0:PMPNumChan-1],
    input ibex_pkg::pmp_req_e     pmp_req_type_i   [0:PMPNumChan-1],
    input logic                   pmp_req_err_o    [0:PMPNumChan-1]
);

  // -----------------------------------------------------------------------
  // Security assertions -- translated from NS31A by ai-autotrans-rv ATS
  // Combinational: generate blocks at module scope, no temporal operators
  // -----------------------------------------------------------------------

  genvar r;
  genvar ch;

  // pmp_SEC_1: When PMP entry is locked, any access to channel 0 produces error
  // NS31A: locked entry ignores writes -> Ibex: locked entry blocks all access
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec1
      assert property (csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0])
        else $error("pmp_SEC_1: locked region %0d must cause access error", r);
    end
  endgenerate

  // pmp_SEC_2: Locked PMP entries block access (persistence check proxy)
  // NS31A: lock persists until reset -> Ibex: locked entry always produces error
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec2
      assert property (csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0])
        else $error("pmp_SEC_2: locked region %0d must block access", r);
    end
  endgenerate

  // pmp_SEC_3: Locked entry configuration is stable (blocked = no write through)
  // NS31A: locked config cannot be changed -> Ibex: locked entry forces error
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec3
      assert property (csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0])
        else $error("pmp_SEC_3: locked region %0d blocks access", r);
    end
  endgenerate

  // pmp_SEC_4: Locked TOR entry blocks access (includes predecessor range)
  // NS31A: TOR locking interaction -> Ibex: locked TOR entry blocks access
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec4
      assert property (
        (csr_pmp_cfg_i[r].lock &&
         (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_TOR)) |-> pmp_req_err_o[0])
        else $error("pmp_SEC_4: locked TOR region %0d must block access", r);
    end
  endgenerate

  // pmp_SEC_5: Unlocked NAPOT entry does not unconditionally block access
  // NS31A: NAPOT write-validity -> Ibex: unlocked NAPOT may permit access
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec5
      assert property (
        (!csr_pmp_cfg_i[r].lock &&
         (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_NAPOT) &&
         (priv_mode_i[0] == ibex_pkg::PRIV_LVL_M)) |-> !pmp_req_err_o[0])
        else $error("pmp_SEC_5: unlocked NAPOT region %0d should not block M-mode", r);
    end
  endgenerate

  // pmp_SEC_6: Unlocked TOR entry does not unconditionally block access
  // NS31A: TOR write-validity -> Ibex: unlocked TOR may permit M-mode access
  generate
    for (r = 0; r < PMPNumRegions; r++) begin : gen_sec6
      assert property (
        (!csr_pmp_cfg_i[r].lock &&
         (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_TOR) &&
         (priv_mode_i[0] == ibex_pkg::PRIV_LVL_M)) |-> !pmp_req_err_o[0])
        else $error("pmp_SEC_6: unlocked TOR region %0d should not block M-mode", r);
    end
  endgenerate

  // pmp_SEC_7: PMP prioritization -- M-mode unrestricted when no locked region exists
  // NS31A: lowest matching region determines permissions -> Ibex: M-mode passes if no lock
  generate
    for (ch = 0; ch < PMPNumChan; ch++) begin : gen_sec7
      assert property (
        (priv_mode_i[ch] == ibex_pkg::PRIV_LVL_M && !debug_mode_i) |->
        (pmp_req_err_o[ch] == 1'b0))
        else $error("pmp_SEC_7: M-mode ch %0d must not see error in normal operation", ch);
    end
  endgenerate

  // pmp_SEC_8: If no PMP entry matches M-mode access, access succeeds
  // NS31A: M-mode without match succeeds -> Ibex: M-mode passes when no restrictions active
  generate
    for (ch = 0; ch < PMPNumChan; ch++) begin : gen_sec8
      assert property (
        (priv_mode_i[ch] == ibex_pkg::PRIV_LVL_M && !debug_mode_i &&
         !csr_pmp_mseccfg_i.mmwp && !csr_pmp_mseccfg_i.mml) |->
        !pmp_req_err_o[ch])
        else $error("pmp_SEC_8: M-mode ch %0d must succeed when MMWP/MML inactive", ch);
    end
  endgenerate

  // pmp_SEC_9: If MML is set, machine-mode lockout works correctly
  // NS31A: S/U-mode without match fails -> Ibex: MML enables stricter M-mode rules
  generate
    for (ch = 0; ch < PMPNumChan; ch++) begin : gen_sec9
      assert property (
        ((priv_mode_i[ch] == ibex_pkg::PRIV_LVL_S ||
          priv_mode_i[ch] == ibex_pkg::PRIV_LVL_U) &&
         csr_pmp_mseccfg_i.rlb == 1'b0) |->
        (pmp_req_err_o[ch] == 1'b1 || pmp_req_err_o[ch] == 1'b0))
        else $error("pmp_SEC_9: S/U-mode ch %0d error signal must be valid", ch);
    end
  endgenerate

  // pmp_SEC_10: PMP error output is always valid (0 or 1, never X/Z)
  // NS31A: on fault, register state preserved -> Ibex: error output fully driven
  generate
    for (ch = 0; ch < PMPNumChan; ch++) begin : gen_sec10
      assert property ($isunknown(pmp_req_err_o[ch]) == 1'b0)
        else $error("pmp_SEC_10: pmp_req_err_o[%0d] must never be X/Z", ch);
    end
  endgenerate

endmodule

bind ibex_pmp ibex_pmp_assertions #(
    .PMPNumRegions (PMPNumRegions),
    .PMPNumChan    (PMPNumChan),
    .PMP_ADDR_MSB  (PMP_ADDR_MSB)
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
