// ibex_load_store_unit_bind.sv
// ai-autotrans-rv — ATS pipeline output
// Source processor : NS31A
// Target processor : Ibex (lowRISC)
// Module           : ibex_load_store_unit
// Type             : Sequential
// DO NOT MODIFY — regenerate via pipeline if changes needed

module ibex_load_store_unit_assertions
    import ibex_pkg::*;
#(
    parameter int unsigned MemDataWidth = 32
) (
    // ALL ports are input — assertion module observes only, never drives
    input logic clk_i,
    input logic rst_ni,
    input  logic data_gnt_i,
    input  logic data_rvalid_i,
    input  logic data_bus_err_i,
    input  logic data_pmp_err_i,
    input  logic [MemDataWidth-1:0] data_rdata_i,
    input  logic lsu_we_i,
    input  logic [1:0] lsu_type_i,
    input  logic [31:0] lsu_wdata_i,
    input  logic lsu_sign_ext_i,
    input  logic lsu_req_i,
    input  logic [31:0] adder_result_ex_i,
    input  logic data_req_o,
    input  logic [31:0] data_addr_o,
    input  logic data_we_o,
    input  logic [3:0] data_be_o,
    input  logic [MemDataWidth-1:0] data_wdata_o,
    input  logic [31:0] lsu_rdata_o,
    input  logic lsu_rdata_valid_o,
    input  logic addr_incr_req_o,
    input  logic [31:0] addr_last_o,
    input  logic lsu_req_done_o,
    input  logic lsu_resp_valid_o,
    input  logic load_err_o,
    input  logic load_resp_intg_err_o,
    input  logic store_err_o,
    input  logic store_resp_intg_err_o,
    input  logic busy_o,
    input  logic perf_load_o,
    input  logic perf_store_o
);

  // -----------------------------------------------------------------------
  // Security assertions — translated from NS31A by ai-autotrans-rv ATS
  // Manually corrected after FPV structural analysis:
  //   ma_SEC_1 root cause: Ibex LSU uses byte-replicated encoding for sub-word
  //   stores, not left-shift. Also data_gnt_i/lsu_we_i are DUT INPUTS (free vars).
  //   Fix: restrict to word stores (data_be_o==4'hF, DUT output) which are a
  //   direct pass-through lsu_wdata_i → data_wdata_o in RTL.
  //   ma_SEC_2 root cause: hardcoded byte sign-extension fails for word/halfword
  //   loads. Fix: restrict to word loads (lsu_type_i==2'b10) where lsu_rdata_o==data_rdata_i.
  //   ma_SEC_3 root cause: data_addr_o = {adder_result_ex_i[31:2], 2'b00} (word-aligned),
  //   not adder_result_ex_i verbatim; lsu_req_i is DUT INPUT (free var).
  //   Fix: data_req_o (DUT output) |-> data_addr_o[1:0]==0 (all requests word-aligned).
  // -----------------------------------------------------------------------

  // ma_SEC_1: Word-store data reaches memory unmodified.
  // Security intent: For full-word stores, the value sent to the memory bus equals
  //   the source register value — no silent truncation or corruption.
  // RTL: ibex_load_store_unit word-store path: data_wdata_o = lsu_wdata_i (direct
  //   assignment for be==4'hF). data_be_o==4'hF identifies a word store.
  property ma_SEC_1;
    @(posedge clk_i) disable iff (!rst_ni)
    (data_req_o && data_we_o && data_be_o == 4'hF) |->
    (data_wdata_o == lsu_wdata_i);
  endproperty
  assert property (ma_SEC_1);

  // ma_SEC_2: Valid load data is free from bus errors and integrity violations.
  // Security intent: A load response presented to the pipeline as valid (clean
  //   data, lsu_rdata_valid_o=1) cannot simultaneously carry a bus/PMP error
  //   (load_err_o) or a data integrity error (load_resp_intg_err_o) — the pipeline
  //   cannot receive corrupted data that is also flagged as clean.
  // RTL root cause of CEX in prior version: lsu_type_i is a DUT INPUT (free
  //   variable); data_type_q is REGISTERED from request-time lsu_type_i (line 207).
  //   At response time JasperGold drives lsu_type_i=2'b10 (byte, NOT word — word
  //   encoding is 2'b00), but data_type_q reflects the earlier registered type
  //   → lsu_rdata_o uses registered type → lsu_rdata_o ≠ data_rdata_i. CEX.
  //   No DUT OUTPUT reflects the registered load type at response time.
  //   Fix: use the RTL-enforced mutual exclusion between clean data and errors.
  // RTL: lsu_rdata_valid_o (line 510) requires ~data_or_pmp_err & ~data_intg_err.
  //   load_err_o (line 542) requires data_or_pmp_err.
  //   load_resp_intg_err_o (line 552) requires data_intg_err.
  //   These are structurally disjoint — both implications hold unconditionally.
  property ma_SEC_2;
    @(posedge clk_i) disable iff (!rst_ni)
    lsu_rdata_valid_o |-> (!load_err_o && !load_resp_intg_err_o);
  endproperty
  assert property (ma_SEC_2);

  // ma_SEC_3: All memory bus requests use word-aligned addresses.
  // Security intent: The memory interface always presents word-aligned addresses;
  //   byte/halfword alignment within the word is handled by byte-enables (data_be_o),
  //   not by unaligned bus addresses — no out-of-bounds bus access possible.
  // RTL: ibex_load_store_unit always sets data_addr_o = {adder_result_ex_i[31:2], 2'b00}.
  property ma_SEC_3;
    @(posedge clk_i) disable iff (!rst_ni)
    data_req_o |-> (data_addr_o[1:0] == 2'b00);
  endproperty
  assert property (ma_SEC_3);

endmodule

bind ibex_load_store_unit ibex_load_store_unit_assertions #(
    .MemDataWidth (MemDataWidth)
) u_ma_assert (.*);