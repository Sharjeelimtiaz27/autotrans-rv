#!/usr/bin/env python3
#
# Author  : Sharjeel Imtiaz
#           Tallinn University of Technology (TalTech)
#
# Contact : sharjeel.imtiaz@taltech.ee
# Project : ai-autotrans-rv — BEC 2026
#
"""
Step 1A: SystemVerilog RTL Parser  ->  signals.json
=======================================================
Designed for Ibex RISC-V RTL but general-purpose:
  any synthesisable .sv module can be parsed with --sv-file.

PyVerilog is not used directly because it does not support
SystemVerilog types (logic, bit, always_ff, package imports).
This parser uses structured regex on comment-stripped text,
which is reliable for ANSI-style SV port declarations.

Usage (Ibex pipeline):
  python scripts/parse_rtl.py --module pmp
  python scripts/parse_rtl.py --all-modules

Usage (any SV module):
  python scripts/parse_rtl.py --sv-file path/to/module.sv
  python scripts/parse_rtl.py --sv-file path/to/module.sv --pkg-file path/to/pkg.sv

Output: results/signals/<MODULE>_signals.json

JSON sections
  module       - module name (or list for merged modules like IE)
  module_key   - CLI key used  (e.g. "csr")
  type         - "sequential" | "combinational"  (always_ff presence)
  clock        - clock signal name  (sequential only)
  reset        - reset signal name  (sequential only)
  reset_polarity - "active_low" | "active_high"  (sequential only)
  ports        - {inputs: [{name, width}], outputs: [{name, width}]}
  internals    - [{name, width}]  internal logic/wire/reg declarations
  parameters   - [name]  parameter names
  pkg_types    - enum/struct defs from pkg file, filtered to types used here
  connectivity - [{lhs, rhs, rhs_signals, source}]  signal-level dependencies

"""
import re, json, argparse, sys
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
#  Ibex-specific config  (only used with --module / --all-modules)
# ─────────────────────────────────────────────────────────────────────────────

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

# Keywords that can appear between 'parameter' and the actual name
_PARAM_TYPE_WORDS = frozenset({
    "int", "bit", "logic", "wire", "reg", "unsigned", "signed",
    "parameter", "localparam", "integer", "shortint", "longint",
    "byte", "automatic", "static"
})

# SV type keywords that are NOT signal names
_SV_KEYWORDS = frozenset({
    "module", "endmodule", "input", "output", "inout", "wire", "reg",
    "logic", "bit", "integer", "int", "byte", "parameter", "localparam",
    "assign", "always", "always_ff", "always_comb", "always_latch",
    "begin", "end", "if", "else", "case", "casez", "casex", "endcase",
    "for", "while", "do", "repeat", "forever", "fork", "join",
    "function", "endfunction", "task", "endtask", "generate", "endgenerate",
    "initial", "final", "posedge", "negedge", "and", "or", "not",
    "nand", "nor", "xor", "xnor", "buf", "bufif0", "bufif1",
    "typedef", "struct", "enum", "union", "packed", "unsigned", "signed",
    "import", "export", "package", "endpackage", "interface", "endinterface",
    "modport", "clocking", "endclocking", "property", "endproperty",
    "sequence", "endsequence", "assert", "assume", "cover", "restrict",
    "disable", "iff", "throughout", "within", "intersect", "first_match",
    "default", "unique", "priority", "automatic", "static", "virtual",
})

# ─────────────────────────────────────────────────────────────────────────────
#  Text utilities
# ─────────────────────────────────────────────────────────────────────────────

def strip_comments(text: str) -> str:
    """Remove // and /* */ comments."""
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    return text


def strip_sv_directives(text: str) -> str:
    """Remove `include, `define, `ifdef etc. (keep newlines for line count)."""
    text = re.sub(r'`include\s+"[^"]*"', '', text)
    text = re.sub(r'`include\s+<[^>]*>', '', text)
    # Remove other backtick directives but NOT `define expansions inside code
    text = re.sub(r'^`[a-zA-Z_]\w*[^\n]*', '', text, flags=re.MULTILINE)
    return text


def find_close_paren(text: str, open_idx: int) -> int:
    """Return index of ')' that balances '(' at open_idx."""
    depth = 0
    for i in range(open_idx, len(text)):
        if   text[i] == '(': depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return len(text) - 1


