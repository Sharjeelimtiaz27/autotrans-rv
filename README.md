# ai-autotrans-rv

**AI-AutoTrans: AI-Assisted Automatic Translation of Security Assertions for RISC-V Processors**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)

---

## Overview

This repository implements **Stage 1 (Assertion Translation Stage)** of a larger formal
security verification flow for RISC-V processors.

The pipeline takes NS31A security assertions from MEMOCODE 2023 (Chuah et al.) and
automatically translates them to Ibex RTL SVA using an **RV-SigEx**-grounded fixed-template
approach with DeepSeek V4-Flash/Pro via NVIDIA NIM API, validated end-to-end by QuestaSim
compilation and JasperGold FPV.

---

## Pipeline — How It Works

```
 INPUTS
 ══════════════════════════════════════════════════════════════════

  rtl/ibex/original/*.sv          assertion_dataset/ns31a_<MODULE>.csv
  (Ibex RTL — never modify)       (NS31A source assertions — 9 modules)
         │                                        │
         │                                        │
         ▼                                        │
 ┌───────────────────────┐                        │
 │   STEP 1A             │                        │
 │   parse_rtl.py        │                        │
 │   RV-SigEx parser     │                        │
 │   (regex-based SV)    │                        │
 └──────────┬────────────┘                        │
            │                                     │
            ▼                                     │
  results/signals/                                │
  <MODULE>_signals.json           prompts/sequential_prompt.txt
  (ports, internals,              prompts/combinational_prompt.txt
   pkg_types, connectivity)       (fixed templates — never modify)
            │                                     │
            └─────────────────┬───────────────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │   STEP 1B             │
                  │   translate.py        │
                  │                       │
                  │   DeepSeek V4-Flash   │
                  │   NVIDIA NIM API      │
                  │   temperature = 0.0   │
                  │   seed = 42           │
                  │                       │
                  │   Translate security  │
                  │   INTENT — every      │
                  │   assertion group     │
                  │   must translate      │
                  └──────────┬────────────┘
                             │
                             ▼
               assertions/translated/<MODULE>_bind.sv
               results/logs/<MODULE>_tar_log.json
               prompts/final/<MODULE>_final_prompt.txt
                             │
                             ▼
                  ┌───────────────────────┐        ┌──────────────────────────┐
                  │   STEP 1C             │  FAIL  │  Retry (max 3)           │
                  │   validate_compile.py ├───────►│  DeepSeek V4-Pro         │
                  │   QuestaSim           │        │  prompt + error log      │
                  │   SVA syntax check    │        │  fix syntax only         │
                  └──────────┬────────────┘        └──────────────────────────┘
                             │ PASS
                             ▼
                  ┌───────────────────────┐        ┌──────────────────────────┐
                  │   STEP 1D             │  FAIL  │  Retry (max 3)           │
                  │   validate_fpv.py     ├───────►│  DeepSeek V4-Pro         │
                  │   JasperGold FPV      │        │  prompt + error + stage  │
                  │   Proven +            │        │  fix assertion logic      │
                  │   non-vacuous         │        └──────────────────────────┘
                  └──────────┬────────────┘
                             │ PROVEN + NON-VACUOUS
                             ▼
               results/step1/<MODULE>_fpv_baseline.txt
               results/step1/<MODULE>_vacuity.txt
               results/step1/<MODULE>_cov.txt
                             │
                             ▼
              ╔══════════════════════════════╗
              ║   TAR (Translation           ║
              ║   Acceptance Rate)           ║
              ║                              ║
              ║   proven_assertions          ║
              ║   ──────────────── × 100     ║
              ║   total_ns31a_groups         ║
              ║                              ║
              ║   Computed per module by     ║
              ║   validate_fpv.py            ║
              ╚══════════════════════════════╝

 NOTES
 ══════════════════════════════════════════════════════════════════
 Steps 1A + 1B run on any laptop (no EDA tools needed).
 Steps 1C + 1D require QuestaSim + JasperGold licences (EDA server).

 LLM tier strategy:
   Flash  → initial translation only (cheap first attempt)
   Pro    → ALL retries: QuestaSim compile failures + JasperGold FPV failures
            (QuestaSim errors involve enum scope, struct fields, port widths —
             they need deep RTL reasoning, not just syntax pattern matching)

 After 3 failed retries at either step: assertion is DROPPED, error
 logged to errors/archive/ (never delete — paper evidence).
```

---

## Three Contributions

