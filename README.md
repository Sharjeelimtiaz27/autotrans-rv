# ai-autotrans-rv

**AI-AutoTrans: AI-Assisted Automatic Translation of Security Assertions for RISC-V Processors**

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
(Chuah et al.) and automatically translates them to Ibex RTL using an
**RV-SigEx**-grounded fixed-template approach with Claude Code CLI, validated
end-to-end by QuestaSim compilation and JasperGold FPV.

**Stages 2–5 (quality ranking, Trojan evaluation, refinement, validation)
are out of scope for this paper and belong to the downstream journal paper.**

---

## Three Contributions

1. **LLM-assisted assertion translation pipeline** — **RV-SigEx**-grounded,
   fixed-template, reproducible. Same RTL + same source assertion = same
   translated SVA every run.

2. **TAR (Translation Acceptance Rate) metric** — per-module measure of
   auto-translated assertions validated by QuestaSim compile + JasperGold
   FPV (Proven + non-vacuous), without manual fixing.

3. **Cross-architecture translation case study: NS31A → Ibex** — 1146
   NS31A properties across 9 security modules.

---

## Pipeline (Stage 1 — 4 steps)

```
RTL (Ibex) + NS31A CSV + prompt template (seq/comb)
    │
    ▼ 1A: parse_rtl.py (RV-SigEx — regex-based SV parser)
signals.json
    │
    ▼ 1B: translate.py (Claude Code CLI)
    │     inputs: signals.json + prompt template + NS31A CSV
assertions/MODULE_bind.sv  +  TAR log
    │
    ▼ 1C: validate_compile.py (QuestaSim, max 3 retries)
compiled bind file
    │
    ▼ 1D: validate_fpv.py (JasperGold FPV — Proven + non-vacuous)
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
├── scripts/                         ← Python pipeline scripts
│   ├── run_step1.py                 ← master orchestrator
│   ├── parse_rtl.py                 ← 1A: RV-SigEx (regex-based SV parser)
│   ├── translate.py                 ← 1B: Claude Code CLI translation
│   ├── validate_compile.py          ← 1C: QuestaSim compile loop
│   ├── validate_fpv.py              ← 1D: JasperGold FPV baseline
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
├── results/
│   ├── signals/                     ← MODULE_signals.json (parser output, gitignored)
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
python scripts/run_step1.py --module pmp --mode local
python scripts/run_step1.py --module csr --mode local

# Server: compile + FPV (QuestaSim + JasperGold licences required)
git pull
python scripts/run_step1.py --module pmp --mode server

# All 9 modules
python scripts/run_step1.py --all-modules

# Status check
python scripts/run_step1.py --status
```

---

## Laptop + Server Workflow

```bash
# Laptop (parse + translate — no licences)
python scripts/run_step1.py --module csr --mode local
git add assertions/ logs/
git commit -m "ATS local: csr translated"
git push

# Server (QuestaSim + JasperGold)
git pull
python scripts/run_step1.py --module csr --mode server
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

## RV-SigEx — RISC-V Signal Extractor

`scripts/parse_rtl.py` implements **RV-SigEx**, a regex-based SystemVerilog
signal extractor developed for this pipeline.

**What it extracts from any SV module:**
- Port declarations (inputs/outputs) with width and direction
- Internal signals (logic/wire/reg and typedef'd enum/struct variables)
- Parameters
- Package types (typedef enum/struct from ibex_pkg.sv), filtered per module
- Connectivity (assign statements + always_comb block assignments)

**Validated on Ibex (9 modules) — signal counts:**

| Module | RTL File | Type | Inputs | Outputs | Internals | Connectivity | PkgTypes |
|--------|----------|------|--------|---------|-----------|--------------|----------|
| pmp | ibex_pmp.sv | combinational | 7 | 1 | 12 | 2 | 4 |
| csr | ibex_cs_registers.sv | sequential | 44 | 27 | 109 | 161 | 9 |
| do/eti/cf/mt | ibex_controller.sv | sequential | 38 | 27 | 39 | 55 | 7 |
| ma | ibex_load_store_unit.sv | sequential | 13 | 18 | 20 | 58 | 0 |
| ie | ibex_id_stage.sv + ibex_ex_block.sv | sequential | 64 | 77 | 89 | 144 | 15 |
| ru | ibex_wb_stage.sv | sequential | 15 | 15 | 18 | 36 | 1 |

Full stats: [`results/signals/parser_stats.txt`](results/signals/parser_stats.txt)

**Reproducibility:** `git diff results/signals/` = empty on every re-run.
Same RTL input always produces byte-identical `signals.json`.

**General-purpose usage:**
```bash
python scripts/parse_rtl.py --sv-file path/to/any_module.sv
python scripts/parse_rtl.py --sv-file path/to/any_module.sv --pkg-file path/to/pkg.sv
```

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
  title     = {{AI}-{AutoTrans}: {AI}-Assisted Automatic Translation of
               Security Assertions for {RISC-V} Processors},
  author    = {Imtiaz, Sharjeel and Reinsalu, Uljana and Ghasempouri, Tara},
  booktitle = {Baltic Electronic Conference (BEC)},
  year      = {2026}
}
```

---

## License

MIT — see [LICENSE](LICENSE) file.

**Contact:** sharjeel.imtiaz@taltech.ee
