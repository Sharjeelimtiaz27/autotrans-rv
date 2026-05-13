#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv -- BEC 2026
#
"""
Step 1D: JasperGold FPV Baseline (Proven + non-vacuous)
=======================================================
Input:  assertions/translated/<MODULE>_bind.sv + rtl/ibex/original/*.sv
Output: results/step1/<MODULE>_fpv_baseline.txt
        results/step1/<MODULE>_vacuity.txt
        results/step1/<MODULE>_cov.txt

Pass criteria (BOTH required, no human gate):
  1. All properties Proven (no CEX)
  2. All properties non-vacuous (check_vacuity passes)

LLM tier:
  Pro (deepseek-ai/deepseek-v4-pro) for ALL retries.
  - CEX on clean RTL = assertion logic wrong (not a Trojan finding here).
  - Vacuous assertion = antecedent never fires in normal operation.
  Both require understanding RTL semantics -- Pro handles this correctly.

After 3 failed retries: set locked=True, print ESCALATE.
TAR is updated in results/logs/<MODULE>_tar_log.json after successful FPV.

TAR = proven_non_vacuous / total_ns31a_groups * 100

Usage:
  python scripts/validate_fpv.py --module pmp
  python scripts/validate_fpv.py --all-modules
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
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
RTL_STUBS   = ROOT / "rtl" / "stubs"
ASSERTS_DIR = ROOT / "assertions" / "translated"
ERRORS_DIR  = ROOT / "errors" / "archive"
RESULTS_DIR = ROOT / "results" / "step1"
LOGS_DIR    = ROOT / "results" / "logs"
ALL_MODULES = list(MODULE_CONFIG.keys())

# Top module for elaboration (the RTL module, not the assertion module)
MODULE_TOP = {k: v["rtl_name"] for k, v in MODULE_CONFIG.items()}

# Per-module RTL files -- excludes tracer/DV-only files not part of the design
_MODULE_RTL = {
    "pmp": ["ibex_pkg.sv", "ibex_pmp.sv"],
    "csr": ["ibex_pkg.sv", "ibex_csr.sv", "ibex_cs_registers.sv"],
    "do":  ["ibex_pkg.sv", "ibex_controller.sv"],
    "eti": ["ibex_pkg.sv", "ibex_controller.sv"],
    "cf":  ["ibex_pkg.sv", "ibex_controller.sv"],
    "mt":  ["ibex_pkg.sv", "ibex_controller.sv"],
    "ma":  ["ibex_pkg.sv", "ibex_load_store_unit.sv"],
    "ie":  ["ibex_pkg.sv", "ibex_alu.sv", "ibex_multdiv_fast.sv",
            "ibex_multdiv_slow.sv", "ibex_ex_block.sv",
            "ibex_decoder.sv", "ibex_id_stage.sv"],
    "ru":  ["ibex_pkg.sv", "ibex_wb_stage.sv"],
}


# ---------------------------------------------------------------------------
# RTL file list (pkg first, module-specific)
# ---------------------------------------------------------------------------

def _rtl_files(module_key: str) -> list:
    names = _MODULE_RTL.get(module_key, [])
    result = []
    for name in names:
        p = RTL_ORIG / name
        if p.exists():
            result.append(p)
    if not result:
        skip = {"ibex_tracer.sv", "ibex_tracer_pkg.sv"}
        pkg = RTL_ORIG / "ibex_pkg.sv"
        if pkg.exists():
            result.append(pkg)
        result.extend(
            f for f in sorted(RTL_ORIG.glob("*.sv"))
            if f.name != "ibex_pkg.sv" and f.name not in skip
        )
    return result


# ---------------------------------------------------------------------------
# JasperGold TCL generator
# ---------------------------------------------------------------------------

def _gen_tcl(module_key: str, bind_path: Path,
             baseline_f: Path, vacuity_f: Path, cov_f: Path) -> str:
    """Generate JasperGold batch TCL for the given module."""
    from translate import load_signals
    signals = load_signals(module_key)
    is_seq  = signals.get("type", "sequential") == "sequential"
    clk     = signals.get("clock", "clk_i")
    rst     = signals.get("reset", "rst_ni")
    top     = MODULE_TOP[module_key]

    # incdir flags: rtl/original first, then stubs for prim_assert.sv no-ops
    incdir_flags = f"+incdir+{RTL_ORIG}"
    if RTL_STUBS.exists():
        incdir_flags += f" +incdir+{RTL_STUBS}"

    analyze_lines = "\n".join(
        f"analyze -sv12 {incdir_flags} {{{f}}}" for f in _rtl_files(module_key)
    )

    clock_reset = (
        f"clock {clk}\nreset -expression {{!{rst}}}"
        if is_seq else
        "# combinational module -- no clock or reset"
    )

    return f"""clear -all