def find_close_brace(text: str, open_idx: int) -> int:
    """Return index of '}' that balances '{' at open_idx."""
    depth = 0
    for i in range(open_idx, len(text)):
        if   text[i] == '{': depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return i
    return len(text) - 1


def split_top_commas(text: str) -> list:
    """Split text by commas not inside any bracket/paren/brace."""
    parts, depth, buf = [], 0, []
    for c in text:
        if   c in '([{': depth += 1; buf.append(c)
        elif c in ')]}': depth -= 1; buf.append(c)
        elif c == ',' and depth == 0:
            parts.append(''.join(buf).strip()); buf = []
        else:
            buf.append(c)
    if buf:
        parts.append(''.join(buf).strip())
    return parts

# ─────────────────────────────────────────────────────────────────────────────
#  Width helpers
# ─────────────────────────────────────────────────────────────────────────────

def bracket_to_width(inner: str):
    """
    Convert bracket content to a width value.
    '31:0'  ->  32   (integer)
    '7:0'   ->  8    (integer)
    'N-1:0' ->  'N-1:0'  (string — parametric)
    """
    inner = inner.strip()
    m = re.match(r'^(\d+)\s*:\s*(\d+)$', inner)
    if m:
        return int(m.group(1)) - int(m.group(2)) + 1
    return inner  # parametric / expression

# ─────────────────────────────────────────────────────────────────────────────
#  Module-level extraction
# ─────────────────────────────────────────────────────────────────────────────

def get_module_name(content: str) -> str:
    m = re.search(r'\bmodule\s+(\w+)', content)
    return m.group(1) if m else "unknown"


def is_sequential(content: str) -> bool:
    """True if module contains always_ff blocks."""
    return bool(re.search(r'\balways_ff\b', content))


def detect_reset_polarity(content: str) -> str:
    """Heuristic: active-low if rst_ni or negedge rst appear."""
    if re.search(r'\bnegedge\s+rst\w*\b', content):
        return "active_low"
    if re.search(r'\brst_ni\b', content):
        return "active_low"
    return "active_high"


def extract_port_list(content: str):
    """
    Find the ANSI port list of the first module in content.
    Returns (port_list_text, header_end_pos).

    Handles all forms:
      module foo (ports);
      module foo #(params) (ports);
      module foo import pkg::*; #(params) (ports);
    """
    mod_m = re.search(r'\bmodule\b', content)
    if not mod_m:
        return "", 0
    text = content[mod_m.start():]

    # Skip optional #(...) parameter block
    search_from = 0
    hash_m = re.search(r'#\s*\(', text)
    if hash_m:
        hp          = text.index('(', hash_m.start())
        hp_end      = find_close_paren(text, hp)
        search_from = hp_end + 1

    # Port list: next (...) after search_from
    try:
        port_open  = text.index('(', search_from)
    except ValueError:
        return "", 0
    port_close = find_close_paren(text, port_open)
    port_text  = text[port_open + 1 : port_close]

    # Module header ends at the ';' after the port list
    try:
        semi       = text.index(';', port_close)
        header_end = mod_m.start() + semi + 1
    except ValueError:
        header_end = mod_m.start() + port_close + 1

    return port_text, header_end

# ─────────────────────────────────────────────────────────────────────────────
#  Port parser
# ─────────────────────────────────────────────────────────────────────────────

