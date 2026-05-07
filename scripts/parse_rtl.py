#!/usr/bin/env python3
"""
Step 1A: Ibex RTL Parser -> signals.json
Input:  rtl/ibex/original/<MODULE>.sv  +  rtl/ibex/original/ibex_pkg.sv
Output: results/signals/<MODULE>_signals.json

JSON sections
  ports        - input/output port names and widths
  internals    - internal logic signal declarations
  parameters   - module parameter names
  pkg_types    - enum/struct definitions from ibex_pkg (only types used by this module)
  connectivity - assign-statement signal dependencies (lhs -> rhs signals)
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
PKG_FILE   = RTL_DIR / "ibex_pkg.sv"

_TYPE_KEYWORDS = frozenset({
    "int", "bit", "logic", "wire", "reg", "unsigned", "signed",
    "parameter", "localparam", "integer", "shortint", "longint", "byte"
})

# ── Text helpers ──────────────────────────────────────────────────────────────

def strip_comments(text):
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    return text


def find_close_paren(text, open_idx):
    depth = 0
    for i in range(open_idx, len(text)):
        if   text[i] == '(': depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return len(text) - 1


def split_top_commas(text):
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
    m = re.match(r'\s*(\d+)\s*:\s*(\d+)\s*$', inner)
    if m:
        return int(m.group(1)) - int(m.group(2)) + 1
    return inner.strip()

# ── ibex_pkg.sv parser ────────────────────────────────────────────────────────

def parse_ibex_pkg(pkg_path):
    """
    Parse all typedef enum and typedef struct packed from ibex_pkg.sv.
    Returns dict: { type_name -> {kind, base_type/fields, values} }
    """
    raw     = pkg_path.read_text(encoding='utf-8', errors='replace')
    content = strip_comments(raw)
    types   = {}

    # typedef enum BASE_TYPE { NAME = VAL, ... } type_name_e;
    for m in re.finditer(
        r'typedef\s+enum\s+([\w\s:\[\]]+?)\s*\{([^}]+)\}\s*(\w+)\s*;',
        content, re.DOTALL
    ):
        base_type = re.sub(r'\s+', ' ', m.group(1).strip())
        body      = m.group(2)
        type_name = m.group(3)

        values = {}
        for vm in re.finditer(r'(\w+)\s*(?:=\s*([^,\n}]+))?', body):
            name = vm.group(1)
            val  = vm.group(2).strip() if vm.group(2) else None
            if name:
                values[name] = val
        types[type_name] = {"kind": "enum", "base_type": base_type, "values": values}

    # typedef struct packed { fields } type_name_t;
    for m in re.finditer(
        r'typedef\s+struct\s+packed\s*\{([^}]+)\}\s*(\w+)\s*;',
        content, re.DOTALL
    ):
        body      = m.group(1)
        type_name = m.group(2)

        fields = []
        for fm in re.finditer(
            r'\b((?:logic|bit)\s*(?:\[[^\]]+\])?|[\w]+(?:::\w+)?)\s+(\w+)\s*;',
            body
        ):
            field_type = re.sub(r'\s+', ' ', fm.group(1).strip())
            field_name = fm.group(2)
            fields.append({"name": field_name, "type": field_type})
        types[type_name] = {"kind": "struct", "fields": fields}

    return types


def filter_pkg_types(pkg_types, signals_json):
    """Return only pkg types referenced by this module's ports/internals."""
    # Collect all width strings from ports and internals
    all_text = []
    for p in signals_json['ports']['inputs'] + signals_json['ports']['outputs']:
        all_text.append(str(p['width']))
    for s in signals_json['internals']:
        all_text.append(str(s['width']))
    combined = ' '.join(all_text)

    used = {}
    for type_name, type_def in pkg_types.items():
        if type_name in combined:
            used[type_name] = type_def
    return used

# ── Connectivity (assign statements) ─────────────────────────────────────────

def extract_connectivity(body, all_signal_names):
    """
    Extract assign statements from module body.
    Returns list of {lhs, rhs, rhs_signals}.
    """
    connectivity = []
    for m in re.finditer(r'\bassign\s+([\w.]+)\s*=\s*([^;]+);', body):
        lhs = m.group(1)
        rhs = m.group(2).strip()
        rhs_signals = list(dict.fromkeys(
            w for w in re.findall(r'\b(\w+)\b', rhs)
            if w in all_signal_names and w != lhs
        ))
        connectivity.append({"lhs": lhs, "rhs": rhs, "rhs_signals": rhs_signals})
    return connectivity

# ── Port-list extraction ──────────────────────────────────────────────────────

def extract_port_list(content):
    mod_m = re.search(r'\bmodule\b', content)
    if not mod_m:
        return "", 0
    text = content[mod_m.start():]

    search_from = 0
    hash_m = re.search(r'#\s*\(', text)
    if hash_m:
        hp     = text.index('(', hash_m.start())
        hp_end = find_close_paren(text, hp)
        search_from = hp_end + 1

    port_open  = text.index('(', search_from)
    port_close = find_close_paren(text, port_open)
    port_text  = text[port_open + 1 : port_close]

    semi       = text.index(';', port_close)
    header_end = mod_m.start() + semi + 1
    return port_text, header_end

# ── Port parser ───────────────────────────────────────────────────────────────

