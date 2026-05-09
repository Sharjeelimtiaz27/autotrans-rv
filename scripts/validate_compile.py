#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Step 1C: QuestaSim Compile Loop (max 3 retries with DeepSeek Pro)
=======================================================
Input:  assertions/translated/<MODULE>_bind.sv
Output: errors/archive/<MODULE>_compile_<N>.log  (on failure — NEVER DELETE)

LLM tier:
  Pro (deepseek-ai/deepseek-v4-pro) for ALL retries.
  QuestaSim errors involve type mismatches, enum scope, struct field names,
  and port width issues — they require deep RTL context to fix correctly.
  Flash is fast but shallow; Pro handles the semantic complexity here.

On FAIL (per attempt):
  - Log error to errors/archive/<MODULE>_compile_<N>.log
  - Build retry prompt = original prompt + error log
  - Send to DeepSeek Pro, parse new bind file, retry compile
After 3 failed retries: set locked=True, print ESCALATE, return False.

Usage:
  python scripts/validate_compile.py --module pmp
  python scripts/validate_compile.py --all-modules
"""

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from translate import (
    MODULE_CONFIG, DEEPSEEK_PRO,
    run_deepseek, parse_output, fix_bind_target,
)

MAX_RETRIES = 3
RTL_ORIG    = ROOT / "rtl" / "ibex" / "original"
ASSERTS_DIR = ROOT / "assertions" / "translated"
ERRORS_DIR  = ROOT / "errors" / "archive"
RESULTS_DIR = ROOT / "results" / "step1"
ALL_MODULES = list(MODULE_CONFIG.keys())


# ---------------------------------------------------------------------------
# RTL file list (pkg first — dependency order)
# ---------------------------------------------------------------------------

def _rtl_files(module_key: str) -> list:
    pkg    = RTL_ORIG / "ibex_pkg.sv"
    all_sv = sorted(RTL_ORIG.glob("*.sv"))
    result = []
    if pkg.exists():
        result.append(pkg)
    result.extend(f for f in all_sv if f.name != "ibex_pkg.sv")
    return result


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def _state_path(module_key: str) -> Path:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    return RESULTS_DIR / f"{module_key}_compile_state.json"


def _load_state(module_key: str) -> dict:
    p = _state_path(module_key)
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"locked": False}


def _save_state(module_key: str, state: dict):
    _state_path(module_key).write_text(json.dumps(state, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# QuestaSim compile
# ---------------------------------------------------------------------------

def _run_vlog(vlog_bin: str, bind_path: Path, module_key: str,
              work_dir: Path) -> tuple:
    """Compile RTL + bind file. Returns (success: bool, output: str)."""
    work_lib = work_dir / "work"
    subprocess.run(["vlib", str(work_lib)], capture_output=True, cwd=ROOT)

    cmd = (
        [vlog_bin, "-sv12compat", "-work", str(work_lib),
         f"+incdir+{RTL_ORIG}"]
        + [str(f) for f in _rtl_files(module_key)]
        + [str(bind_path)]
    )
    try:
        res = subprocess.run(cmd, capture_output=True, text=True,
                             cwd=ROOT, timeout=300)
    except subprocess.TimeoutExpired:
        return False, "vlog timed out after 300s"

    out = (res.stdout + "\n" + res.stderr).strip()
    success = res.returncode == 0 and "** Error" not in out
    return success, out


# ---------------------------------------------------------------------------
# Retry prompt
# ---------------------------------------------------------------------------

def _retry_prompt(module_key: str, bind_content: str,
                  error_text: str, attempt: int) -> str:
    """Original prompt + QuestaSim error + fix-syntax-only instruction."""
    prompt_path = ROOT / "prompts" / "final" / f"{module_key}_final_prompt.txt"
    base = prompt_path.read_text(encoding="utf-8") if prompt_path.exists() else ""

    return base + f"""

================================================================================
PREVIOUS COMPILATION FAILED (attempt {attempt}/{MAX_RETRIES}):

{error_text}

--- CURRENT BIND FILE (FIX THIS) ---
{bind_content}

