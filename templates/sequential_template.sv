// sequential_template.sv
// AutoAssert-RV — SVA bind file skeleton for SEQUENTIAL modules
// This file shows the expected output structure Claude must produce.
// All {{PLACEHOLDERS}} are filled by build_prompt.py before sending to Claude.

// {{MODULE_NAME}}_bind.sv
// AutoAssert-RV — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : {{MODULE_NAME}}
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module {{MODULE_NAME}}_assertions (
    input  logic        {{CLOCK}},
    input  logic        {{RESET}},
    // --- copy remaining ports from signals.json ---
    input  logic [31:0] example_input_i,
    output logic [31:0] example_output_o
);

  // -----------------------------------------------------------------------
  // Property 1: <describe the security invariant being checked>
  // NS31A source: <original NS31A assertion name or ID>
  // Ibex mapping: <ns31a_signal> → <ibex_signal>
  // -----------------------------------------------------------------------
  property {{MODULE_SHORT}}_SEC_1;
    @(posedge {{CLOCK}}) disable iff (!{{RESET}})
    <antecedent_condition> |-> <consequent_condition>;
  endproperty
  assert property ({{MODULE_SHORT}}_SEC_1);

  // -----------------------------------------------------------------------
  // Property 2: temporal — consequent checked N cycles after antecedent
  // -----------------------------------------------------------------------
  property {{MODULE_SHORT}}_SEC_2;
    @(posedge {{CLOCK}}) disable iff (!{{RESET}})
    <trigger_condition> |-> ##N <delayed_condition>;
  endproperty
  assert property ({{MODULE_SHORT}}_SEC_2);

  // -----------------------------------------------------------------------
  // Property 3: previous-cycle value check
  // -----------------------------------------------------------------------
  property {{MODULE_SHORT}}_SEC_3;
    @(posedge {{CLOCK}}) disable iff (!{{RESET}})
    <condition> |-> $past(<signal>) == <expected_value>;
  endproperty
  assert property ({{MODULE_SHORT}}_SEC_3);

  // -----------------------------------------------------------------------
  // ... add one block per translated NS31A assertion ...
  // -----------------------------------------------------------------------

endmodule

// Bind statement — outside and after the module
bind {{MODULE_NAME}} {{MODULE_NAME}}_assertions u_{{MODULE_SHORT}}_assert (.*);
