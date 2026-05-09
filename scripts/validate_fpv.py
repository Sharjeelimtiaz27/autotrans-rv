#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Step 1D: JasperGold FPV Baseline (Proven + non-vacuous)
=======================================================
Input:  assertions/translated/<MODULE>_bind.sv + rtl/ibex/original/<MODULE>.sv
Output: results/step1/<MODULE>_fpv_baseline.txt
        results/step1/<MODULE>_vacuity.txt
        results/step1/<MODULE>_cov.txt

Pass criteria (BOTH required):
  1. All properties Proven (no CEX)
  2. All properties non-vacuous (check_vacuity passes)

CEX on clean RTL = translation error -> retry (not a Trojan finding).
Max 3 JasperGold retries. After 3 failures: set locked=true.
"""