1. **RV-SigEx — regex-based SystemVerilog signal extractor for LLM prompt grounding.**
   RV-SigEx extracts ports, internal signals, package types (typedef enums, structs), and
   parameterized widths from real-world SV into a structured JSON injected into every
   prompt. Unlike PyVerilog, which builds a full parse tree and struggles with advanced
   Ibex constructs (package-scoped enums in separate files, struct-typed ports,
   parameterized arrays), RV-SigEx uses targeted regex patterns tuned to real RISC-V SV
   style. The LLM sees only signals that actually exist in the RTL — it cannot hallucinate
   non-existent signal names.

2. **Hallucination-free, reproducible SVA translation with a two-tier LLM cost strategy.**
   RV-SigEx grounding + fixed template + `temperature=0.0` + `seed=42` together eliminate
   the two failure modes of raw-LLM translation: hallucinated signals and non-reproducible
   outputs. A two-tier model strategy — Flash for initial generation (cheap, fast), Pro for
   all retries (deeper RTL reasoning for type-scope and struct-field errors) — bounds cost
   while maximising fix quality. No GPU, no fine-tuning; only NVIDIA NIM free-tier credits.
   The pipeline covers the complete NS31A corpus: **46 security SVA** (formal NS31A
   assertions, adapted to Ibex signals) and **22 security properties** (English descriptions
   only, from which the framework generates formal SVA directly).

3. **Two-step industry-grade validation gate and TAR metric.** Every translated assertion
   must pass two gates before it counts: QuestaSim SVA compile (syntax) then JasperGold
   FPV Proven + non-vacuous on clean RTL (semantics). TAR (Translation Acceptance Rate =
   proven\_non\_vacuous / total\_ns31a\_groups) measures mechanically verified translation
   quality — not LLM self-report or BLEU/ROUGE. Applied to NS31A → Ibex across 9 security
   modules without manual porting of any assertion.

---

## Setup

### One-command check

After completing the steps below:

```bash
python scripts/setup_env.py
```

---

### Step 1 — Python dependencies

```bash
python -m pip install -r requirements.txt
```

Installs: `pyverilog`, `pandas`, `openai`, `python-dotenv`.

---

### Step 2 — NVIDIA NIM API key

