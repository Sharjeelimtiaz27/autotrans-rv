# AutoTrans

**AutoTrans: AI-Assisted Automatic Translation of Security Assertions for RISC-V Processors**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)

BEC 2026 — Sharjeel Imtiaz, Uljana Reinsalu, Tara Ghasempouri — TalTech

---

## Overview

AutoTrans is a fully automated pipeline for cross-architecture translation of RISC-V security
assertions. It takes the NS31A security assertion corpus (Chuah et al., MEMOCODE 2023) and
automatically translates it to lowRISC Ibex SVA bind files, validated end-to-end by QuestaSim
compilation and JasperGold Formal Property Verification.

**Results on Ibex (9 security modules, 68 NS31A groups):**
- **78% Auto TAR** — automated pipeline (Flash + Pro retries), zero human intervention
- **100% Final TAR** — after targeted manual resolution of JasperGold structural constraints
- **100% translation coverage** — every NS31A group produces at least one SVA property

---

## Four Contributions

1. **Parser-grounded prompt assembly** — a regex-based SystemVerilog signal extractor
   (`parse_rtl.py`) grounds every LLM prompt in the exact target RTL interface, eliminating
   signal hallucination without EDA infrastructure or licences. The LLM sees only signals that
   actually exist in the RTL.

2. **Reproducible deterministic translation** — a fixed SVA template plus `temperature=0.0`
   and `seed=42` enforce byte-identical prompt assembly on every run. A two-tier model
   strategy (V4-Flash for initial translation, V4-Pro for all retries) keeps cost near zero
   with no GPU and no fine-tuning.

3. **Natural-language SVA synthesis** — the pipeline generates formal SVA from English-only
   security descriptions, covering all 22 such NS31A properties with no manual authoring,
   extending beyond what prior work required formal SVA source code to translate.

4. **Industry-grade validation gate and TAR metric** — every translated assertion must pass
   QuestaSim SVA compilation (syntax) then JasperGold FPV Proven + non-vacuous (semantics)
   before counting. TAR (Translation Acceptance Rate = proven\_non\_vacuous / total\_groups)
   measures mechanically verified quality, not BLEU or self-report. Released open source.

---

## Pipeline — Two Stages

```
 INPUTS
 ══════════════════════════════════════════════════════════════════

  rtl/ibex/original/*.sv          assertion_dataset/ns31a_<MODULE>.csv
  (Ibex RTL — never modify)       (NS31A source assertions — 9 modules)
         │                                        │
         ▼                                        │
 ╔═══════════════════════════════════════════════════════════════╗
 ║  STAGE 1 — Security SVA Translation (laptop, no EDA needed)  ║
 ╚═══════════════════════════════════════════════════════════════╝
         │
         ▼
 ┌───────────────────────┐
 │   STEP 1A             │
 │   parse_rtl.py        │
 │   Regex-based SV      │
 │   signal extractor    │
 └──────────┬────────────┘
            │
            ▼
  results/signals/<MODULE>_signals.json
  (ports, internals, pkg_types)
            │
            └──────────────────────────────────────────────────┐
                                                               │
  prompts/sequential_prompt.txt                               │
  prompts/combinational_prompt.txt                            │
  (fixed templates — never modify)                            │
                                                               │
 ┌─────────────────────────────────────────────────────────────┐
 │   STEP 1B             │
 │   translate.py        │  ← build_prompt() fills all {{PLACEHOLDERS}}
 │   Prompt Assembly     │    from signals.json + CSV + fixed template
 └──────────┬────────────┘
            │
            ▼
  prompts/final/<MODULE>_final_prompt.txt
            │
            ▼
 ┌───────────────────────┐
 │   STEP 1C             │
 │   translate.py        │
 │   DeepSeek V4-Flash   │
 │   NVIDIA NIM API      │
 │   temperature = 0.0   │
 │   seed = 42           │
 └──────────┬────────────┘
            │
            ▼
  assertions/translated/<MODULE>_bind.sv
  results/logs/<MODULE>_tar_log.json
            │
            ▼
 ╔═══════════════════════════════════════════════════════════════╗
 ║  STAGE 2 — Security SVA Validation (EDA server, licences)    ║
 ╚═══════════════════════════════════════════════════════════════╝
            │
            ▼
 ┌───────────────────────┐        ┌──────────────────────────────┐
 │   STEP 2A             │  FAIL  │  DeepSeek V4-Pro retry       │
 │   validate_compile.py ├───────►│  orig. prompt + error log    │
 │   vlog -sv12compat    │        │  instruction: fix syntax     │
 │   QuestaSim compile   │        │  only, preserve logic        │
 └──────────┬────────────┘        │  max 3 retries → LOCK        │
            │ PASS                └──────────────────────────────┘
            ▼
 ┌───────────────────────┐        ┌──────────────────────────────┐
 │   STEP 2B             │  FAIL  │  DeepSeek V4-Pro retry       │
 │   validate_fpv.py     ├───────►│  orig. prompt + NS31A source │
 │   JasperGold FPV      │        │  + signal classification     │
 │   prove -all          │        │  + Ibex FPV pitfall notes    │
 │   report -vacuity     │        │  CEX: fix logic              │
 │   Proven + non-vac    │        │  Vacuous: rewrite antecedent │
 └──────────┬────────────┘        │  max 3 retries → LOCK        │
            │ ALL PASS            └──────────────────────────────┘
            ▼
  results/step1/<MODULE>_fpv_baseline.txt
  results/step1/<MODULE>_vacuity.txt
            │
            ▼
  TAR = proven_non_vacuous / total_ns31a_groups × 100
  Written to results/logs/<MODULE>_tar_log.json

 NOTES
 ══════════════════════════════════════════════════════════════════
 Stage 1 (Steps 1A–1C) runs on any laptop — no EDA tools needed.
 Stage 2 (Steps 2A–2B) requires QuestaSim + JasperGold licences (EDA server).

 LLM tier strategy:
   V4-Flash → initial translation only (Step 1C — cheap, fast)
   V4-Pro   → ALL retries at both steps (deeper RTL reasoning for
              enum scope, struct fields, port widths, FPV semantics)

 After 3 failed retries at either step: module is LOCKED (ESCALATE),
 error logs archived to errors/archive/ — never delete (paper evidence).
```