def _parse_one_port(entry: str):
    """
    Parse a single ANSI port declaration string.
    Returns (direction, name, width) or None if not a port.

    Handles:
      input  logic             clk_i
      input  logic [31:0]      data_i
      output logic [N-1:0]     result_o
      input  ibex_pkg::type_e  signal_i
      input  ibex_pkg::type_e  signal_i [PMPNumChan]
      input  logic [31:0]      signal_i [PMPNumRegions]
      input  logic signed [7:0] val_i
    """
    entry = entry.strip()
    if not entry:
        return None

    # Must start with a direction keyword
    dir_m = re.match(r'^(input|output|inout)\b\s*', entry)
    if not dir_m:
        return None
    direction = dir_m.group(1)
    if direction == 'inout':
        return None
    rest = entry[dir_m.end():]

    # Strip leading wire/var/automatic
    rest = re.sub(r'^(wire|var|automatic)\s+', '', rest).strip()

    # Strip trailing UNPACKED array suffix: name [expr]
    # Must follow an identifier char (not a bracket)
    unpacked_sfx = ''
    arr_m = re.search(r'(\[[^\[]*\])\s*$', rest)
    if arr_m and re.search(r'\w$', rest[:arr_m.start()].rstrip()):
        unpacked_sfx = arr_m.group(1).strip()
        rest = rest[:arr_m.start()].strip()

    # Signal name = last identifier token
    name_m = re.search(r'(\w+)\s*$', rest)
    if not name_m:
        return None
    name      = name_m.group(1)
    type_part = rest[:name_m.start()].strip()

    # Derive width from the type part
    # Priority: explicit [msb:lsb] bracket  >  package type  >  plain logic = 1
    width_bracket = re.search(r'\[([^\]]+)\]', type_part)
    if width_bracket:
        width = bracket_to_width(width_bracket.group(1))
    else:
        # Remove 'logic', 'signed', 'unsigned' to expose bare package type
        bare = re.sub(r'\b(logic|wire|reg|signed|unsigned)\b', '', type_part).strip()
        if bare:
            # e.g. "ibex_pkg::priv_lvl_e"  or  "priv_lvl_e"
            width = bare + (unpacked_sfx if unpacked_sfx else '')
        elif unpacked_sfx:
            # e.g. "logic clk_i [PMPNumChan]"  -> 1-bit array
            width = '1' + unpacked_sfx
        else:
            width = 1

    return direction, name, width


def parse_ports(port_list_text: str):
    """
    Parse all port declarations from an ANSI port list.
    Returns (inputs, outputs) as lists of {name, width} dicts.
    """
    inputs, outputs = [], []
    for entry in split_top_commas(port_list_text):
        result = _parse_one_port(entry)
        if result is None:
            continue
        direction, name, width = result
        port = {"name": name, "width": width}
        (inputs if direction == 'input' else outputs).append(port)
    return inputs, outputs

# ─────────────────────────────────────────────────────────────────────────────
#  Internal signals
# ─────────────────────────────────────────────────────────────────────────────

def extract_internals(body: str, port_names: set) -> list:
    """
    Extract internal signal declarations from module body.

    Captures all of:
      logic [W1][W2]  name ;     (plain logic, multi-dim packed)
      wire  [W]       name ;
      reg   [W]       name ;
      some_type_e     name ;     (typedef'd enum/struct variable — no width keyword)

    Skips port names, SV keywords, and names starting with uppercase
    (those are typically package constants, not signals).
    """
    internals, seen = [], set(port_names)

    # ── logic / wire / reg  (with any number of packed dimensions) ──────────
    for m in re.finditer(
        r'\b(logic|wire|reg)\b\s*((?:\[[^\]]+\]\s*)*)(\w+)\s*(?:\[[^\]]*\])?\s*;',
        body
    ):
        brackets, name = m.group(2), m.group(3)
        if name in seen or name in _SV_KEYWORDS:
            continue
        seen.add(name)
        first_b = re.match(r'\[([^\]]+)\]', brackets.strip()) if brackets else None
        width   = bracket_to_width(first_b.group(1)) if first_b else 1
        internals.append({"name": name, "width": width})

    # ── typedef'd enum/struct variable: TypeName_e  var_name ; ─────────────
    # Pattern: word ending in _e, _t, _s (common SV typedef suffixes)
    # followed by an identifier and semicolon, not at the start of typedef
    for m in re.finditer(
        r'(?<!typedef\s)(?<!\bmodule\s)'
        r'\b(\w+(?:_e|_t|_s))\b\s*(\w+)\s*(?:\[[^\]]*\])?\s*;',
        body
    ):
        type_name, name = m.group(1), m.group(2)
        if name in seen or name in _SV_KEYWORDS:
            continue
        # Exclude lines that look like typedef/parameter declarations
        line_start = body.rfind('\n', 0, m.start())
        line       = body[line_start:m.start()].strip()
        if re.search(r'\b(typedef|parameter|localparam|input|output)\b', line):
            continue
        seen.add(name)
        internals.append({"name": name, "width": type_name})

    return internals

# ─────────────────────────────────────────────────────────────────────────────
#  Parameter extraction
# ─────────────────────────────────────────────────────────────────────────────

