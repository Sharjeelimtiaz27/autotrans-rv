"""
ablation_no_rvsigex.py
Runs DeepSeek V4-Flash on PMP with NO RV-SigEx grounding.
Baseline for the ablation study in §4.4 of the BEC 2026 paper.
Usage: python scripts/ablation_no_rvsigex.py
Output: assertions/ablation/pmp_no_rvsigex_bind.sv
"""

import os, csv, json
from pathlib import Path
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key=os.environ["NVIDIA_API_KEY"]
)

# Load NS31A PMP assertions (same source as the main pipeline)
csv_path = Path("assertion_dataset/ns31a_pmp.csv")
rows = []
with open(csv_path) as f:
    for r in csv.DictReader(f):
        rows.append(r)

ns31a_text = "\n".join(
    f"Group {i+1}: [{r['property_id']}] {r['description']}\nSVA: {r['sva']}"
    for i, r in enumerate(rows)
)

# Minimal prompt — NO signal list, NO template, NO rules, NO pkg types
PROMPT = f"""You are an expert hardware security verification engineer.

Translate the following NS31A security assertions for the NS31A reference RISC-V processor
into equivalent SystemVerilog Assertions (SVA) for the Ibex RISC-V processor module ibex_pmp.

Target module: ibex_pmp
Clock: clk_i
Reset: rst_ni (active low)

NS31A SOURCE ASSERTIONS:
{ns31a_text}

Return a complete, compilable SystemVerilog bind file for ibex_pmp.
"""

print("Calling DeepSeek V4-Flash (no RV-SigEx grounding)...")
response = client.chat.completions.create(
    model="deepseek-ai/deepseek-v4-flash",
    messages=[{"role": "user", "content": PROMPT}],
    temperature=0.0,
    seed=42,
    max_tokens=4096,
)

output = response.choices[0].message.content

out_path = Path("assertions/ablation/pmp_no_rvsigex_bind.sv")
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(output)
print(f"Saved: {out_path}")

# Count signal names in output and cross-check against ibex_pmp.sv
import re
sv_path = Path("rtl/ibex/original/ibex_pmp.sv")
rtl_text = sv_path.read_text()

# Extract all identifiers from the generated bind file
gen_identifiers = set(re.findall(r'\b([a-z][a-z0-9_]*)\b', output.lower()))
# Extract port/signal names from ibex_pmp.sv (rough: words after input/output/logic)
rtl_signals = set(re.findall(r'(?:input|output|logic)\s+(?:\[[^\]]+\]\s+)?(\w+)', rtl_text))

# Find identifiers in bind that look like signal names (not keywords/types)
sv_keywords = {'module','endmodule','input','output','logic','property','endproperty',
               'assert','always','posedge','negedge','disable','iff','import','bind',
               'if','else','for','begin','end','parameter','localparam','typedef',
               'enum','struct','packed','unsigned','signed','clk_i','rst_ni',
               'integer','int','bit','byte','shortint','longint','real'}

# Signals used in assertions (inside property bodies)
prop_body = re.findall(r'property\s+\w+.*?endproperty', output, re.DOTALL)
used_sigs = set()
for p in prop_body:
    used_sigs.update(re.findall(r'\b([a-z][a-z0-9_]{2,})\b', p.lower()))
used_sigs -= sv_keywords

invented = sorted(s for s in used_sigs if s not in rtl_text.lower() and len(s) > 3)

print(f"\n=== ABLATION RESULTS ===")
print(f"Total property-body identifiers:  {len(used_sigs)}")
print(f"Not found in ibex_pmp.sv RTL:     {len(invented)}")
print(f"Invented signal names:")
for s in invented[:20]:
    print(f"  {s}")

# Save results JSON
results = {
    "module": "pmp",
    "condition": "no_rvsigex",
    "total_identifiers_in_properties": len(used_sigs),
    "invented_signals": len(invented),
    "invented_signal_names": invented,
    "ns31a_groups": len(rows),
}
Path("results/logs/pmp_ablation.json").write_text(json.dumps(results, indent=2))
print(f"\nSaved results: results/logs/pmp_ablation.json")
print("\nNext: run QuestaSim compile on assertions/ablation/pmp_no_rvsigex_bind.sv")
print("  vlog -sv rtl/ibex/original/ibex_pkg.sv rtl/ibex/original/ibex_pmp.sv assertions/ablation/pmp_no_rvsigex_bind.sv")