{analyze_lines}
analyze -sv12 {incdir_flags} {{{bind_path}}}

elaborate -top {top}
{clock_reset}

prove -bg -all
check_vacuity -all

report -results -file {{{baseline_f}}}
report -vacuity -file {{{vacuity_f}}}
report -cov     -file {{{cov_f}}}
exit
"""


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def _state_path(module_key: str) -> Path:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    return RESULTS_DIR / f"{module_key}_fpv_state.json"


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
# Report parsing
# ---------------------------------------------------------------------------

def _parse_baseline(report_path: Path) -> dict:
    """
    Parse JasperGold baseline report.
    Returns {property_name: "proven" | "cex" | "unknown"}.
    """
    if not report_path.exists():
        return {}

    results = {}
    text = report_path.read_text(encoding="utf-8", errors="replace")

    for line in text.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 2:
            continue
        name, status = parts[0], parts[1].lower()
        if not name or name.startswith("-") or name.lower() in ("name", "property"):
            continue
        if any(kw in status for kw in ("proven", "cex", "unknown", "error")):
            key = "proven" if "proven" in status else (
                  "cex"    if "cex"    in status else "unknown")
            results[name] = key

    return results


def _parse_vacuity(report_path: Path) -> dict:
    """
    Parse JasperGold vacuity report.
    Returns {property_name: True (vacuous) | False (non-vacuous)}.
    """
    if not report_path.exists():
        return {}

    results = {}
    text = report_path.read_text(encoding="utf-8", errors="replace")

    for line in text.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 2:
            continue
        name, status = parts[0], parts[1].lower()
        if not name or name.startswith("-") or name.lower() in ("name", "property"):
            continue
        if "vacuous" in status:
            results[name] = "non-vacuous" not in status

    return results


# ---------------------------------------------------------------------------
# JasperGold invocation
# ---------------------------------------------------------------------------

def _run_jg(jg_bin: str, tcl_path: Path) -> tuple:
    """Run JasperGold in batch mode. Returns (exit_code, stdout+stderr)."""
    cmd = [jg_bin, "-no_gui", "-batch", "-tcl", str(tcl_path)]
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             cwd=ROOT, timeout=600)
        res.stdout = res.stdout.decode("utf-8", errors="replace") if isinstance(res.stdout, bytes) else (res.stdout or "")
        res.stderr = res.stderr.decode("utf-8", errors="replace") if isinstance(res.stderr, bytes) else (res.stderr or "")
    except subprocess.TimeoutExpired:
        return 1, "JasperGold timed out after 600s"

    out = (res.stdout + "\n" + res.stderr).strip()
    return res.returncode, out


def _fpv_passed(baseline: dict, vacuity: dict) -> tuple:
    """
    Determine if all assertions pass (Proven + non-vacuous).
    Returns (all_pass: bool, issues: list[str]).
    """
    issues = []
    for name, status in baseline.items():
        if status == "cex":
            issues.append(f"CEX: {name}")
        elif status == "unknown":
            issues.append(f"Unknown: {name}")

    for name, is_vac in vacuity.items():
        if is_vac:
            issues.append(f"Vacuous: {name}")

    return len(issues) == 0, issues


# ---------------------------------------------------------------------------
# TAR update
# ---------------------------------------------------------------------------

def _update_tar(module_key: str, baseline: dict, vacuity: dict, ts: str):
    """Compute TAR from FPV results and update results/logs/<MODULE>_tar_log.json."""
    log_path = LOGS_DIR / f"{module_key}_tar_log.json"
    log = {}
    if log_path.exists():
        try:
            log = json.loads(log_path.read_text(encoding="utf-8"))
        except Exception:
            pass

    proven_non_vac = sum(
        1 for name, status in baseline.items()
        if status == "proven" and not vacuity.get(name, False)
    )
    total = log.get("total_ns31a_groups", 0)
    tar   = round(proven_non_vac / total * 100, 1) if total > 0 else 0.0

    log["TAR"]                      = tar
    log["proven_non_vacuous"]       = proven_non_vac
    log["total_assertions_in_bind"] = len(baseline)
    log["fpv_baseline"]             = baseline
    log["fpv_vacuity"]              = {k: "vacuous" if v else "non-vacuous"
                                       for k, v in vacuity.items()}
    log["fpv_timestamp"]            = ts

    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_path.write_text(json.dumps(log, indent=2), encoding="utf-8")
    return tar, proven_non_vac, total


# ---------------------------------------------------------------------------
# Retry prompt
# ---------------------------------------------------------------------------

def _retry_prompt(module_key: str, bind_content: str,
                  issues: list, attempt: int) -> str:
    """Original prompt + FPV failures + fix-logic instruction."""
    prompt_path = ROOT / "prompts" / "final" / f"{module_key}_final_prompt.txt"
    base = prompt_path.read_text(encoding="utf-8") if prompt_path.exists() else ""

    issue_block = "\n".join(f"  - {i}" for i in issues)

    cex_note = ""
    vac_note = ""
    if any("CEX" in i for i in issues):
        cex_note = ("  For CEX assertions: the property does NOT hold on clean Ibex RTL.\n"
                    "  This means the assertion logic is wrong -- rewrite to correctly\n"
                    "  capture the security property using available Ibex signals.\n")
    if any("Vacuous" in i for i in issues):
        vac_note = ("  For Vacuous assertions: the antecedent NEVER fires in simulation.\n"
                    "  Rewrite the antecedent so the trigger condition is reachable in\n"
                    "  normal (non-Trojan) Ibex operation.\n")

    return base + f"""