---

## Setup

### One-command check

```bash
python scripts/setup_env.py
```

### Python dependencies

```bash
python -m pip install -r requirements.txt
```

Installs: `openai`, `python-dotenv`. (`parse_rtl.py` uses only stdlib regex — no parser library needed.)

### NVIDIA NIM API key

Get a free API key at [build.nvidia.com](https://build.nvidia.com) (1000 free credits).

Create `.env` in the project root:

```
NVIDIA_API_KEY=nvapi-...your-key-here...
```

The `.env` file is gitignored — never commit it. **No GPU required.**

---

## Running the Pipeline

### Stage 1 — laptop (no EDA tools)

```bash
# All 9 modules
python scripts/run_step1.py --all-modules --mode local

# Single module
python scripts/run_step1.py --module pmp --mode local

# Individual steps
python scripts/parse_rtl.py --module pmp          # Step 1A: extract signals
python scripts/translate.py  --module pmp          # Steps 1B+1C: assemble prompt + translate
python scripts/translate.py  --module pmp --pro    # Force Pro model
python scripts/translate.py  --module pmp --dry-run  # Build prompt only, no API call
```

### Stage 2 — EDA server (QuestaSim + JasperGold)

```bash
git pull
python scripts/run_step1.py --all-modules --mode server
```

### Check pipeline status

```bash
python scripts/run_step1.py --status
```

---

## Laptop + Server Workflow

```bash
# --- LAPTOP (Stage 1 — parse + translate) ---
python scripts/run_step1.py --all-modules --mode local
git add assertions/translated/ results/logs/ prompts/final/
git commit -m "Stage 1: all modules translated"
git push

# --- SERVER (Stage 2 — compile + FPV) ---
git pull
python scripts/run_step1.py --all-modules --mode server
git add results/ errors/
git commit -m "Stage 2: all modules validated"
git push

# --- LAPTOP (collect results) ---
git pull
python scripts/run_step1.py --status
```

---

## Ibex Security Modules (9 total)

| Module | RTL File | Type | Bind File |
|--------|----------|------|-----------|
| PMP | `ibex_pmp.sv` | Combinational | `pmp_bind.sv` |
| CSR | `ibex_cs_registers.sv` | Sequential | `csr_bind.sv` |
| DO | `ibex_controller.sv` | Sequential | `do_bind.sv` |
| ETI | `ibex_controller.sv` | Sequential | `eti_bind.sv` |
| CF | `ibex_controller.sv` | Sequential | `cf_bind.sv` |
| MT | `ibex_controller.sv` | Sequential | `mt_bind.sv` |
| MA | `ibex_load_store_unit.sv` | Sequential | `ma_bind.sv` |
| IE | `ibex_id_stage.sv` + `ibex_ex_block.sv` | Sequential | `ie_bind.sv` |
| RU | `ibex_wb_stage.sv` | Sequential | `ru_bind.sv` |

`ibex_controller.sv` serves 4 logical modules (DO, ETI, CF, MT).
PMP is combinational — no `@(posedge)`, `##N`, or `$past()`.
Clock: `clk_i`. Reset: `rst_ni` (active-low).

---

## Repository Structure

```
ai-autotrans-rv/
├── README.md
├── requirements.txt                 ← openai, python-dotenv
├── .env                             ← NVIDIA_API_KEY (gitignored)
│
├── prompts/                         ← prompt templates (fixed — edit with advisor approval)
│   ├── sequential_prompt.txt
│   ├── combinational_prompt.txt
│   └── final/                       ← assembled prompts per module (gitignored)
│
├── scripts/
│   ├── setup_env.py                 ← environment checker
│   ├── run_step1.py                 ← master orchestrator
│   ├── parse_rtl.py                 ← Step 1A: regex SV signal extractor
│   ├── translate.py                 ← Steps 1B+1C: prompt assembly + DeepSeek translation
│   ├── validate_compile.py          ← Step 2A: QuestaSim compile loop
│   ├── validate_fpv.py              ← Step 2B: JasperGold FPV loop
│   └── ablation_no_rvsigex.py       ← ablation: ungrounded baseline
│
├── rtl/ibex/original/               ← clean Ibex RTL (never modify)
├── assertion_dataset/               ← NS31A CSV files (one per module)
│
├── assertions/
│   ├── translated/                  ← SVA bind files (pipeline output)
│   ├── fpv/                         ← FPV wrappers (PMP combinational wrapper)
│   └── backup_working_20May2026/    ← FPV-validated bind files before advisor demo
│
├── results/
│   ├── signals/                     ← <MODULE>_signals.json (parser output)
│   ├── logs/                        ← <MODULE>_tar_log.json (TAR data)
│   ├── raw/                         ← LLM raw output (gitignored)
│   └── step1/                       ← FPV reports, vacuity, state files
│
└── errors/
    └── archive/                     ← QuestaSim + JasperGold error logs (NEVER DELETE)
```

---

## Tool Requirements

| Tool | Purpose | Step |
|------|---------|------|
| Python 3.10+ | Pipeline scripts | All |
| openai | NVIDIA NIM API client | 1B/1C |
| python-dotenv | .env loading | 1B/1C |
| NVIDIA NIM account | Free API credits (1000) | 1B/1C |
| QuestaSim | SVA compilation | 2A |
| JasperGold | Formal verification | 2B |

**Stage 1 runs entirely on a laptop. No GPU. No EDA licence. No paid subscription.**

---

## TAR Metric

```
TAR = proven_non_vacuous / total_ns31a_groups × 100   (per module)
```

- **Auto TAR**: groups proven by automated pipeline (Flash + Pro retries), no human intervention
- **Final TAR**: Auto TAR + groups proven after targeted manual resolution of JasperGold structural constraints (port scope, free-variable antecedents, timing, Ibex-specific opcodes)

TAR is computed by `validate_fpv.py` at Step 2B and stored in `results/logs/<MODULE>_tar_log.json`.

---

## Signal Extractor (`parse_rtl.py`)

Regex-based SystemVerilog parser — no EDA tools or parser libraries required.

**Extracts per module:**
- Port declarations (inputs/outputs) with width and direction
- Internal signals (`logic`/`wire`/`reg` and typedef'd enum/struct variables)
- Parameter names
- Package types (`typedef enum`/`struct` from `ibex_pkg.sv`), filtered to those referenced by the module
- Signal connectivity (`assign` + `always_comb` assignments)

**General-purpose usage (any SV module):**
```bash
python scripts/parse_rtl.py --sv-file path/to/module.sv
python scripts/parse_rtl.py --sv-file path/to/module.sv --pkg-file path/to/pkg.sv
```

**Reproducibility:** `git diff results/signals/` is empty on every re-run (deterministic regex).

---

## Relation to Other Papers

| Paper | Role |
|-------|------|
| Imtiaz et al., ISCAS 2025 | Our prior work — semi-automated, 5 modules, no FPV gate |
| Chuah et al., MEMOCODE 2023 | Source of NS31A assertion corpus |
| SecMetric journal paper | Downstream companion — Stages 2–5 of the broader flow |

---

## Acknowledgments

Built on the **lowRISC Ibex** RISC-V processor (Apache 2.0).
NS31A assertion corpus from **Chuah et al., MEMOCODE 2023**.
Funded by the Estonian Research Council grant **PSG837**.
LLM inference via **NVIDIA NIM** free developer credits.
Pipeline development assisted by **Claude Code** (Anthropic).

---

## Citation

```bibtex
@inproceedings{imtiaz2026autotrans,
  title     = {{AutoTrans}: {AI}-Assisted Automatic Translation of
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
