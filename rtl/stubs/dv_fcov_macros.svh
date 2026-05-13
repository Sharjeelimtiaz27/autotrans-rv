// Stub for dv_fcov_macros.svh -- suppresses OpenTitan functional coverage macros.
// Used only for QuestaSim/JasperGold compilation of security assertions.

`ifndef DV_FCOV_MACROS_SVH
`define DV_FCOV_MACROS_SVH

`define DV_FCOV_SIGNAL(_type, _name, _expr)
`define DV_FCOV_SIGNAL_GEN_IF(_type, _name, _expr, _cond)

`endif // DV_FCOV_MACROS_SVH