def extract_parameters(content: str) -> list:
    """
    Extract parameter names from module header and body.
    Handles:
      parameter bit  WritebackStage = 1'b0
      parameter int unsigned PMPNumRegions = 4
      parameter ibex_pkg::pmp_cfg_t PMPRstCfg[...] = ...
    """
    params, seen = [], set()
    for m in re.finditer(
        r'\bparameter\b[^=;]*?(\b\w+\b)\s*(?:\[[^\]]*\])?\s*=',
        content
    ):
        name = m.group(1)
        if (name not in _PARAM_TYPE_WORDS
                and not name.startswith('ibex_')
                and name not in seen):
            seen.add(name); params.append(name)
    return params

# ─────────────────────────────────────────────────────────────────────────────
#  Connectivity  (assign + always_comb simple assignments)
# ─────────────────────────────────────────────────────────────────────────────

def extract_connectivity(body: str, all_signal_names: set) -> list:
    """
    Extract signal-level dependencies.
    Captures two sources:
      1. Continuous assignments:  assign lhs = rhs;
      2. Simple always_comb assignments: lhs = rhs;  (top-level inside comb block)

    Each entry: {lhs, rhs, rhs_signals, source}
    """
    connectivity = []

    def rhs_sigs(rhs_text):
        return list(dict.fromkeys(
            w for w in re.findall(r'\b([a-z_]\w*)\b', rhs_text)
            if w in all_signal_names
        ))

    # ── 1. Continuous assign statements ─────────────────────────────────────
    for m in re.finditer(r'\bassign\s+([\w.]+)\s*=\s*([^;]+);', body):
        lhs = m.group(1).split('.')[0]   # strip struct field access
        rhs = m.group(2).strip()
        sigs = [s for s in rhs_sigs(rhs) if s != lhs]
        connectivity.append({
            "lhs": lhs, "rhs": rhs,
            "rhs_signals": sigs, "source": "assign"
        })

    # ── 2. Simple assignments inside always_comb blocks ─────────────────────
    # Find always_comb ... begin ... end blocks, extract top-level assignments
    for comb_m in re.finditer(r'\balways_comb\b', body):
        block_start = comb_m.end()
        # Find the begin keyword (or immediate assignment without begin)
        tail = body[block_start:]
        begin_m = re.match(r'\s*begin\b', tail)
        if begin_m:
            # Find matching end
            begin_idx  = block_start + begin_m.start()
            begin_pos  = block_start + begin_m.end()
            depth      = 1
            pos        = begin_pos
            while pos < len(body) and depth > 0:
                if re.match(r'\bbegin\b', body[pos:]):
                    depth += 1; pos += 5
                elif re.match(r'\bend\b', body[pos:]):
                    depth -= 1
                    if depth == 0:
                        block_end = pos; break
                    pos += 3
                else:
                    pos += 1
            block_body = body[begin_pos : pos]
        else:
            # Single statement always_comb (no begin/end)
            end_m = re.search(r';', tail)
            block_body = tail[:end_m.end()] if end_m else tail[:50]

        # Extract LHS = RHS ; at any level (captures nested too, which is fine)
        for am in re.finditer(r'\b(\w+)\s*(?:\[[^\]]*\])?\s*=\s*([^;]+);', block_body):
            lhs  = am.group(1)
            rhs  = am.group(2).strip()
            if lhs in _SV_KEYWORDS or '(' in lhs:
                continue
            sigs = [s for s in rhs_sigs(rhs) if s != lhs]
            if sigs and lhs in all_signal_names:
                connectivity.append({
                    "lhs": lhs, "rhs": rhs,
                    "rhs_signals": sigs, "source": "always_comb"
                })

    # Deduplicate (same lhs/rhs can appear from both assign and always_comb)
    seen_pairs, unique = set(), []
    for c in connectivity:
        key = (c['lhs'], c['rhs'][:60])
        if key not in seen_pairs:
            seen_pairs.add(key); unique.append(c)

    return unique

# ─────────────────────────────────────────────────────────────────────────────
#  ibex_pkg.sv  enum + struct parser
# ─────────────────────────────────────────────────────────────────────────────

