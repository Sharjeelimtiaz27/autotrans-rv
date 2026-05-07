#!/usr/bin/env python3
"""
Step 1A: Ibex RTL Parser -> signals.json
Input:  rtl/ibex/original/<MODULE>.sv
Output: results/signals/<MODULE>_signals.json
"""
import re, json, argparse, sys
from pathlib import Path

# ── Module → RTL file(s) ─────────────────────────────────────────────────────
MODULE_RTL_MAP = {
    "pmp": ["ibex_pmp.sv"],
    "csr": ["ibex_cs_registers.sv"],
    "do":  ["ibex_controller.sv"],
    "eti": ["ibex_controller.sv"],
    "cf":  ["ibex_controller.sv"],
    "mt":  ["ibex_controller.sv"],
    "ma":  ["ibex_load_store_unit.sv"],
    "ie":  ["ibex_id_stage.sv", "ibex_ex_block.sv"],
    "ru":  ["ibex_wb_stage.sv"],
}

RTL_DIR    = Path("rtl/ibex/original")
OUTPUT_DIR = Path("results/signals")

_TYPE_KEYWORDS = frozenset({
    "int", "bit", "logic", "wire", "reg", "unsigned", "signed",
    "parameter", "localparam", "integer", "shortint", "longint", "byte"
})

# ── Text helpers ─────────────────────────────────────────────────────────────

def strip_comments(text):
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    return text


def find_close_paren(text, open_idx):
    """Return index of ')' matching '(' at text[open_idx]."""
    depth = 0
    for i in range(open_idx, len(text)):
        if   text[i] == '(': depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return len(text) - 1


def split_top_commas(text):
    """Split by commas that are not inside any brackets."""
    parts, depth, buf = [], 0, []
    for c in text:
        if   c in '([': depth += 1; buf.append(c)
        elif c in ')]': depth -= 1; buf.append(c)
        elif c == ',' and depth == 0:
            parts.append(''.join(buf).strip()); buf = []
        else:
            buf.append(c)
    if buf:
        parts.append(''.join(buf).strip())
    return parts

# ── Width helpers ─────────────────────────────────────────────────────────────

def bracket_to_width(inner):
    """'31:0' -> 32,  '7:0' -> 8,  'N-1:0' -> 'N-1:0' (parametric string)."""
    m = re.match(r'\s*(\d+)\s*:\s*(\d+)\s*$', inner)
    if m:
        return int(m.group(1)) - int(m.group(2)) + 1
    return inner.strip()

# ── Port-list extraction ──────────────────────────────────────────────────────

def extract_port_list(content):
    """
    Return (port_list_text, end_of_header_pos) from the comment-stripped content.
    Handles both:
      module foo #(params) (ports);
      module foo import pkg::*; #(params) (ports);
    """
    mod_m = re.search(r'\bmodule\b', content)
    if not mod_m:
        return "", 0
    text = content[mod_m.start():]

    # Skip #(...) param block if present
    search_from = 0
    hash_m = re.search(r'#\s*\(', text)
    if hash_m:
        hp = text.index('(', hash_m.start())
        hp_end = find_close_paren(text, hp)
        search_from = hp_end + 1

    # Port list is the next (...) after search_from
    port_open  = text.index('(', search_from)
    port_close = find_close_paren(text, port_open)
    port_text  = text[port_open + 1 : port_close]

    # Header ends at ';' after the closing paren
    semi = text.index(';', port_close)
    header_end = mod_m.start() + semi + 1

    return port_text, header_end

# ── Port parser ───────────────────────────────────────────────────────────────

def parse_ports(port_list_text):
    inputs, outputs = [], []
    for entry in split_top_commas(port_list_text):
        entry = entry.strip()
        if not entry:
            continue

        # Direction
        dir_m = re.match(r'(input|output|inout)\b', entry)
        if not dir_m:
            continue
        direction = dir_m.group(1)
        if direction == 'inout':
            continue
        entry = entry[dir_m.end():].strip()

        # Strip leading wire/var
        entry = re.sub(r'^(wire|var)\s+', '', entry).strip()

        # Strip trailing array suffix  e.g.  name [PMPNumChan]  or  name [3:0]
        array_sfx = ''
        arr_m = re.search(r'(\[[^\[]*\])\s*$', entry)
        # Only strip if it follows an identifier (i.e. the array comes after the name)
        if arr_m:
            before = entry[:arr_m.start()].rstrip()
            if re.search(r'\w$', before):          # last char before [ is word char
                array_sfx = arr_m.group(1).strip()
                entry = before

        # Signal name = last identifier
        name_m = re.search(r'(\w+)\s*$', entry)
        if not name_m:
            continue
        name      = name_m.group(1)
        type_part = entry[:name_m.start()].strip()

        # Width from type_part
        width_m = re.search(r'\[([^\]]+)\]', type_part)
        if width_m:
            width = bracket_to_width(width_m.group(1))
        else:
            # Remove 'logic' to expose package type if any
            bare = re.sub(r'\blogic\b', '', type_part).strip()
            if bare:
                width = bare + (array_sfx if array_sfx else '')
            elif array_sfx:
                width = f'1{array_sfx}'
            else:
                width = 1

        port = {"name": name, "width": width}
        (inputs if direction == 'input' else outputs).append(port)

    return inputs, outputs

