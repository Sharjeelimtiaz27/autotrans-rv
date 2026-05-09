// ibex_pmp_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_pmp_assertions (
    // --- ports matching DUT — NO clock or reset (combinational module) ---
    input  ibex_pkg::pmp_cfg_t[PMPNumRegions] csr_pmp_cfg_i,
    input  logic [PMP_ADDR_MSB:0] csr_pmp_addr_i,
    input  ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_i,
    input  logic debug_mode_i,
    input  ibex_pkg::priv_lvl_e[PMPNumChan] priv_mode_i,
    input  logic [PMP_ADDR_MSB:0] pmp_req_addr_i,
    input  ibex_pkg::pmp_req_e[PMPNumChan] pmp_req_type_i,
    output logic [PMPNumChan-1:0] pmp_req_err_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------
  // NOTE: All NS31A assertions are UNTRANSLATABLE due to:
  // 1. Combinational module constraint (no clock, reset, sequential logic)
  // 2. Missing signals (no register data, write valid, CSR write, opcode, fault signals)
  // 3. Sequential nature of assertions (require $past(), ##N, $stable())
  //
  // The only assertions that could potentially be written are purely combinational
  // checks on the available signals, but none of the NS31A assertions map to such checks.
  //
  // Available signals for potential future assertions:
  // - csr_pmp_cfg_i: PMP configuration (lock, mode, exec, write, read)
  // - csr_pmp_addr_i: PMP address registers
  // - csr_pmp_mseccfg_i: Machine security configuration (rlb, mmwp, mml)
  // - debug_mode_i: Debug mode indicator
  // - priv_mode_i: Privilege level per channel
  // - pmp_req_addr_i: Request address per channel
  // - pmp_req_type_i: Request type (exec, write, read) per channel
  // - pmp_req_err_o: PMP error output per channel
  // - region_start_addr, region_addr_mask: Region address computation
  // - region_match_gt, region_match_lt, region_match_eq, region_match_all: Region matching
  // - region_basic_perm_check, region_perm_check: Permission checks
  // - access_fault_check_res: Access fault result
  // - debug_mode_allowed_access: Debug mode access permission

  // No assertions could be translated from NS31A to Ibex PMP combinational logic.
  // All 108 NS31A assertions are flagged as untranslatable.

endmodule

bind ibex_pmp ibex_pmp_assertions u_pmp_assert (.*);