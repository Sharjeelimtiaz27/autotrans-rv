// combinational_template.sv
// AutoAssert-RV — SVA bind file skeleton for COMBINATIONAL modules
// This file shows the expected output structure Claude must produce.
// Used ONLY for ibex_pmp.sv — the only combinational module in Ibex.
// FORBIDDEN in this file: @(posedge), ##N, $past(), disable iff

// {{MODULE_NAME}}_bind.sv
// AutoAssert-RV — ATS pipeline output
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

  // -----------------------------------------------------------------------
  // Property 1: pure combinational implication (no temporal operators)
  // NS31A source: <original NS31A assertion name or ID>
  // Ibex mapping: <ns31a_signal> → <ibex_signal>
  // -----------------------------------------------------------------------
  property {{MODULE_SHORT}}_SEC_1;
    <combinational_antecedent> |-> <combinational_consequent>;
  endproperty
  assert property ({{MODULE_SHORT}}_SEC_1);

  // -----------------------------------------------------------------------
  // Property 2: bit-field check — inspect a specific configuration field
  // -----------------------------------------------------------------------
  property {{MODULE_SHORT}}_SEC_2;
    <field_condition> |-> <expected_output_condition>;
  endproperty
  assert property ({{MODULE_SHORT}}_SEC_2);

  // -----------------------------------------------------------------------
  // ... add one block per translated NS31A assertion ...
  // -----------------------------------------------------------------------

endmodule

// Bind statement — outside and after the module
bind {{MODULE_NAME}} {{MODULE_NAME}}_assertions u_{{MODULE_SHORT}}_assert (.*);
