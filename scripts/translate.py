#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Step 1B: DeepSeek (NVIDIA NIM) SVA Translation
=======================================================
Assembles prompt inline from:
  prompts/<seq|comb>_prompt.txt  (selected from signals.json type)
  results/signals/<MODULE>_signals.json
  assertion_dataset/ns31a_<MODULE>.csv
Calls DeepSeek via NVIDIA NIM API (temperature=0.0 for reproducibility).
Output: assertions/translated/<MODULE>_bind.sv  +  results/logs/<MODULE>_tar_log.json

API key: set NVIDIA_API_KEY in .env or environment.
Model tier:
  Flash  (default) — deepseek-ai/deepseek-v4-flash — initial generation only
  Pro    (--pro)   — deepseek-ai/deepseek-v4-pro   — all retries (compile + FPV)
"""

import argparse
import csv
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# DeepSeek / NVIDIA NIM configuration
# ---------------------------------------------------------------------------
NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1"
# Flash: fast, cheap — used for initial generation ONLY
DEEPSEEK_FLASH  = "deepseek-ai/deepseek-v4-flash"
# Pro: deeper reasoning — used for ALL retries (QuestaSim compile + JasperGold FPV)
DEEPSEEK_PRO    = "deepseek-ai/deepseek-v4-pro"
TEMPERATURE     = 0.0   # greedy decoding — reduces output variance
SEED            = 42    # fixed seed — further anchors determinism where supported
MAX_TOKENS      = 16384

# Maps logical module key -> RTL file name, short id, output bind file name.
# ibex_controller serves DO / ETI / CF / MT — each gets its own bind file.
MODULE_CONFIG = {
    "pmp": {
        "rtl_name":  "ibex_pmp",
        "short":     "pmp",
        "bind_file": "pmp_bind.sv",
    },
    "csr": {
        "rtl_name":  "ibex_cs_registers",
        "short":     "csr",
        "bind_file": "csr_bind.sv",
    },
    "do": {
        "rtl_name":  "ibex_controller",
        "short":     "do",
        "bind_file": "do_bind.sv",
    },
    "eti": {
        "rtl_name":  "ibex_controller",
        "short":     "eti",
        "bind_file": "eti_bind.sv",
    },
    "cf": {
        "rtl_name":  "ibex_controller",
        "short":     "cf",
        "bind_file": "cf_bind.sv",
    },
    "mt": {
        "rtl_name":  "ibex_controller",
        "short":     "mt",
        "bind_file": "mt_bind.sv",
    },
    "ma": {
        "rtl_name":  "ibex_load_store_unit",
        "short":     "ma",
        "bind_file": "ma_bind.sv",
    },
    "ie": {
        "rtl_name":  "ibex_id_stage",
        "short":     "ie",
        "bind_file": "ie_bind.sv",
    },
    "ru": {
        "rtl_name":  "ibex_wb_stage",
        "short":     "ru",
        "bind_file": "ru_bind.sv",
    },
}


# ---------------------------------------------------------------------------
# Helpers: name derivation
# ---------------------------------------------------------------------------

def _assert_module_name(module_key: str) -> str:
    """
    Return the assertion module name used in the SVA bind file.
    ibex_controller is shared by do/eti/cf/mt, so append the logical suffix
    to distinguish the four assertion modules (ibex_controller_do, etc.).
    """
    cfg = MODULE_CONFIG[module_key]
    if module_key in ("do", "eti", "cf", "mt"):
        return f"{cfg['rtl_name']}_{cfg['short']}"
    return cfg["rtl_name"]


# ---------------------------------------------------------------------------
# I/O loaders
# ---------------------------------------------------------------------------

def load_signals(module_key: str) -> dict:
    path = ROOT / "results" / "signals" / f"{module_key}_signals.json"
    if not path.exists():
        print(f"ERROR: signals file not found: {path}", file=sys.stderr)
        print(f"  Run: python scripts/parse_rtl.py --module {module_key}", file=sys.stderr)
        sys.exit(1)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_csv(module_key: str) -> list:
    path = ROOT / "assertion_dataset" / f"ns31a_{module_key}.csv"
    if not path.exists():
        print(f"ERROR: NS31A CSV not found: {path}", file=sys.stderr)
        sys.exit(1)
    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# Formatting helpers for prompt placeholders
# ---------------------------------------------------------------------------

def _width_label(width) -> str:
    """Human-readable width for signal table."""
    if isinstance(width, int):
        return f"{width}-bit"
    return str(width)


def _sv_type(width) -> str:
    """Convert a signals.json width field to an SV type string."""
    if isinstance(width, int):
        return "logic" if width == 1 else f"logic [{width - 1}:0]"
    w = str(width)
    if w.isdigit():
        n = int(w)
        return "logic" if n == 1 else f"logic [{n - 1}:0]"
    # Package type — e.g. "ibex_pkg::priv_lvl_e" or "ibex_pkg::pmp_cfg_t[PMPNumRegions]"
    if "::" in w:
        return w
    # Parameterised range — e.g. "PMP_ADDR_MSB:0" or "31:0"
    if re.match(r'^[A-Za-z0-9_]+:[A-Za-z0-9_]+$', w):
        return f"logic [{w}]"
    # "1[PMPNumChan]" → 1-bit vector of depth PMPNumChan
    m = re.match(r'^(\d+)\[([A-Za-z0-9_]+)\]$', w)
    if m:
        bits, dim = int(m.group(1)), m.group(2)
        return f"logic [{dim}-1:0]" if bits == 1 else f"logic [{bits - 1}:0] [{dim}-1:0]"
    return f"logic {w}"


def _fmt_signals_table(signals_list: list, skip: set = None) -> str:
    """Name-width table for the AVAILABLE SIGNALS section of the prompt."""
    skip = skip or set()
    lines = [
        f"  {s['name']:<44} [{_width_label(s['width'])}]"
        for s in signals_list
        if s["name"] not in skip
    ]
    return "\n".join(lines) if lines else "  (none)"


def _fmt_pkg_types(pkg_types: dict) -> str:
    """Format pkg_types as SV typedef text."""
    if not pkg_types:
        return "  (none — no package types used by this module)"
    out = []
    for tname, info in pkg_types.items():
        if info.get("kind") == "enum":
            base = info.get("base_type", "logic")
            out.append(f"typedef enum {base} {{")
            vals = list(info.get("values", {}).items())
            for i, (sym, raw) in enumerate(vals):
                comma = "," if i < len(vals) - 1 else ""
                out.append(f"    {sym} = {raw}{comma}")
            out.append(f"}} {tname};")
        elif info.get("kind") == "struct":
            out.append("typedef struct packed {")
            for field in info.get("fields", []):
                out.append(f"    {field['type']} {field['name']};")
            out.append(f"}} {tname};")
        out.append("")
    return "\n".join(out).rstrip()


def _fmt_port_declarations(signals: dict, is_sequential: bool) -> str:
    """
    Generate SV port declaration lines for the {{PORT_DECLARATIONS}} placeholder.
    Sequential modules: clock and reset are declared separately in the template,
    so they are excluded here.
    """
    clk = signals.get("clock", "clk_i")
    rst = signals.get("reset", "rst_ni")
    skip = {clk, rst} if is_sequential else set()

    lines = []
    # ALL ports are input — assertion module observes only, never drives signals.
    # DUT outputs are monitored as inputs here; driving them would conflict with the DUT.
    for p in signals["ports"]["inputs"]:
        if p["name"] in skip:
            continue
        lines.append(f"    input  {_sv_type(p['width'])} {p['name']}")
    for p in signals["ports"]["outputs"]:
        lines.append(f"    input  {_sv_type(p['width'])} {p['name']}")

    if not lines:
        return "    // (no additional ports)"

    # Trailing comma on every line except the last
    return "\n".join(
        line + ("," if i < len(lines) - 1 else "")
        for i, line in enumerate(lines)
    )


def _fmt_ns31a(rows: list) -> str:
    """Format NS31A CSV rows as numbered assertion groups."""
    lines = []
    for i, row in enumerate(rows, 1):
        pid   = row.get("property_id",   "").strip()
        cnt   = row.get("count",         "").strip()
        cat   = row.get("category",      "").strip()
        desc  = row.get("description",   "").strip()
        sva   = row.get("sva",           "").strip()
        ex    = row.get("example_target","").strip()
        notes = row.get("notes",         "").strip()

        lines.append(f"--- Assertion Group {i} ---")
        lines.append(f"  property_id    : {pid}")
        lines.append(f"  count          : {cnt}")
        lines.append(f"  category       : {cat}")
        lines.append(f"  description    : {desc}")
        lines.append(
            f"  ns31a_sva      : {sva if sva else '(none — translate from description)'}"
        )
        if ex:
            lines.append(f"  example_target : {ex}")
        if notes:
            lines.append(f"  notes          : {notes}")
        lines.append("")
    return "\n".join(lines).rstrip()


# ---------------------------------------------------------------------------
# Prompt assembly
# ---------------------------------------------------------------------------

def build_prompt(module_key: str, signals: dict, csv_rows: list, template: str) -> tuple:
    """
    Fill all {{PLACEHOLDERS}} in the prompt template.
    Returns (filled_prompt_str, assert_module_name).
    """
    cfg      = MODULE_CONFIG[module_key]
    is_seq   = signals.get("type", "sequential") == "sequential"
    aname    = _assert_module_name(module_key)
    clk      = signals.get("clock", "clk_i")
    rst      = signals.get("reset", "rst_ni")
    params   = ", ".join(signals.get("parameters", [])) or "(none)"

    skip_tbl = {clk, rst} if is_seq else set()

    replacements = {
        "{{MODULE_NAME}}":           aname,
        "{{MODULE_SHORT}}":          cfg["short"],
        "{{CLOCK}}":                 clk,
        "{{RESET}}":                 rst,
        "{{PARAMETERS}}":            params,
        "{{INPUT_PORTS}}":           _fmt_signals_table(signals["ports"]["inputs"],  skip_tbl),
        "{{OUTPUT_PORTS}}":          _fmt_signals_table(signals["ports"]["outputs"]),
        "{{INTERNAL_SIGNALS}}":      _fmt_signals_table(signals.get("internals", [])),
        "{{PKG_TYPES}}":             _fmt_pkg_types(signals.get("pkg_types", {})),
        "{{NS31A_ASSERTIONS}}":      _fmt_ns31a(csv_rows),
        "{{PORT_DECLARATIONS}}":     _fmt_port_declarations(signals, is_seq),
        "{{NS31A_TOTAL_GROUPS}}":    str(len(csv_rows)),
    }

    prompt = template
    for ph, val in replacements.items():
        prompt = prompt.replace(ph, val)

    return prompt, aname


# ---------------------------------------------------------------------------
# DeepSeek / NVIDIA NIM invocation
# ---------------------------------------------------------------------------

def _load_api_key() -> str:
    """
    Load NVIDIA_API_KEY from environment or .env file.
    Exits with a clear message if not found.
    """
    key = os.environ.get("NVIDIA_API_KEY", "")
    if not key:
        env_path = ROOT / ".env"
        if env_path.exists():
            for line in env_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line.startswith("NVIDIA_API_KEY="):
                    key = line.split("=", 1)[1].strip()
                    break
    if not key:
        print("ERROR: NVIDIA_API_KEY not set.", file=sys.stderr)
        print("  Add it to .env (project root) or export it in your shell:", file=sys.stderr)
        print("  NVIDIA_API_KEY=nvapi-...", file=sys.stderr)
        sys.exit(1)
    return key


def _strip_think_tags(text: str) -> str:
    """Remove DeepSeek R1 reasoning traces (<think>...</think>) from output."""
    return re.sub(r'<think>[\s\S]*?</think>', '', text, flags=re.IGNORECASE).strip()


def run_deepseek(prompt: str, model: str = DEEPSEEK_FLASH, timeout: int = 300) -> str:
    """
    Call DeepSeek via NVIDIA NIM (OpenAI-compatible) and return the text response.

    temperature=0.0 ensures deterministic output — same prompt → same SVA every run.
    This is the core reproducibility guarantee for the paper.
    """
    try:
        from openai import OpenAI
    except ImportError:
        print("ERROR: openai package not installed.", file=sys.stderr)
        print("  Run: python -m pip install openai python-dotenv", file=sys.stderr)
        sys.exit(1)

    api_key = _load_api_key()
    client  = OpenAI(base_url=NVIDIA_BASE_URL, api_key=api_key)

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=TEMPERATURE,
            seed=SEED,
            max_tokens=MAX_TOKENS,
            timeout=timeout,
        )
    except Exception as exc:
        print(f"ERROR: DeepSeek API call failed: {exc}", file=sys.stderr)
        sys.exit(1)

    raw = response.choices[0].message.content or ""
    return _strip_think_tags(raw)


# ---------------------------------------------------------------------------
# Output parsing
# ---------------------------------------------------------------------------

def parse_output(raw: str) -> tuple:
    """
    Split LLM output into (tar_dict | None, bind_sv_text | None).

    Recognised formats (tried in order):
      1. Explicit section markers:
           --- SECTION 1: JSON MAPPING LOG ---
           { ...json... }
           --- SECTION 2: SVA BIND FILE ---
           // SV code ...
      2. Markdown code fences (DeepSeek default):
           ```json
           { ...json... }
           ```
           ```systemverilog
           // SV code ...
           ```
      3. Heuristic fallback.
    """
    json_block = ""
    sv_block   = ""

    # --- Strategy 1: explicit section markers ---
    s1 = re.search(r'---\s*SECTION\s*1[^-\n]*---', raw, re.IGNORECASE)
    s2 = re.search(r'---\s*SECTION\s*2[^-\n]*---', raw, re.IGNORECASE)
    if s1 and s2:
        json_block = raw[s1.end():s2.start()].strip()
        sv_block   = raw[s2.end():].strip()

    # --- Strategy 2: markdown code fences ---
    if not json_block or not sv_block:
        jm = re.search(r'```json\s*([\s\S]*?)```', raw, re.IGNORECASE)
        sm = re.search(r'```(?:systemverilog|sv|verilog)\s*([\s\S]*?)```', raw, re.IGNORECASE)
        if jm:
            json_block = jm.group(1).strip()
        if sm:
            sv_block = sm.group(1).strip()

    # --- Strategy 3: heuristic fallback ---
    if not json_block:
        jm = re.search(r'(\{[\s\S]*?"mappings"[\s\S]*?\})\s*(?:```|$)', raw, re.DOTALL)
        if jm:
            json_block = jm.group(1)
    if not sv_block:
        sm = re.search(r'(//\s*\S+_bind\.sv[\s\S]*)', raw, re.DOTALL)
        if sm:
            sv_block = sm.group(1)

    # Strip any remaining markdown fences
    json_block = re.sub(r'```[a-z]*\n?', '', json_block).strip()
    sv_block   = re.sub(r'```[a-z]*\n?', '', sv_block).strip().rstrip('`').strip()

    # Parse JSON
    tar_data = None
    try:
        tar_data = json.loads(json_block)
    except (json.JSONDecodeError, ValueError):
        m = re.search(r'\{[\s\S]*\}', json_block)
        if m:
            try:
                tar_data = json.loads(m.group())
            except (json.JSONDecodeError, ValueError):
                pass

    return tar_data, sv_block or None


# ---------------------------------------------------------------------------
# Post-processing
# ---------------------------------------------------------------------------

def fix_bind_target(sv: str, rtl_name: str, assert_name: str) -> str:
    """
    Correct the bind target for shared-RTL modules (do / eti / cf / mt).

    Claude sees MODULE_NAME = "ibex_controller_do" so it outputs:
      bind ibex_controller_do ibex_controller_do_assertions ...
    We need:
      bind ibex_controller ibex_controller_do_assertions ...
    """
    if rtl_name == assert_name:
        return sv
    return re.sub(
        rf'\bbind\s+{re.escape(assert_name)}\b',
        f'bind {rtl_name}',
        sv
    )


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

def save_tar_log(module_key: str, assert_name: str, tar_data: dict, ts: str,
                 csv_total: int = 0):
    if tar_data is None:
        tar_data = {
            "module":             assert_name,
            "total_ns31a_groups": csv_total,
            "translated":         0,
            "mappings":           [],
            "parse_error":        "Could not extract JSON mapping log from LLM output",
        }
    tar_data.setdefault("module", assert_name)
    tar_data["timestamp"] = ts
    # Authoritative total always comes from CSV, never from model's self-report
    if csv_total > 0:
        tar_data["total_ns31a_groups"] = csv_total
    # Normalise field names from old schema if present
    tar_data.pop("total_ns31a_signals", None)
    tar_data.pop("auto_accepted",       None)
    tar_data.pop("untranslatable",      None)
    tar_data.pop("human_corrected",     None)
    # TAR is computed by FPV (validate_fpv.py), not here.
    # At translation stage we record how many groups were translated (should = total).
    translated = tar_data.get("translated", csv_total)
    total      = tar_data.get("total_ns31a_groups", csv_total)
    tar_data["translation_coverage"] = round(translated / total * 100, 1) if total > 0 else 0.0

    logs_dir = ROOT / "results" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = logs_dir / f"{module_key}_tar_log.json"
    with open(log_path, "w", encoding="utf-8") as f:
        json.dump(tar_data, f, indent=2)
    return tar_data, log_path


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="translate.py  Step 1B — NS31A to Ibex SVA via DeepSeek (NVIDIA NIM)"
    )
    ap.add_argument(
        "--module", required=True,
        choices=sorted(MODULE_CONFIG),
        metavar="MODULE",
        help=f"Logical module key: {', '.join(sorted(MODULE_CONFIG))}",
    )
    ap.add_argument(
        "--dry-run", action="store_true",
        help="Assemble and save prompt only — do not call DeepSeek",
    )
    ap.add_argument(
        "--pro", action="store_true",
        help=f"Use Pro model ({DEEPSEEK_PRO}) instead of Flash",
    )
    ap.add_argument(
        "--timeout", type=int, default=600,
        help="API call timeout in seconds (default: 600)",
    )
    args = ap.parse_args()

    module_key = args.module
    cfg   = MODULE_CONFIG[module_key]
    ts    = datetime.now(timezone.utc).isoformat()
    model = DEEPSEEK_PRO if args.pro else DEEPSEEK_FLASH

    print(f"\n=== translate.py  module={module_key} ===")

    # 1. Load signals
    print("  Loading signals.json ...")
    signals = load_signals(module_key)
    is_seq  = signals.get("type", "sequential") == "sequential"
    print(f"  Module type: {'sequential' if is_seq else 'combinational'}")

    # 2. Load NS31A CSV
    print("  Loading NS31A CSV ...")
    csv_rows = load_csv(module_key)
    print(f"  NS31A assertion groups: {len(csv_rows)}")

    # 3. Load prompt template
    tmpl_name = "sequential_prompt.txt" if is_seq else "combinational_prompt.txt"
    tmpl_path = ROOT / "prompts" / tmpl_name
    template  = tmpl_path.read_text(encoding="utf-8")
    print(f"  Template: {tmpl_name}")

    # 4. Build filled prompt
    prompt, assert_name = build_prompt(module_key, signals, csv_rows, template)
    prompt_dir  = ROOT / "prompts" / "final"
    prompt_dir.mkdir(parents=True, exist_ok=True)
    prompt_path = prompt_dir / f"{module_key}_final_prompt.txt"
    prompt_path.write_text(prompt, encoding="utf-8")
    print(f"  Prompt: {len(prompt):,} chars -> prompts/final/{module_key}_final_prompt.txt")

    if args.dry_run:
        print("  [dry-run] Prompt saved — DeepSeek not called.")
        return

    # 5. Call DeepSeek via NVIDIA NIM
    tier = "Pro" if args.pro else "Flash"
    print(f"  Calling DeepSeek {tier} (temp={TEMPERATURE}, seed={SEED}, timeout={args.timeout}s) ...")
    print(f"  Model: {model}")
    raw = run_deepseek(prompt, model=model, timeout=args.timeout)

    # Save raw output (gitignored)
    raw_dir  = ROOT / "results" / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_path = raw_dir / f"{module_key}_raw_output.txt"
    raw_path.write_text(raw, encoding="utf-8")
    print(f"  Raw output: {len(raw):,} chars -> results/raw/{module_key}_raw_output.txt")

    # 6. Parse sections from DeepSeek output
    tar_data, bind_sv = parse_output(raw)

    if not bind_sv:
        print("ERROR: Could not extract SVA bind file from DeepSeek output.", file=sys.stderr)
        print(f"  Raw output at: results/raw/{module_key}_raw_output.txt", file=sys.stderr)
        sys.exit(1)

    # 7. Fix bind target for shared-RTL modules (do/eti/cf/mt)
    bind_sv = fix_bind_target(bind_sv, cfg["rtl_name"], assert_name)

    # 8. Save bind file
    bind_dir  = ROOT / "assertions" / "translated"
    bind_dir.mkdir(parents=True, exist_ok=True)
    bind_path = bind_dir / cfg["bind_file"]
    bind_path.write_text(bind_sv, encoding="utf-8")

    # 9. Save TAR log — csv_rows length is the authoritative denominator
    tar_data, log_path = save_tar_log(module_key, assert_name, tar_data, ts,
                                      csv_total=len(csv_rows))

    # 10. Print summary
    total      = tar_data.get("total_ns31a_groups", 0)
    translated = tar_data.get("translated", 0)
    coverage   = tar_data.get("translation_coverage", 0.0)

    print(f"\n  Bind file  : assertions/translated/{cfg['bind_file']}")
    print(f"  Trans. log : {log_path.relative_to(ROOT)}")
    print(f"\n  Translation coverage = {translated}/{total} groups = {coverage}%")
    print(f"  (TAR computed after JasperGold FPV — run validate_fpv.py)")
    print(f"\n  Next: python scripts/validate_compile.py --module {module_key}")


if __name__ == "__main__":
    main()
