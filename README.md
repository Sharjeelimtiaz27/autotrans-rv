# ai-autotrans-rv

**Automated LLM-Assisted Translation of Security Assertions for RISC-V Processors**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![Venue: BEC 2026](https://img.shields.io/badge/venue-BEC%202026-orange.svg)]()

> **Venue:** Baltic Electronic Conference (BEC) 2026 — 6-page paper
> **Submission deadline:** 27 May 2026
> **Authors:** S. Imtiaz, U. Reinsalu, T. Ghasempouri — TalTech, Grant PSG837

---

## Overview

This repository implements **Stage 1 (Assertion Translation Stage)** of a
larger formal security verification flow for RISC-V processors.

The pipeline takes 1146 NS31A security assertions from MEMOCODE 2023
(Chuah et al.) and automatically translates them to Ibex RTL using a
PyVerilog-grounded fixed-template approach with Claude Code CLI, validated
end-to-end by QuestaSim compilation and JasperGold FPV.

**Stages 2–5 (quality ranking, Trojan evaluation, refinement, validation)
are out of scope for this paper and belong to the downstream journal paper.**

---

## Three Contributions

1. **LLM-assisted assertion translation pipeline** — PyVerilog-grounded,
   fixed-template, reproducible. Same RTL + same source assertion = same
   translated SVA every run.

2. **TAR (Translation Acceptance Rate) metric** — per-module measure of
   auto-translated assertions validated by QuestaSim compile + JasperGold
   FPV (Proven + non-vacuous), without manual fixing.

3. **Cross-architecture translation case study: NS31A → Ibex** — 1146
   NS31A properties across 9 security modules.

---

## Pipeline (Stage 1 — 6 sub-steps)

```
RTL (Ibex)
    │
    ▼ 1A: parse_rtl.py (pyverilog)
signals.json
    │
    ▼ 1B: build_prompt.py
final_prompt_MODULE.txt
    │
    ▼ 1C: translate.py (Claude Code CLI)
SVA bind file candidate  +  TAR log
    │
    ▼ 1D: validate_compile.py (QuestaSim, max 3 retries)
compiled bind file
    │
    ▼ 1E: build_wrapper.py
assertions/translated/MODULE_bind.sv
    │
    ▼ 1F: validate_fpv.py (JasperGold FPV — Proven + non-vacuous)
results/step1/MODULE_fpv_baseline.txt
```

**CEX on clean RTL = translation error → retry.** This is not Trojan detection.

---

## Ibex Security Modules

| Module | RTL File | Type | Bind File |
|--------|----------|------|-----------|
| PMP | `ibex_pmp.sv` | Combinational | `ibex_pmp_bind.sv` |
| CSR | `ibex_cs_registers.sv` | Sequential | `ibex_csr_bind.sv` |
| DO | `ibex_controller.sv` | Sequential | `ibex_controller_do_bind.sv` |
| ETI | `ibex_controller.sv` | Sequential | `ibex_controller_eti_bind.sv` |
| CF | `ibex_controller.sv` | Sequential | `ibex_controller_cf_bind.sv` |
| MT | `ibex_controller.sv` | Sequential | `ibex_controller_mt_bind.sv` |
| MA | `ibex_load_store_unit.sv` | Sequential | `ibex_lsu_bind.sv` |
| IE | `ibex_id_stage.sv` + `ibex_ex_block.sv` | Sequential | `ibex_id_bind.sv` / `ibex_ex_bind.sv` |
| RU | `ibex_wb_stage.sv` | Sequential | `ibex_wb_bind.sv` |

`ibex_controller.sv` serves 4 logical modules (DO, ETI, CF, MT).
`ibex_csr.sv` is a sub-module of CSR — ignored.
PMP is combinational — no `@(posedge)`, `##N`, or `$past()`.
Clock: `clk_i`. Reset: `rst_ni` (active-low).

---

## Repository Structure

```
ai-autotrans-rv/
├── README.md
├── requirements.txt                 ← pyverilog, pandas
│
├── templates/                       ← FIXED SVA skeleton templates (input)
│   ├── sequential_template.sv
│   └── combinational_template.sv
│
├── prompts/                         ← FIXED Claude instruction templates (input)
│   ├── sequential_prompt.txt
│   └── combinational_prompt.txt
│
├── pipeline/                        ← Python scripts + runtime data
│   ├── run_step1.py                 ← master orchestrator
│   ├── parse_rtl.py                 ← 1A: pyverilog RTL parser
│   ├── build_prompt.py              ← 1B: prompt builder
│   ├── translate.py                 ← 1C: Claude Code CLI
│   ├── validate_compile.py          ← 1D: QuestaSim compile loop
│   ├── build_wrapper.py             ← 1E: bind wrapper
│   ├── validate_fpv.py              ← 1F: JasperGold FPV baseline
│   ├── signals/                     ← MODULE_signals.json (gitignored)
│   └── logs/                        ← MODULE_tar_log.json (TAR data)
│
├── rtl/
│   └── ibex/
│       ├── original/                ← clean Ibex RTL (parser input — never modify)
│       └── trojaned_rtl/            ← trojaned RTL for assertion testing
│
├── assertion_dataset/               ← NS31A source CSV files (one per module)
│
├── assertions/                      ← SVA bind files (pipeline output)
│
├── jasper_tcl/                      ← TCL scripts for JasperGold FPV + QuestaSim
│
├── results/
│   └── step1/                       ← FPV reports, vacuity, COV files
│
└── errors/
    └── archive/                     ← QuestaSim + JasperGold error logs (NEVER DELETE)
```

---

## Quick Start

```bash
git clone https://github.com/Sharjeelimtiaz27/ai-autotrans-rv
cd ai-autotrans-rv
pip install pyverilog pandas

# Place Ibex RTL in rtl/ibex/original/ (read-only)
# Place NS31A CSVs in assertion_dataset/

# Laptop: parse + translate (no licences needed)
python pipeline/run_step1.py --module pmp --mode local
python pipeline/run_step1.py --module csr --mode local

# Server: compile + FPV (QuestaSim + JasperGold licences required)
git pull
python pipeline/run_step1.py --module pmp --mode server

# All 9 modules
python pipeline/run_step1.py --all-modules

# Status check
python pipeline/run_step1.py --status

# Compute metrics
python metrics/compute_tar.py
python metrics/compute_satr.py
```

---

## Laptop + Server Workflow

```bash
# Laptop (parse + translate — no licences)
python pipeline/run_step1.py --module csr --mode local
git add pipeline/logs/ assertions/translated/
git commit -m "ATS local: csr translated"
git push

# Server (QuestaSim + JasperGold)
git pull
python pipeline/run_step1.py --module csr --mode server
git add results/ errors/
git commit -m "ATS server: csr validated"
git push
```

---

## Metrics

| Metric | Formula | Scope |
|--------|---------|-------|
| TAR (novel) | `auto_accepted / total_ns31a_signals × 100` | Per module |
| SATR | `validated_assertions / total_source_assertions × 100` | Aggregate |
| Reproducibility | `diff` of two independent pipeline runs = empty | Pipeline-level |

All other metrics (AQS, AER, SAPC, TCFC, TDER, WTDR, AAD) belong to
the downstream journal paper and are out of scope here.

---

## Requirements

- Python 3.10+ with `pyverilog` and `pandas`
- Claude Code CLI (authenticated — uses existing Claude subscription)
- QuestaSim (compile validation — server only)
- JasperGold FPV licence (formal verification — server only)

**No GPU. No model training. No extra API cost beyond Claude Code subscription.**

---

## Relation to Other Papers

| Paper | Role |
|-------|------|
| ISCAS (our group) | Upstream context — cited in §1 |
| Chuah MEMOCODE 2023 | Source of NS31A assertion corpus |
| AutoAssert/TrustAssert DATE 2026 | Different problem (generation, not translation) |
| SecMetric journal paper | Downstream companion — picks up Stages 2-5 |

---

## Acknowledgments

Built on the **lowRISC Ibex** RISC-V processor (Apache 2.0).
NS31A assertion corpus from **Chuah et al., MEMOCODE 2023**.
Funded by the Estonian Research Council grant **PSG837**.

---

## Citation

```bibtex
@inproceedings{imtiaz2026bec,
  title     = {Automated {LLM}-Assisted Translation of Security Assertions
               for {RISC-V} Processors},
  author    = {Imtiaz, Sharjeel and Reinsalu, Uljana and Ghasempouri, Tara},
  booktitle = {Baltic Electronic Conference (BEC)},
  year      = {2026}
}
```

---

## License

MIT — see [LICENSE](LICENSE) file.

**Contact:** sharjeel.imtiaz@taltech.ee