Get a free API key at [build.nvidia.com](https://build.nvidia.com) (1000 free credits).

Create a `.env` file in the project root:

```
NVIDIA_API_KEY=nvapi-...your-key-here...
```

The `.env` file is gitignored — never commit it.

**No GPU required. No paid subscription. Just the free NVIDIA developer account.**

---

### Step 3 — Ibex RTL + NS31A data (already in repo)

- `rtl/ibex/original/` — clean Ibex RTL (read-only, never modify)
- `assertion_dataset/ns31a_<module>.csv` — NS31A assertion source files

---

## Running the Pipeline

### Local mode — Steps 1A + 1B (laptop, no EDA tools)

**Single module:**
```bash
python scripts/run_step1.py --module pmp --mode local
```

**All 9 modules:**
```bash
python scripts/run_step1.py --all-modules --mode local
```

**Individual steps:**
```bash
python scripts/parse_rtl.py --module pmp          # Step 1A: parse RTL
python scripts/translate.py  --module pmp          # Step 1B: translate assertions
python scripts/translate.py  --module pmp --pro    # Step 1B: use Pro model
```

**Dry-run (build prompt only, no API call):**
```bash
python scripts/translate.py --module pmp --dry-run
```

### Server mode — Steps 1C + 1D (QuestaSim + JasperGold)

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
# --- LAPTOP (parse + translate, no EDA licences) ---
python scripts/run_step1.py --all-modules --mode local
git add assertions/translated/ results/logs/
git commit -m "Step1 local: all modules translated"
git push

# --- SERVER (QuestaSim + JasperGold) ---
git pull
python scripts/run_step1.py --all-modules --mode server
git add results/ errors/
git commit -m "Step1 server: all modules validated"
git push

# --- LAPTOP (collect results) ---
git pull
python scripts/run_step1.py --status
```

---

## Ibex Security Modules

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
├── requirements.txt                 ← pyverilog, pandas, openai, python-dotenv
├── .env                             ← NVIDIA_API_KEY (gitignored — never commit)
│
├── prompts/                         ← prompt templates
│   ├── sequential_prompt.txt        ← FIXED sequential SVA template
│   ├── combinational_prompt.txt     ← FIXED combinational SVA template
│   └── final/                       ← assembled prompts per module (gitignored)
│
├── scripts/                         ← Python pipeline scripts
│   ├── setup_env.py                 ← environment checker (run first)
│   ├── run_step1.py                 ← master orchestrator
│   ├── parse_rtl.py                 ← 1A: RV-SigEx (regex-based SV parser)
│   ├── translate.py                 ← 1B: DeepSeek V4-Flash translation
│   ├── validate_compile.py          ← 1C: QuestaSim compile loop
│   └── validate_fpv.py              ← 1D: JasperGold FPV baseline
│
├── rtl/
│   └── ibex/
│       ├── original/                ← clean Ibex RTL (parser input — never modify)
│       └── trojaned_rtl/            ← trojaned RTL for assertion testing
│
├── assertion_dataset/               ← NS31A source CSV files (one per module)
│
├── assertions/
│   └── translated/                  ← SVA bind files (pipeline output)
│
├── results/
│   ├── signals/                     ← MODULE_signals.json (parser output)
│   ├── logs/                        ← MODULE_tar_log.json (translation log)
│   ├── raw/                         ← LLM raw output per module (gitignored)
│   └── step1/                       ← FPV reports, vacuity, COV files
│
└── errors/
    └── archive/                     ← QuestaSim + JasperGold error logs (NEVER DELETE)
```

---

## Requirements Summary

| Tool | Purpose | Required for | Install |
|------|---------|-------------|---------|
| Python 3.10+ | Pipeline scripts | All steps | python.org |
| pyverilog | RTL parsing | Step 1A | `pip install pyverilog` |
| pandas | CSV handling | Step 1B | `pip install pandas` |
| openai | NVIDIA NIM API client | Step 1B | `pip install openai` |
| python-dotenv | .env file loading | Step 1B | `pip install python-dotenv` |
| NVIDIA NIM account | Free API credits | Step 1B | build.nvidia.com |
| QuestaSim | SVA compilation | Step 1C | EDA server |
| JasperGold | Formal verification | Step 1D | EDA server |

**Steps 1A + 1B run entirely on a laptop. No GPU. No paid subscription.**

---

## LLM Model Tiers

| Model | ID | Used for |
|-------|----|---------|
| DeepSeek V4-Flash | `deepseek-ai/deepseek-v4-flash` | Initial translation only (Step 1B) |
| DeepSeek V4-Pro | `deepseek-ai/deepseek-v4-pro` | All retries: QuestaSim compile (Step 1C) + JasperGold FPV (Step 1D) |

Both called via NVIDIA NIM (OpenAI-compatible API, `https://integrate.api.nvidia.com/v1`).
`temperature=0.0`, `seed=42` for reproducibility.

---

## RV-SigEx — RISC-V Signal Extractor

`scripts/parse_rtl.py` implements **RV-SigEx**, a regex-based SystemVerilog signal extractor.

**What it extracts:**
- Port declarations (inputs/outputs) with width and direction
- Internal signals (logic/wire/reg and typedef'd enum/struct variables)
- Parameters
- Package types (typedef enum/struct from ibex_pkg.sv), filtered per module
- Connectivity (assign statements + always_comb block assignments)

**Validated on Ibex (9 modules):**

| Module | RTL File | Inputs | Outputs | Internals | PkgTypes |
|--------|----------|--------|---------|-----------|----------|
| pmp | ibex_pmp.sv | 7 | 1 | 12 | 4 |
| csr | ibex_cs_registers.sv | 44 | 27 | 109 | 9 |
| do/eti/cf/mt | ibex_controller.sv | 38 | 27 | 39 | 7 |
| ma | ibex_load_store_unit.sv | 13 | 18 | 20 | 0 |
| ie | ibex_id_stage.sv + ibex_ex_block.sv | 64 | 77 | 89 | 15 |
| ru | ibex_wb_stage.sv | 15 | 15 | 18 | 1 |

Full stats: [`results/signals/parser_stats.txt`](results/signals/parser_stats.txt)

**Reproducibility:** `git diff results/signals/` = empty on every re-run.

**General-purpose usage:**
```bash
python scripts/parse_rtl.py --sv-file path/to/any_module.sv
python scripts/parse_rtl.py --sv-file path/to/any_module.sv --pkg-file path/to/pkg.sv
```

---

## TAR Metric

```
TAR = proven_assertions / total_ns31a_groups × 100   (per module)
```

- `proven_assertions` — assertions that pass JasperGold FPV (Proven + non-vacuous),
  without any manual intervention
- `total_ns31a_groups` — number of NS31A assertion groups in the source CSV

TAR is computed by `validate_fpv.py` and stored in `results/logs/<MODULE>_tar_log.json`.
The translation step (Step 1B) aims for 100% translation coverage; TAR filters to only
what is formally verified.

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