def parse_pkg_file(pkg_path: Path) -> dict:
    """
    Parse typedef enum and typedef struct packed from a package SV file.
    Returns {type_name: {kind, base_type/fields, values}}.
    Works on any SV package file, not just ibex_pkg.sv.
    """
    if not pkg_path.exists():
        return {}
    raw     = pkg_path.read_text(encoding='utf-8', errors='replace')
    content = strip_comments(raw)
    types   = {}

    # typedef enum BASE_TYPE { NAME = VAL, ... } type_name;
    for m in re.finditer(
        r'typedef\s+enum\s+([\w\s:\[\]]+?)\s*\{([^}]+)\}\s*(\w+)\s*;',
        content, re.DOTALL
    ):
        base_type = re.sub(r'\s+', ' ', m.group(1).strip())
        body      = m.group(2)
        type_name = m.group(3)

        values = {}
        for vm in re.finditer(r'(\w+)\s*(?:=\s*([^,\n}]+))?', body):
            n = vm.group(1)
            v = vm.group(2).strip() if vm.group(2) else None
            if n and n not in _SV_KEYWORDS:
                values[n] = v
        types[type_name] = {
            "kind": "enum", "base_type": base_type, "values": values
        }

    # typedef struct packed { fields } type_name;
    for m in re.finditer(
        r'typedef\s+struct\s+packed\s*\{([^}]+)\}\s*(\w+)\s*;',
        content, re.DOTALL
    ):
        body      = m.group(1)
        type_name = m.group(2)
        fields    = []
        for fm in re.finditer(
            r'\b((?:logic|bit)\s*(?:\[[^\]]+\])?|[\w]+(?:::\w+)?)\s+(\w+)\s*;',
            body
        ):
            ftype = re.sub(r'\s+', ' ', fm.group(1).strip())
            fname = fm.group(2)
            if fname not in _SV_KEYWORDS:
                fields.append({"name": fname, "type": ftype})
        types[type_name] = {"kind": "struct", "fields": fields}

    return types


def filter_pkg_types(pkg_types: dict, signals_json: dict) -> dict:
    """
    Return only pkg types actually referenced in this module's port/internal widths.
    """
    all_text = ' '.join(
        str(p['width'])
        for p in (signals_json['ports']['inputs']
                  + signals_json['ports']['outputs']
                  + signals_json['internals'])
    )
    return {
        name: defn
        for name, defn in pkg_types.items()
        if name in all_text
    }

# ─────────────────────────────────────────────────────────────────────────────
#  Single-file parser  (general purpose)
# ─────────────────────────────────────────────────────────────────────────────

def parse_sv_file(filepath: Path) -> dict:
    """
    Parse one .sv file and return an intermediate dict with all extracted data.
    """
    raw     = filepath.read_text(encoding='utf-8', errors='replace')
    content = strip_comments(strip_sv_directives(raw))

    module_name = get_module_name(content)
    seq         = is_sequential(content)
    parameters  = extract_parameters(content)

    port_text, header_end = extract_port_list(content)
    inputs, outputs       = parse_ports(port_text)

    body       = content[header_end:]
    port_names = {p['name'] for p in inputs + outputs}
    internals  = extract_internals(body, port_names)

    all_names    = port_names | {s['name'] for s in internals}
    connectivity = extract_connectivity(body, all_names)

    return {
        "module_name":   module_name,
        "is_sequential": seq,
        "ports":         {"inputs": inputs, "outputs": outputs},
        "internals":     internals,
        "parameters":    parameters,
        "connectivity":  connectivity,
    }

# ─────────────────────────────────────────────────────────────────────────────
#  Merge  (for IE which has two source files)
# ─────────────────────────────────────────────────────────────────────────────

def merge_and_build(module_key: str, parsed_list: list, pkg_types: dict) -> dict:
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
        "module":      mod_names[0] if len(mod_names) == 1 else mod_names,
        "module_key":  module_key,
        "type":        mod_type,
        "ports":       {"inputs": all_inputs, "outputs": all_outputs},
        "internals":   all_internals,
        "parameters":  all_params,
    }
    if mod_type == "sequential":
        # Find clock and reset from inputs (look for conventional names)
        input_names = {p['name'] for p in all_inputs}
        result["clock"]  = next(
            (n for n in ["clk_i", "clk", "clock"] if n in input_names), "clk_i"
        )
        rst_name = next(
            (n for n in ["rst_ni", "rst_n", "rstn", "rst_i", "rst", "reset_n",
                         "reset", "reset_i"] if n in input_names), "rst_ni"
        )
        result["reset"]          = rst_name
        result["reset_polarity"] = "active_low" if rst_name.endswith(
            ('_ni', '_n', 'n')) else "active_high"

    result["pkg_types"]    = filter_pkg_types(pkg_types, result)
    result["connectivity"] = all_connectivity
    return result

