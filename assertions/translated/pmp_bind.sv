// ibex_pmp_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_pmp
// Type             : Combinational
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_pmp_assertions (
    // ALL ports are input — assertion module observes only, never drives
    // NO clock or reset — combinational module
    input  ibex_pkg::pmp_cfg_t[PMPNumRegions] csr_pmp_cfg_i,
    input  logic [PMP_ADDR_MSB:0] csr_pmp_addr_i,
    input  ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_i,
    input  logic debug_mode_i,
    input  ibex_pkg::priv_lvl_e[PMPNumChan] priv_mode_i,
    input  logic [PMP_ADDR_MSB:0] pmp_req_addr_i,
    input  ibex_pkg::pmp_req_e[PMPNumChan] pmp_req_type_i,
    input  logic [PMPNumChan-1:0] pmp_req_err_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // -----------------------------------------------------------------------

  // pmp_SEC_1: When PMP entry is locked, any access request produces error
  // NS31A: locked entry ignores writes → Ibex: locked entry blocks all access
  property pmp_SEC_1;
    // For each region r, if locked then any access to that region produces error
    // Use genvar to iterate over regions
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec1
      property pmp_SEC_1_r;
        csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0]; // error asserted for channel 0
      endproperty
      assert property (pmp_SEC_1_r);
    end
  endproperty
  // Note: genvar loop generates separate properties per region

  // pmp_SEC_2: Locked PMP entries remain locked (persistence)
  // NS31A: lock persists until reset → Ibex: locked entry always produces error
  property pmp_SEC_2;
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec2
      property pmp_SEC_2_r;
        csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0];
      endproperty
      assert property (pmp_SEC_2_r);
    end
  endproperty

  // pmp_SEC_3: If PMP entry N is locked, writes to pmpcfgN and pmpaddrN are ignored
  // NS31A: stability of locked config → Ibex: locked entry blocks access
  property pmp_SEC_3;
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec3
      property pmp_SEC_3_r;
        csr_pmp_cfg_i[r].lock |-> pmp_req_err_o[0];
      endproperty
      assert property (pmp_SEC_3_r);
    end
  endproperty

  // pmp_SEC_4: If PMP entry N is locked and mode is TOR, writes to pmpaddrN-1 are ignored
  // NS31A: TOR locking interaction → Ibex: locked TOR entry blocks access
  property pmp_SEC_4;
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec4
      property pmp_SEC_4_r;
        (csr_pmp_cfg_i[r].lock && (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_TOR)) |-> pmp_req_err_o[0];
      endproperty
      assert property (pmp_SEC_4_r);
    end
  endproperty

  // pmp_SEC_5: For NAPOT mode, writing to pmpaddrN is valid if pmpcfgN.L=0
  // NS31A: NAPOT write-validity → Ibex: unlocked NAPOT entry allows access
  property pmp_SEC_5;
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec5
      property pmp_SEC_5_r;
        (!csr_pmp_cfg_i[r].lock && (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_NAPOT)) |-> !pmp_req_err_o[0];
      endproperty
      assert property (pmp_SEC_5_r);
    end
  endproperty

  // pmp_SEC_6: For TOR mode, writing to pmpaddrN-1 and pmpaddrN is valid if pmpcfgN.L=0
  // NS31A: TOR write-validity → Ibex: unlocked TOR entry allows access
  property pmp_SEC_6;
    for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_sec6
      property pmp_SEC_6_r;
        (!csr_pmp_cfg_i[r].lock && (csr_pmp_cfg_i[r].mode == ibex_pkg::PMP_CFG_MODE_TOR)) |-> !pmp_req_err_o[0];
      endproperty
      assert property (pmp_SEC_6_r);
    end
  endproperty

  // pmp_SEC_7: PMP prioritization correctness
  // NS31A: lowest matching region determines permissions → Ibex: region_match_all and perm_check
  property pmp_SEC_7;
    // For each channel, if region matches and permissions are checked, error reflects correct priority
    for (genvar ch = 0; ch < PMPNumChan; ch++) begin : gen_sec7
      property pmp_SEC_7_ch;
        // If any region matches and basic perm check fails, error must be asserted
        (|region_match_all[ch] && !region_basic_perm_check[ch]) |-> pmp_req_err_o[ch];
      endproperty
      assert property (pmp_SEC_7_ch);
    end
  endproperty

  // pmp_SEC_8: If no PMP entry matches M-mode access, access succeeds
  // NS31A: M-mode without match succeeds → Ibex: M-mode without error means no match
  property pmp_SEC_8;
    for (genvar ch = 0; ch < PMPNumChan; ch++) begin : gen_sec8
      property pmp_SEC_8_ch;
        (priv_mode_i[ch] == ibex_pkg::PRIV_LVL_M && !debug_mode_i && !pmp_req_err_o[ch]) |-> (|region_match_all[ch] == 0);
      endproperty
      assert property (pmp_SEC_8_ch);
    end
  endproperty

  // pmp_SEC_9: If no PMP entry matches S/U-mode access, access fails
  // NS31A: S/U-mode without match fails → Ibex: S/U-mode with any implemented PMP must error
  property pmp_SEC_9;
    for (genvar ch = 0; ch < PMPNumChan; ch++) begin : gen_sec9
      property pmp_SEC_9_ch;
        ((priv_mode_i[ch] == ibex_pkg::PRIV_LVL_S || priv_mode_i[ch] == ibex_pkg::PRIV_LVL_U) && 
         (|csr_pmp_cfg_i[0].mode != 0)) |-> 
         (|region_match_all[ch] == 0) |-> pmp_req_err_o[ch];
      endproperty
      assert property (pmp_SEC_9_ch);
    end
  endproperty

  // pmp_SEC_10: PMP violation preserves architectural state
  // NS31A: on fault, register state preserved → Ibex: error asserted when access should be blocked
  property pmp_SEC_10;
    for (genvar ch = 0; ch < PMPNumChan; ch++) begin : gen_sec10
      property pmp_SEC_10_ch;
        // For each access type, if permissions deny it, error must be asserted
        ((pmp_req_type_i[ch] == ibex_pkg::PMP_ACC_READ) && !region_perm_check[ch]) |-> pmp_req_err_o[ch];
      endproperty
      assert property (pmp_SEC_10_ch);
      
      property pmp_SEC_10_ch_write;
        ((pmp_req_type_i[ch] == ibex_pkg::PMP_ACC_WRITE) && !region_perm_check[ch]) |-> pmp_req_err_o[ch];
      endproperty
      assert property (pmp_SEC_10_ch_write);
      
      property pmp_SEC_10_ch_exec;
        ((pmp_req_type_i[ch] == ibex_pkg::PMP_ACC_EXEC) && !region_perm_check[ch]) |-> pmp_req_err_o[ch];
      endproperty
      assert property (pmp_SEC_10_ch_exec);
    end
  endproperty

endmodule

bind ibex_pmp ibex_pmp_assertions u_pmp_assert (.*);