def parse_ports(port_list_text):
    inputs, outputs = [], []
    for entry in split_top_commas(port_list_text):
        entry = entry.strip()
        if not entry:
            continue

        dir_m = re.match(r'(input|output|inout)\b', entry)
        if not dir_m:
            continue
        direction = dir_m.group(1)
        if direction == 'inout':
            continue
        entry = entry[dir_m.end():].strip()
        entry = re.sub(r'^(wire|var)\s+', '', entry).strip()

        # Strip trailing unpacked array suffix: name [N]
        array_sfx = ''
        arr_m = re.search(r'(\[[^\[]*\])\s*$', entry)
        if arr_m:
            before = entry[:arr_m.start()].rstrip()
            if re.search(r'\w$', before):
                array_sfx = arr_m.group(1).strip()
                entry = before

        name_m = re.search(r'(\w+)\s*$', entry)
        if not name_m:
            continue
        name      = name_m.group(1)
        type_part = entry[:name_m.start()].strip()

        width_m = re.search(r'\[([^\]]+)\]', type_part)
        if width_m:
            width = bracket_to_width(width_m.group(1))
        else:
            bare = re.sub(r'\blogic\b', '', type_part).strip()
            if bare:
                width = bare + (array_sfx if array_sfx else '')
            elif array_sfx:
                width = f'1{array_sfx}'
            else:
                width = 1

        (inputs if direction == 'input' else outputs).append({"name": name, "width": width})
    return inputs, outputs

# ── Internal signals ──────────────────────────────────────────────────────────

def extract_internals(body, port_names):
    internals, seen = [], set(port_names)
    for m in re.finditer(
        r'\blogic\b\s*((?:\[[^\]]+\]\s*)*)(\w+)\s*(?:\[[^\]]*\])?\s*;',
        body
    ):
        brackets, name = m.group(1), m.group(2)
        if name in seen:
            continue
        seen.add(name)
        first_m = re.match(r'\[([^\]]+)\]', brackets.strip()) if brackets else None
        width   = bracket_to_width(first_m.group(1)) if first_m else 1
        internals.append({"name": name, "width": width})
    return internals

# ── Parameter extraction ──────────────────────────────────────────────────────

def extract_parameters(content):
    params, seen = [], set()
    for m in re.finditer(
        r'\bparameter\b[^=;]*?(\b\w+\b)\s*(?:\[[^\]]*\])?\s*=', content
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

    # Connectivity: all known signals for RHS lookup
    all_names = port_names | {s['name'] for s in internals}
    connectivity = extract_connectivity(body, all_names)

    return {
        "module_name":  module_name,
        "is_sequential": is_seq,
        "ports":        {"inputs": inputs, "outputs": outputs},
        "internals":    internals,
        "parameters":   parameters,
        "body":         body,          # passed through for merge; not written to JSON
        "connectivity": connectivity,
    }

# ── Merge + build JSON ────────────────────────────────────────────────────────

def build_signals_json(module_key, parsed_list, pkg_types):
    all_inputs, all_outputs, all_internals, all_params = [], [], [], []
    all_connectivity = []
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
        all_connectivity.extend(p['connectivity'])

    mod_type = "sequential" if is_seq else "combinational"
    result = {
        "module":       mod_names[0] if len(mod_names) == 1 else mod_names,
        "module_key":   module_key,
        "type":         mod_type,
        "ports":        {"inputs": all_inputs, "outputs": all_outputs},
        "internals":    all_internals,
        "parameters":   all_params,
    }
    if mod_type == "sequential":
        result["clock"]          = "clk_i"
        result["reset"]          = "rst_ni"
        result["reset_polarity"] = "active_low"

    # Filter pkg_types to only those referenced by this module
    result["pkg_types"]    = filter_pkg_types(pkg_types, result)
    result["connectivity"] = all_connectivity
    return result

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    ap  = argparse.ArgumentParser(description="Step 1A: Parse Ibex RTL → signals.json")
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--module", choices=list(MODULE_RTL_MAP))
    grp.add_argument("--all-modules", action="store_true")
    args = ap.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Parse ibex_pkg.sv once
    if not PKG_FILE.exists():
        print(f"ERROR: {PKG_FILE} not found", file=sys.stderr); sys.exit(1)
    print(f"  Loading package types from {PKG_FILE} ...")
    pkg_types = parse_ibex_pkg(PKG_FILE)
    print(f"  Found {len(pkg_types)} types in ibex_pkg.sv")

    modules = list(MODULE_RTL_MAP) if args.all_modules else [args.module]

    for mod in modules:
        parsed = []
        for fname in MODULE_RTL_MAP[mod]:
            fpath = RTL_DIR / fname
            if not fpath.exists():
                print(f"ERROR: {fpath} not found", file=sys.stderr); sys.exit(1)
            print(f"  Parsing {fpath} ...")
            parsed.append(parse_rtl_file(fpath))

        out = build_signals_json(mod, parsed, pkg_types)

        # Remove internal 'body' field before writing
        for p in parsed:
            p.pop('body', None)

        out_path = OUTPUT_DIR / f"{mod}_signals.json"
        out_path.write_text(json.dumps(out, indent=2))

        ni = len(out['ports']['inputs'])
        no = len(out['ports']['outputs'])
        nn = len(out['internals'])
        nc = len(out['connectivity'])
        nt = len(out['pkg_types'])
        print(f"  [{mod}] {out['module']} | {out['type']} | "
              f"in={ni} out={no} int={nn} assign={nc} pkg_types={nt} -> {out_path}")

if __name__ == "__main__":
    main()