# ─────────────────────────────────────────────────────────────────────────────
#  Validation
# ─────────────────────────────────────────────────────────────────────────────

def validate(out: dict, module_key: str) -> list:
    """Return list of warning strings for the generated signals.json."""
    warnings = []
    ni = len(out['ports']['inputs'])
    no = len(out['ports']['outputs'])

    if ni == 0:
        warnings.append("No input ports found — port list parsing may have failed")
    if no == 0:
        warnings.append("No output ports found")
    if out['type'] == 'sequential':
        clk = out.get('clock', '')
        rst = out.get('reset', '')
        input_names = {p['name'] for p in out['ports']['inputs']}
        if clk not in input_names:
            warnings.append(f"Clock '{clk}' not found in input ports")
        if rst not in input_names:
            warnings.append(f"Reset '{rst}' not found in input ports")
    if len(out['internals']) == 0:
        warnings.append("No internal signals found (module may be very simple or parse failed)")
    return warnings

# ─────────────────────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Step 1A: SV RTL Parser → signals.json",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Ibex pipeline — all 9 modules
  python scripts/parse_rtl.py --all-modules

  # Single Ibex module
  python scripts/parse_rtl.py --module csr

  # Any SV file (general use)
  python scripts/parse_rtl.py --sv-file path/to/mymodule.sv

  # Any SV file with a package file
  python scripts/parse_rtl.py --sv-file path/to/mymodule.sv --pkg-file path/to/mypkg.sv
"""
    )
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--module",      choices=list(MODULE_RTL_MAP),
                     help="Ibex module key")
    grp.add_argument("--all-modules", action="store_true",
                     help="Parse all 9 Ibex modules")
    grp.add_argument("--sv-file",     type=Path, metavar="PATH",
                     help="Parse any SV file directly")
    ap.add_argument("--pkg-file",     type=Path, metavar="PATH",
                    help="Package SV file for type definitions (optional with --sv-file)")
    ap.add_argument("--out-dir",      type=Path, default=OUTPUT_DIR,
                    help=f"Output directory (default: {OUTPUT_DIR})")
    args = ap.parse_args()

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    # ── Load package types ───────────────────────────────────────────────────
    pkg_file = args.pkg_file or (PKG_FILE if PKG_FILE.exists() else None)
    if pkg_file:
        print(f"  Loading package types from {pkg_file} ...")
        pkg_types = parse_pkg_file(pkg_file)
        print(f"  Found {len(pkg_types)} typedef(s) in package file")
    else:
        pkg_types = {}

    # ── Determine which modules to process ───────────────────────────────────
    if args.sv_file:
        # General mode: single arbitrary SV file
        if not args.sv_file.exists():
            print(f"ERROR: {args.sv_file} not found", file=sys.stderr); sys.exit(1)
        modules_to_run = [("_sv_file", [args.sv_file])]
    elif args.all_modules:
        modules_to_run = [(mod, [RTL_DIR / f for f in files])
                          for mod, files in MODULE_RTL_MAP.items()]
    else:
        modules_to_run = [(args.module,
                           [RTL_DIR / f for f in MODULE_RTL_MAP[args.module]])]

    # ── Parse each module ────────────────────────────────────────────────────
    for mod_key, file_paths in modules_to_run:
        parsed = []
        for fpath in file_paths:
            if not fpath.exists():
                print(f"ERROR: {fpath} not found", file=sys.stderr); sys.exit(1)
            print(f"  Parsing {fpath} ...")
            parsed.append(parse_sv_file(fpath))

        out = merge_and_build(mod_key, parsed, pkg_types)

        # Use module name for --sv-file mode
        if mod_key == "_sv_file":
            mod_key = out['module'] if isinstance(out['module'], str) else out['module'][0]

        out_path = out_dir / f"{mod_key}_signals.json"
        out_path.write_text(json.dumps(out, indent=2))

        ni = len(out['ports']['inputs'])
        no = len(out['ports']['outputs'])
        nn = len(out['internals'])
        nc = len(out['connectivity'])
        nt = len(out['pkg_types'])
        print(f"  [{mod_key}] {out['module']} | {out['type']} | "
              f"in={ni} out={no} int={nn} assign={nc} pkg_types={nt}"
              f"  ->  {out_path}")

        # Validation warnings
        for w in validate(out, mod_key):
            print(f"  WARNING [{mod_key}]: {w}")

if __name__ == "__main__":
    main()