# ── Internal signals ──────────────────────────────────────────────────────────

def extract_internals(body, port_names):
    """Grab  logic [W1][W2]... name ;  declarations from module body."""
    internals, seen = [], set(port_names)
    for m in re.finditer(
        r'\blogic\b\s*((?:\[[^\]]+\]\s*)*)(\w+)\s*(?:\[[^\]]*\])?\s*;',
        body
    ):
        brackets, name = m.group(1), m.group(2)
        if name in seen:
            continue
        seen.add(name)
        # Use the first packed dimension as the width
        first_m = re.match(r'\[([^\]]+)\]', brackets.strip()) if brackets else None
        width = bracket_to_width(first_m.group(1)) if first_m else 1
        internals.append({"name": name, "width": width})
    return internals

# ── Parameter extraction ──────────────────────────────────────────────────────

def extract_parameters(content):
    params, seen = [], set()
    for m in re.finditer(
        r'\bparameter\b[^=;]*?(\b\w+\b)\s*(?:\[[^\]]*\])?\s*=',
        content
    ):
        name = m.group(1)
        if name not in _TYPE_KEYWORDS and not name.startswith('ibex_') and name not in seen:
            seen.add(name); params.append(name)
    return params

# ── File parser ───────────────────────────────────────────────────────────────

def parse_rtl_file(filepath):
    raw     = filepath.read_text(encoding='utf-8', errors='replace')
    content = strip_comments(raw)

    mod_m       = re.search(r'\bmodule\s+(\w+)', content)
    module_name = mod_m.group(1) if mod_m else filepath.stem
    is_seq      = bool(re.search(r'\balways_ff\b', content))
    parameters  = extract_parameters(content)

    port_text, header_end = extract_port_list(content)
    inputs, outputs       = parse_ports(port_text)

    body       = content[header_end:]
    port_names = {p['name'] for p in inputs + outputs}
    internals  = extract_internals(body, port_names)

    return {
        "module_name": module_name,
        "is_sequential": is_seq,
        "ports": {"inputs": inputs, "outputs": outputs},
        "internals": internals,
        "parameters": parameters,
    }

# ── Merge + build JSON ────────────────────────────────────────────────────────

def build_signals_json(module_key, parsed_list):
    all_inputs, all_outputs, all_internals, all_params = [], [], [], []
    seen, is_seq, mod_names = set(), False, []

    for p in parsed_list:
        mod_names.append(p['module_name'])
        if p['is_sequential']:
            is_seq = True
        for sig in p['ports']['inputs']:
            if sig['name'] not in seen:
                all_inputs.append(sig); seen.add(sig['name'])
        for sig in p['ports']['outputs']:
            if sig['name'] not in seen:
                all_outputs.append(sig); seen.add(sig['name'])
        for sig in p['internals']:
            if sig['name'] not in seen:
                all_internals.append(sig); seen.add(sig['name'])
        for par in p['parameters']:
            if par not in all_params:
                all_params.append(par)

    mod_type = "sequential" if is_seq else "combinational"
    result = {
        "module":      mod_names[0] if len(mod_names) == 1 else mod_names,
        "module_key":  module_key,
        "type":        mod_type,
        "ports":       {"inputs": all_inputs, "outputs": all_outputs},
        "internals":   all_internals,
        "parameters":  all_params,
    }
    if mod_type == "sequential":
        result["clock"]          = "clk_i"
        result["reset"]          = "rst_ni"
        result["reset_polarity"] = "active_low"
    return result

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    ap  = argparse.ArgumentParser(description="Step 1A: Parse Ibex RTL → signals.json")
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--module", choices=list(MODULE_RTL_MAP),
                     help="Single module to parse")
    grp.add_argument("--all-modules", action="store_true",
                     help="Parse all 9 modules")
    args = ap.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    modules = list(MODULE_RTL_MAP) if args.all_modules else [args.module]

    for mod in modules:
        parsed = []
        for fname in MODULE_RTL_MAP[mod]:
            fpath = RTL_DIR / fname
            if not fpath.exists():
                print(f"ERROR: {fpath} not found", file=sys.stderr)
                sys.exit(1)
            print(f"  Parsing {fpath} ...")
            parsed.append(parse_rtl_file(fpath))

        out      = build_signals_json(mod, parsed)
        out_path = OUTPUT_DIR / f"{mod}_signals.json"
        out_path.write_text(json.dumps(out, indent=2))

        ni = len(out['ports']['inputs'])
        no = len(out['ports']['outputs'])
        nn = len(out['internals'])
        print(f"  [{mod}] {out['module']} | {out['type']} | "
              f"in={ni} out={no} internals={nn} -> {out_path}")

if __name__ == "__main__":
    main()
