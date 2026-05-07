#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Step 1B: Claude Code CLI Translation
=======================================================
Assembles prompt inline from:
  prompts/<seq|comb>_prompt.txt  (selected from signals.json type)
  results/signals/<MODULE>_signals.json
  assertion_dataset/ns31a_<MODULE>.csv
Runs: claude -p "<assembled prompt>"
Output: assertions/<MODULE>_bind.sv  +  scripts/logs/<MODULE>_tar_log.json
"""
