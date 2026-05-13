// Stub for prim_assert.sv -- suppresses OpenTitan DV infrastructure.
// Used only for QuestaSim/JasperGold compilation of security assertions.
// All assertion macros are no-ops so the RTL compiles cleanly without
// the full OpenTitan DV environment.

`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

`define ASSERT_I(_name, _prop)
`define ASSERT_INIT(_name, _prop)
`define ASSERT_INIT_NET(_name, _prop)
`define ASSERT_FINAL(_name, _prop)
`define ASSERT(_name, _prop)
`define ASSERT_NEVER(_name, _prop)
`define ASSERT_KNOWN(_name, _sig)
`define COVER(_name, _prop)
`define ASSUME(_name, _prop)
`define ASSERT_ERROR_TRIGGER_ALERT(_name, _prop, _alert)

`endif // PRIM_ASSERT_SV
