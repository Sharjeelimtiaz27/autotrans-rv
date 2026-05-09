#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Environment setup checker for ai-autotrans-rv.

Run once after cloning the repository:
  python scripts/setup_env.py

Checks and installs:
  1. Python >= 3.10
  2. Python packages (pyverilog, pandas, anthropic)
  3. Node.js (required for Claude Code CLI)
  4. Claude Code CLI  (@anthropic-ai/claude-code via npm)

Does NOT install Node.js automatically (requires system package manager).
Prints exact commands to run if anything is missing.

Note on API keys
----------------
The Claude Code CLI uses your Claude.ai subscription (Claude Pro or Max plan)
via OAuth login — NOT a paid Anthropic API key. After installing the CLI, run:
  claude login
and sign in with your Claude.ai account in the browser. No extra cost.
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OK   = "[OK]"
FAIL = "[MISSING]"
WARN = "[WARN]"


def check(label: str, ok: bool, fix: str = "") -> bool:
    status = OK if ok else FAIL
    print(f"  {status:<12} {label}")
    if not ok and fix:
        print(f"             Fix: {fix}")
    return ok


def run_silent(*cmd) -> tuple:
    """Return (stdout, returncode)."""
    try:
        r = subprocess.run(list(cmd), capture_output=True, text=True, timeout=30)
        return r.stdout.strip(), r.returncode
    except Exception:
        return "", 1


def main():
    print("\n=== ai-autotrans-rv — environment check ===\n")
    all_ok = True

    # 1. Python version
    major, minor = sys.version_info[:2]
    ok = (major, minor) >= (3, 10)
    all_ok &= check(f"Python >= 3.10  (found {major}.{minor})", ok,
                    "Download Python 3.10+ from https://www.python.org/downloads/")

    # 2. Python packages
    for pkg in ("pyverilog", "pandas", "anthropic"):
        out, rc = run_silent(sys.executable, "-c", f"import {pkg}; print({pkg}.__version__)")
        ok = rc == 0
        all_ok &= check(f"Python package: {pkg}" + (f" ({out})" if ok else ""), ok,
                        f"python -m pip install {pkg}")

    # 3. Node.js
    out, rc = run_silent("node", "--version")
    ok = rc == 0
    all_ok &= check(f"Node.js" + (f" ({out})" if ok else ""), ok,
                    "Windows: winget install OpenJS.NodeJS.LTS\n"
                    "             macOS:   brew install node\n"
                    "             Linux:   sudo apt install nodejs npm")

    # 4. npm
    out, rc = run_silent("npm", "--version")
    ok = rc == 0
    all_ok &= check(f"npm" + (f" ({out})" if ok else ""), ok,
                    "Installed with Node.js — see above")

    # 5. Claude Code CLI
    claude_exe = _find_claude()
    out, rc = run_silent(claude_exe, "--version")
    ok = rc == 0
    all_ok &= check(f"Claude Code CLI" + (f" ({out})" if ok else ""), ok,
                    "npm install -g @anthropic-ai/claude-code")

    # 6. Claude auth check
    if ok:
        out2, rc2 = run_silent(claude_exe, "--allowedTools", "", "-p", "reply: AUTH_OK")
        auth_ok = rc2 == 0 and "AUTH_OK" in out2
        all_ok &= check("Claude Code CLI authenticated", auth_ok,
                        "Run: claude login   (opens browser — use your Claude.ai account)\n"
                        "             No API key needed — uses your Claude.ai subscription.")

    print()
    if all_ok:
        print("  All checks passed. Ready to run the pipeline.\n")
        print("  One-command local translation (all 9 modules):")
        print("    python scripts/run_step1.py --all-modules --mode local\n")
        print("  Single module:")
        print("    python scripts/run_step1.py --module pmp --mode local\n")
        print("  After git push, on the server (QuestaSim + JasperGold):")
        print("    python scripts/run_step1.py --all-modules --mode server\n")
    else:
        print("  Fix the items above and re-run: python scripts/setup_env.py\n")

    return 0 if all_ok else 1


def _find_claude() -> str:
    found = shutil.which("claude") or shutil.which("claude.cmd")
    if found:
        return found
    fallback = r"C:\Users\shimti\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe"
    if Path(fallback).exists():
        return fallback
    return "claude"


if __name__ == "__main__":
    sys.exit(main())
