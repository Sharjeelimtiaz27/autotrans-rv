//
// Author  : Sharjeel Imtiaz
//           Tallinn University of Technology (TalTech)
//
// Contact : sharjeel.imtiaz@taltech.ee
// Project : ai-autotrans-rv — BEC 2026
//
// combinational_template.sv
// ai-autotrans-rv — SVA bind file skeleton for COMBINATIONAL modules
// This file shows the expected output structure Claude must produce.
// Used ONLY for ibex_pmp.sv — the only combinational module in Ibex.
// FORBIDDEN in this file: @(posedge), ##N, $past(), disable iff

// {{MODULE_NAME}}_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : {{MODULE_NAME}}
// Type             : Combinational
// DO NOT MODIFY — regenerate via pipeline if changes needed

module {{MODULE_NAME}}_assertions (
    // --- NO clock, NO reset — combinational module ---
    // copy remaining ports from signals.json
    input  logic [33:0] csr_pmp_cfg_i,
    input  logic [31:0] csr_pmp_addr_i,
    input  logic [31:0] pmp_req_addr_i,
    output logic        pmp_req_err_o
);

  // All assertions grouped in one always_comb block.
  // Use immediate assertions only — no property/endproperty, no assert property.
  // Boolean implication A -> B expressed as !A || B.
  always_comb begin

    // -----------------------------------------------------------------------
    // Assertion 1: pure combinational implication
    // NS31A source: <original NS31A assertion name or ID>
    // Ibex mapping: <ns31a_signal> → <ibex_signal>
    // -----------------------------------------------------------------------
    a_{{MODULE_SHORT}}_SEC_1: assert (!<combinational_antecedent> || <combinational_consequent>)
      else $error("{{MODULE_SHORT}}_SEC_1: <description of violated security property>");

    // -----------------------------------------------------------------------
    // Assertion 2: bit-field check — inspect a specific configuration field
    // -----------------------------------------------------------------------
    a_{{MODULE_SHORT}}_SEC_2: assert (!<field_condition> || <expected_output_condition>)
      else $error("{{MODULE_SHORT}}_SEC_2: <description>");

    // -----------------------------------------------------------------------
    // ... add one block per translated NS31A assertion ...
    // -----------------------------------------------------------------------

  end

endmodule

// Bind statement — outside and after the module
bind {{MODULE_NAME}} {{MODULE_NAME}}_assertions u_{{MODULE_SHORT}}_assert (.*);
