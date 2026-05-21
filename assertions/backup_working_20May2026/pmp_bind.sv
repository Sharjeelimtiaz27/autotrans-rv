// ibex_pmp_bind.sv
// ai-autotrans-rv -- ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational
//
// Key Ibex PMP semantics (ibex_pmp.sv lines 239-251):
//   debug_mode_allowed_access[c] = debug_mode_i
//                                  & ((addr[31:0] & 32'hFFFFF000) == 32'h1A110000)
//   access_fault (M-mode, no MMWP, no MML, no matching region) = 0
//   pmp_req_err_o[c] = ~debug_mode_allowed_access[c] & access_fault_check_res[c]
//
// NS31A assumed unconditional debug/M-mode bypass.
// Ibex restricts debug bypass to the Debug Module address range
// (0x1A110000-0x1A110FFF, mask 0xFFFFF000).
// M-mode bypass holds only when no PMP region is active (all modes OFF).

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

  always_comb begin

    // pmp_SEC_1: Debug mode + DM address range (0x1A110xxx) bypasses PMP ch0
    // From RTL: debug_mode_allowed_access[0] = debug_mode_i & (addr & 0xFFFFF000 == 0x1A110000)
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
    // From RTL: all regions OFF => region_match_all=0 => access_fault=0 for M-mode
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
    // MML=1 would deny unmatched EXEC for M-mode; explicitly require MML=0
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

    // pmp_SEC_10: Debug+DM on ch0 never errors (restatement of SEC_1, single channel)
    a_pmp_SEC_10: assert (
      !(debug_mode_i &&
        ((pmp_req_addr_i[0][31:0] & 32'hFFFFF000) == 32'h1A110000)) ||
      !pmp_req_err_o[0])
      else $error("pmp_SEC_10: debug+DM ch0 must never error");

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
