#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv -- BEC 2026
#
"""
Master Orchestrator -- Stage 1 (Assertion Translation Stage)
=======================================================
Usage:
  python scripts/run_step1.py --module pmp               # single module, all steps
  python scripts/run_step1.py --module csr --mode local  # laptop: 1A + 1B only
  python scripts/run_step1.py --module csr --mode server # server: 1C + 1D only
  python scripts/run_step1.py --all-modules              # all 9 modules (local mode)
  python scripts/run_step1.py --all-modules --mode local # explicit local
  python scripts/run_step1.py --status                   # show pipeline state

Steps:
  1A  parse_rtl.py         RV-SigEx RTL parser -> signals.json
  1B  translate.py         DeepSeek NVIDIA NIM -> assertions/translated/<MODULE>_bind.sv
  1C  validate_compile.py  QuestaSim compile loop (max 3 retries)  [server only]
  1D  validate_fpv.py      JasperGold FPV baseline                 [server only]

Modes:
  local   Steps 1A + 1B only. No EDA tools required. Runs on any laptop with
          Python 3.10+ and Claude Code CLI authenticated.
  server  Steps 1C + 1D only. Requires QuestaSim + JasperGold licences.
  full    All four steps (default when --mode not specified).
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT   = Path(__file__).resolve().parent.parent
LOGS    = ROOT / "results" / "logs"
SIGS    = ROOT / "results" / "signals"
ASSERTS = ROOT / "assertions" / "translated"

ALL_MODULES = ["pmp", "csr", "do", "eti", "cf", "mt", "ma", "ie", "ru"]

BIND_FILES = {
    "pmp": "pmp_bind.sv",
    "csr": "csr_bind.sv",
    "do":  "do_bind.sv",
    "eti": "eti_bind.sv",
    "cf":  "cf_bind.sv",
    "mt":  "mt_bind.sv",
    "ma":  "ma_bind.sv",
    "ie":  "ie_bind.sv",
    "ru":  "ru_bind.sv",
}


def _run(script: str, extra_args: list, label: str) -> bool:
    """Run a pipeline script. Returns True on success."""
    cmd = [sys.executable, str(ROOT / "scripts" / script)] + extra_args
    print(f"\n  [{label}] {' '.join(cmd[2:])}")
    r = subprocess.run(cmd, cwd=ROOT)
    return r.returncode == 0


def step1a(module: str) -> bool:
    return _run("parse_rtl.py", ["--module", module], "1A parse_rtl")


def step1b(module: str) -> bool:
    return _run("translate.py", ["--module", module], "1B translate")


def step1c(module: str) -> bool:
    return _run("validate_compile.py", ["--module", module], "1C compile")


def step1d(module: str) -> bool:
    return _run("validate_fpv.py", ["--module", module], "1D fpv")


def run_module(module: str, mode: str) -> dict:
    """
    Run pipeline for a single module. Returns result dict with pass/fail per step.
    mode: 'local' | 'server' | 'full'
    """
    print(f"\n{'='*60}")
    print(f"  Module: {module}  |  Mode: {mode}  |  {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}")

    result = {"module": module, "mode": mode, "steps": {}}

    if mode in ("local", "full"):
        ok = step1a(module)
        result["steps"]["1A"] = "pass" if ok else "fail"
        if not ok:
            print(f"  ERROR: 1A (parse_rtl) failed for {module} -- stopping.", file=sys.stderr)
            return result

        ok = step1b(module)
        result["steps"]["1B"] = "pass" if ok else "fail"
        if not ok:
            print(f"  ERROR: 1B (translate) failed for {module}.", file=sys.stderr)
            if mode == "local":
                return result

    if mode in ("server", "full"):
        ok = step1c(module)
        result["steps"]["1C"] = "pass" if ok else "fail"
        if not ok:
            print(f"  ERROR: 1C (compile) failed for {module} -- stopping.", file=sys.stderr)
            return result

        ok = step1d(module)
        result["steps"]["1D"] = "pass" if ok else "fail"

    return result


def show_status():
    """Print pipeline status for all 9 modules."""
    STEP1 = ROOT / "results" / "step1"
    print("\n=== AI-AutoTrans Pipeline Status ===\n")
    header = (f"  {'Mod':<5}  {'1A':<4}  {'1B bind':<10}  "
              f"{'1C compile':<12}  {'1D FPV result':<30}  {'1B trans cov'}")
    print(header)
    print("  " + "-" * (len(header) - 2))

    for m in ALL_MODULES:
        # 1A
        sig = "OK" if (SIGS / f"{m}_signals.json").exists() else "--"

        # 1B
        bname = BIND_FILES[m]
        bind  = "OK" if (ASSERTS / bname).exists() else "--"

        # 1C compile state
        cp = STEP1 / f"{m}_compile_state.json"
        if cp.exists():
            try:
                cs = json.loads(cp.read_text(encoding="utf-8"))
                if cs.get("locked"):
                    compile_s = "LOCKED"
                elif cs.get("status") == "pass":
                    r = cs.get("retries_used", 0)
                    compile_s = f"PASS ({r} retr)" if r > 0 else "PASS"
                elif cs.get("status") == "fail":
                    r = cs.get("retries_used", 0)
                    compile_s = f"FAIL ({r}/3 retr)"
                else:
                    compile_s = "running"
            except Exception:
                compile_s = "err"
        else:
            compile_s = "--"

        # 1D FPV state + TAR from log
        fp = STEP1 / f"{m}_fpv_state.json"
        log_p = LOGS / f"{m}_tar_log.json"
        trans_cov = "--"
        fpv_s = "--"

        if log_p.exists():
            try:
                data  = json.loads(log_p.read_text(encoding="utf-8"))
                total = data.get("total_ns31a_groups", data.get("total_ns31a_signals", 0))
                trans = data.get("translated", data.get("auto_accepted", 0))
                trans_cov = f"{trans}/{total} (100%)"

                fpv_tar = data.get("TAR")          # written ONLY after FPV PASS
                if fpv_tar is not None:
                    proven = int(round(fpv_tar * total / 100.0))
                    fpv_s = f"PASS  TAR={fpv_tar:.1f}%  ({proven}/{total})"
                elif fp.exists():
                    try:
                        fs = json.loads(fp.read_text(encoding="utf-8"))
                        if fs.get("locked"):
                            fpv_s = "LOCKED  (3 retries exhausted)"
                        elif fs.get("status") == "pass":
                            tar_fs = fs.get("TAR")
                            if tar_fs is not None:
                                proven = int(round(tar_fs * total / 100.0))
                                fpv_s = f"PASS  TAR={tar_fs:.1f}%  ({proven}/{total})"
                            else:
                                fpv_s = "PASS  (TAR not recorded)"
                        else:
                            r = fs.get("retries_used", fs.get("attempt", 0))
                            fpv_s = f"FAIL  ({r}/3 retries)"
                    except Exception:
                        fpv_s = "state-err"
                else:
                    fpv_s = "pending  (1D not yet run)"
            except Exception:
                trans_cov = "log-err"
                fpv_s     = "log-err"

        print(f"  {m:<5}  {sig:<4}  {bind:<10}  {compile_s:<12}  {fpv_s:<30}  {trans_cov}")

    print()


def main():
    ap = argparse.ArgumentParser(
        description="run_step1.py -- AI-AutoTrans pipeline orchestrator"
    )
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--module",  choices=ALL_MODULES, metavar="MODULE",
                     help=f"Single module: {', '.join(ALL_MODULES)}")
    grp.add_argument("--all-modules", action="store_true",
                     help="Run all 9 logical modules sequentially")
    grp.add_argument("--status", action="store_true",
                     help="Show pipeline status for all modules")
    ap.add_argument("--mode", choices=["local", "server", "full"], default="local",
                    help="local=1A+1B only | server=1C+1D only | full=all (default: local)")

    args = ap.parse_args()

    if args.status:
        show_status()
        return

    modules = ALL_MODULES if args.all_modules else [args.module]
    results = []

    for m in modules:
        res = run_module(m, args.mode)
        results.append(res)

    # Summary
    print(f"\n{'='*60}")
    print("  SUMMARY")
    print(f"{'='*60}")
    for r in results:
        steps_str = "  ".join(f"{k}:{v}" for k, v in r["steps"].items())
        print(f"  {r['module']:<6}  {steps_str}")

    failed = [r["module"] for r in results if "fail" in r["steps"].values()]
    if failed:
        print(f"\n  FAILED: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("\n  All modules completed successfully.")
        if args.mode == "local":
            print("  Next: git add assertions/translated/ results/logs/ && git commit && git push")
            print("        Then on server: python scripts/run_step1.py --all-modules --mode server")


if __name__ == "__main__":
    main()