Fix the SVA bind file to resolve this QuestaSim compilation error.
Use ONLY signals from the AVAILABLE SIGNALS list above.
Do NOT change assertion logic — fix syntax and port declarations only.
Return ONLY the corrected SystemVerilog bind file (no JSON mapping section).
================================================================================
"""


# ---------------------------------------------------------------------------
# Main compile loop
# ---------------------------------------------------------------------------

def run_module(module_key: str) -> bool:
    """Step 1C for one module. Returns True on success."""
    cfg       = MODULE_CONFIG[module_key]
    bind_path = ASSERTS_DIR / cfg["bind_file"]

    print(f"\n  [1C] {module_key}: {cfg['bind_file']}")

    if not bind_path.exists():
        print(f"  ERROR: bind file missing — run translate.py first.",
              file=sys.stderr)
        return False

    state = _load_state(module_key)
    if state.get("locked"):
        print(f"  LOCKED: exhausted retries.")
        print(f"  ESCALATE: manual fix required for {bind_path.name}")
        return False

    vlog_bin = shutil.which("vlog")
    if not vlog_bin:
        print("  ERROR: 'vlog' not on PATH — run this step on the EDA server.",
              file=sys.stderr)
        sys.exit(2)

    ERRORS_DIR.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="ats_vlog_") as tmp:
        work_dir = Path(tmp)
        ts       = datetime.now(timezone.utc).isoformat()

        # Initial compile
        ok, out = _run_vlog(vlog_bin, bind_path, module_key, work_dir)
        if ok:
            print(f"  [1C] PASS — compiles clean.")
            _save_state(module_key, {"locked": False, "status": "pass",
                                     "retries_used": 0, "timestamp": ts})
            return True

        # Retries with Pro
        for retry in range(1, MAX_RETRIES + 1):
            err_path = ERRORS_DIR / f"{module_key}_compile_{retry}.log"
            err_path.write_text(
                f"Module: {module_key}\nAttempt: {retry}\nTimestamp: {ts}\n\n{out}",
                encoding="utf-8"
            )
            print(f"  [1C] FAIL  — logged: errors/archive/{err_path.name}")
            print(f"  [1C] DeepSeek Pro retry {retry}/{MAX_RETRIES} ...")

            bind_content = bind_path.read_text(encoding="utf-8")
            prompt       = _retry_prompt(module_key, bind_content, out, retry)
            raw          = run_deepseek(prompt, model=DEEPSEEK_PRO, timeout=300)

            raw_dir = ROOT / "results" / "raw"
            raw_dir.mkdir(parents=True, exist_ok=True)
            (raw_dir / f"{module_key}_compile_retry_{retry}.txt").write_text(
                raw, encoding="utf-8"
            )

            _, new_sv = parse_output(raw)
            if not new_sv and "module " in raw and "endmodule" in raw:
                new_sv = raw

            if new_sv:
                rtl_name    = cfg["rtl_name"]
                assert_name = (f"{rtl_name}_{cfg['short']}"
                               if module_key in ("do", "eti", "cf", "mt")
                               else rtl_name)
                new_sv = fix_bind_target(new_sv, rtl_name, assert_name)
                bind_path.write_text(new_sv, encoding="utf-8")
                print(f"  [1C] Bind file updated by Pro.")
            else:
                print(f"  [1C] WARNING: could not parse Pro output, retrying unchanged.")

            ts = datetime.now(timezone.utc).isoformat()
            ok, out = _run_vlog(vlog_bin, bind_path, module_key, work_dir)
            if ok:
                print(f"  [1C] PASS — compiles clean after {retry} retry/retries.")
                _save_state(module_key, {"locked": False, "status": "pass",
                                         "retries_used": retry, "timestamp": ts})
                return True

        # Exhausted
        final_err = ERRORS_DIR / f"{module_key}_compile_{MAX_RETRIES + 1}.log"
        final_err.write_text(
            f"Module: {module_key}\nFinal failure after {MAX_RETRIES} retries\n"
            f"Timestamp: {ts}\n\n{out}",
            encoding="utf-8"
        )
        _save_state(module_key, {"locked": True, "status": "fail",
                                  "retries_used": MAX_RETRIES, "timestamp": ts})
        print(f"\n  [1C] ESCALATE: {module_key} FAILED after {MAX_RETRIES} retries.")
        print(f"  Logs: errors/archive/{module_key}_compile_*.log")
        return False


def main():
    ap = argparse.ArgumentParser(
        description="validate_compile.py — Step 1C QuestaSim compile loop"
    )
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--module", choices=ALL_MODULES, metavar="MODULE",
                     help=f"Single module: {', '.join(ALL_MODULES)}")
    grp.add_argument("--all-modules", action="store_true",
                     help="Run all modules")
    args = ap.parse_args()

    modules = ALL_MODULES if args.all_modules else [args.module]
    results = {}
    for m in modules:
        results[m] = run_module(m)

    print(f"\n{'='*50}")
    print("  STEP 1C SUMMARY")
    print(f"{'='*50}")
    for m, ok in results.items():
        print(f"  {m:<6}  {'PASS' if ok else 'FAIL'}")

    failed = [m for m, ok in results.items() if not ok]
    if failed:
        print(f"\n  FAILED: {', '.join(failed)}")
        sys.exit(1)
    print("\n  All modules compiled successfully.")
    print("  Next: python scripts/validate_fpv.py --all-modules")


if __name__ == "__main__":
    main()