================================================================================
JASPERGOLD FPV FAILED (attempt {attempt}/{MAX_RETRIES}):

The following assertions have issues:
{issue_block}

{cex_note}{vac_note}
--- CURRENT BIND FILE (FIX THIS) ---
{bind_content}

Fix the SVA bind file to resolve these FPV failures.
Use ONLY signals from the AVAILABLE SIGNALS list above.
You may change assertion logic to correctly capture the security intent.
Return ONLY the corrected SystemVerilog bind file (no JSON mapping section).
================================================================================
"""


# ---------------------------------------------------------------------------
# Main FPV loop
# ---------------------------------------------------------------------------

def run_module(module_key: str) -> bool:
    """Step 1D for one module. Returns True on success."""
    cfg       = MODULE_CONFIG[module_key]
    bind_path = ASSERTS_DIR / cfg["bind_file"]

    print(f"\n  [1D] {module_key}: {cfg['bind_file']}")

    if not bind_path.exists():
        print(f"  ERROR: bind file missing -- run steps 1A→1C first.",
              file=sys.stderr)
        return False

    state = _load_state(module_key)
    if state.get("locked"):
        print(f"  LOCKED: exhausted FPV retries.")
        print(f"  ESCALATE: manual fix required for {bind_path.name}")
        return False

    jg_bin = shutil.which("jg")
    if not jg_bin:
        print("  ERROR: 'jg' not on PATH -- run this step on the EDA server.",
              file=sys.stderr)
        sys.exit(2)

    ERRORS_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    baseline_f = RESULTS_DIR / f"{module_key}_fpv_baseline.txt"
    vacuity_f  = RESULTS_DIR / f"{module_key}_vacuity.txt"
    cov_f      = RESULTS_DIR / f"{module_key}_cov.txt"

    tcl_path   = RESULTS_DIR / f"{module_key}_jg.tcl"

    for attempt in range(1, MAX_RETRIES + 2):
        ts = datetime.now(timezone.utc).isoformat()

        # Generate TCL
        tcl_content = _gen_tcl(module_key, bind_path, baseline_f, vacuity_f, cov_f)
        tcl_path.write_text(tcl_content, encoding="utf-8")

        print(f"  [1D] Attempt {attempt} -- running JasperGold ...")
        retcode, jg_out = _run_jg(jg_bin, tcl_path)

        # Parse report files
        baseline = _parse_baseline(baseline_f)
        vacuity  = _parse_vacuity(vacuity_f)

        if not baseline:
            # JasperGold failed to produce a report -- treat as fail
            issues = [f"JasperGold did not produce results (exit {retcode})"]
        else:
            all_pass, issues = _fpv_passed(baseline, vacuity)
            if all_pass:
                tar, pnv, total = _update_tar(module_key, baseline, vacuity, ts)
                print(f"  [1D] PASS -- all assertions Proven + non-vacuous.")
                print(f"  [1D] TAR = {pnv}/{total} = {tar}%")
                _save_state(module_key, {"locked": False, "status": "pass",
                                         "retries_used": attempt - 1,
                                         "TAR": tar, "timestamp": ts})
                return True

        if attempt > MAX_RETRIES:
            break

        # Log failure
        err_path = ERRORS_DIR / f"{module_key}_fpv_{attempt}.log"
        err_path.write_text(
            f"Module: {module_key}\nAttempt: {attempt}\nTimestamp: {ts}\n"
            f"Issues:\n" + "\n".join(f"  {i}" for i in issues) + f"\n\n{jg_out}",
            encoding="utf-8"
        )
        print(f"  [1D] FAIL  -- {len(issues)} issue(s): {', '.join(issues[:3])}")
        print(f"  [1D] Logged: errors/archive/{err_path.name}")
        print(f"  [1D] DeepSeek Pro retry {attempt}/{MAX_RETRIES} ...")

        bind_content = bind_path.read_text(encoding="utf-8")
        prompt       = _retry_prompt(module_key, bind_content, issues, attempt)
        raw          = run_deepseek(prompt, model=DEEPSEEK_PRO, timeout=300)

        raw_dir = ROOT / "results" / "raw"
        raw_dir.mkdir(parents=True, exist_ok=True)
        (raw_dir / f"{module_key}_fpv_retry_{attempt}.txt").write_text(
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
            print(f"  [1D] Bind file updated by Pro.")
        else:
            print(f"  [1D] WARNING: could not parse Pro output, retrying unchanged.")

    # Exhausted
    final_err = ERRORS_DIR / f"{module_key}_fpv_{MAX_RETRIES + 1}.log"
    final_err.write_text(
        f"Module: {module_key}\nFinal failure after {MAX_RETRIES} FPV retries\n"
        f"Timestamp: {ts}\nIssues:\n" + "\n".join(f"  {i}" for i in issues),
        encoding="utf-8"
    )
    _save_state(module_key, {"locked": True, "status": "fail",
                              "retries_used": MAX_RETRIES, "timestamp": ts})
    print(f"\n  [1D] ESCALATE: {module_key} FAILED after {MAX_RETRIES} FPV retries.")
    print(f"  Logs: errors/archive/{module_key}_fpv_*.log")
    return False


def main():
    ap = argparse.ArgumentParser(
        description="validate_fpv.py -- Step 1D JasperGold FPV baseline"
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
    print("  STEP 1D SUMMARY")
    print(f"{'='*50}")
    for m, ok in results.items():
        log_path = LOGS_DIR / f"{m}_tar_log.json"
        tar_str  = "--"
        if log_path.exists():
            try:
                d = json.loads(log_path.read_text(encoding="utf-8"))
                if "TAR" in d:
                    tar_str = f"TAR={d['TAR']}%"
            except Exception:
                pass
        print(f"  {m:<6}  {'PASS' if ok else 'FAIL'}  {tar_str}")

    failed = [m for m, ok in results.items() if not ok]
    if failed:
        print(f"\n  FAILED: {', '.join(failed)}")
        sys.exit(1)
    print("\n  All modules passed FPV.")
    print("  Next: python scripts/run_step1.py --status")


if __name__ == "__main__":
    main()
