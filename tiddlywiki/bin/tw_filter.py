#!/usr/bin/env python3
"""
TiddlyWiki Filter Expression Evaluator

This module provides functionality to parse and evaluate TiddlyWiki filter expressions
with support for various operator types: math, string, string manipulation, list, and wiki operators.

Based on TiddlyWiki's filter syntax: https://tiddlywiki.com/static/Filters.html
"""

import sys
import os
import math
import statistics
import base64
import urllib.parse
import json
import hashlib
import re

# Import wiki loading functionality from tw script
script_dir = os.path.dirname(os.path.abspath(__file__))
tw_path = os.path.join(script_dir, "tw")

# Import tw module
import importlib.util
import importlib.machinery
loader = importlib.machinery.SourceFileLoader("tw", tw_path)
tw_module = loader.load_module()


def safe_str(value):
    """Convert a value to string, treating None as empty string."""
    return '' if value is None else str(value)


def to_number(value, default=0.0):
    """Convert a value to float, returning default if conversion fails."""
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def split_param_values(param, delimiters=(',', '|', ';')):
    """Split a parameter string using common delimiters."""
    if param is None:
        return []
    text = str(param)
    for delim in delimiters:
        if delim in text:
            return [part.strip() for part in text.split(delim) if part.strip() != '']
    # Fallback to whitespace split
    return [part for part in text.split() if part]


def split_param_values_preserve_empty(param, delimiters=(',', '|', ';'), maxsplit=None):
    """Split a parameter string while preserving empty fields."""
    if param is None:
        return []
    text = str(param)
    for delim in delimiters:
        if delim in text:
            if maxsplit is None:
                parts = text.split(delim)
            else:
                parts = text.split(delim, maxsplit)
            return [part.strip() for part in parts]
    return [text.strip()]


def slugify_text(text):
    """Best-effort slugify to mimic TiddlyWiki's human-friendly slugs."""
    s = safe_str(text)
    # Replace non-alphanumeric characters with hyphens
    s = re.sub(r'[^A-Za-z0-9]+', '-', s)
    # Trim leading/trailing hyphens and lowercase
    return s.strip('-').lower()


def css_escape(text):
    """Minimal CSS escaping for selector-safe strings."""
    s = safe_str(text)
    # Escape characters that are not alphanumerics with a backslash
    return ''.join(ch if ch.isalnum() or ch == '_' else f'\\{ch}' for ch in s)


def parse_search_replace(param):
    """Parse search-replace parameters separated by comma or pipe."""
    search, repl, _flags = parse_search_replace_with_flags(param)
    return search, repl


def parse_search_replace_with_flags(param):
    """Parse search-replace parameters with optional flags."""
    if param is None:
        return '', '', ''
    text = str(param)
    if ',' not in text and '|' not in text:
        parts = text.split(None, 1)
        search = parts[0] if len(parts) > 0 else ''
        repl = parts[1] if len(parts) > 1 else ''
        return search, repl, ''
    parts = split_param_values_preserve_empty(text, delimiters=(',', '|'), maxsplit=2)
    search = parts[0] if len(parts) > 0 else ''
    repl = parts[1] if len(parts) > 1 else ''
    flags = parts[2] if len(parts) > 2 else ''
    return search, repl, flags


def parse_search_replace_flags(flags):
    """Parse search-replace flags into regex usage and options."""
    use_regex = False
    global_replace = True
    re_flags = 0
    flag_text = safe_str(flags).strip().lower()
    if not flag_text:
        return use_regex, global_replace, re_flags
    tokens = re.split(r'[\s,;]+', flag_text)
    for token in tokens:
        if not token:
            continue
        if token in ('re', 'regex', 'regexp'):
            use_regex = True
            continue
        if token in ('first', 'once', 'single', 'nog', 'noglobal'):
            global_replace = False
            continue
        if token in ('g', 'global'):
            global_replace = True
            continue
        for ch in token:
            if ch == 'g':
                global_replace = True
            elif ch == 'i':
                re_flags |= re.IGNORECASE
            elif ch == 'm':
                re_flags |= re.MULTILINE
            elif ch == 's':
                re_flags |= re.DOTALL
            elif ch == 'r':
                use_regex = True
            elif ch == '1':
                global_replace = False
    return use_regex, global_replace, re_flags


def parse_filter_expression(filter_expr):
    """Parse a TiddlyWiki filter expression into runs with optional prefixes."""
    # Split runs when we see a run prefix at depth 0; whitespace within a run is preserved
    runs_raw = []
    buf = ''
    depth = 0

    for idx, ch in enumerate(filter_expr):
        if ch == '[':
            depth += 1
        elif ch == ']':
            depth = max(0, depth - 1)

        is_prefix_char = ch in '+-~=' and (idx + 1 < len(filter_expr) and filter_expr[idx + 1] == '[')
        # Check for named prefix :and, :or, etc. only when starting a new run
        named_prefix_split = (ch == ':' and
                            (not buf or buf[-1].isspace()) and
                            idx + 1 < len(filter_expr) and
                            (filter_expr[idx + 1].isalnum() or filter_expr[idx + 1] in '_-'))

        if depth == 0 and (is_prefix_char or named_prefix_split):
            if buf.strip():
                runs_raw.append(buf.strip())
                buf = ch
                continue

        # Preserve whitespace within runs but collapse at depth 0
        if depth == 0 and ch.isspace():
            buf += ' '
            continue

        buf += ch

    if buf.strip():
        runs_raw.append(buf.strip())

    parsed_runs = []
    for raw in runs_raw:
        prefix = None
        run_text = raw

        # Named prefix :and, :or, etc.
        if run_text.startswith(':'):
            pos = 1
            while pos < len(run_text) and (run_text[pos].isalnum() or run_text[pos] in '_-'):
                pos += 1
            prefix = run_text[1:pos]
            run_text = run_text[pos:].strip()
        elif run_text and run_text[0] in '+-~=':
            prefix = run_text[0]
            run_text = run_text[1:].strip()

        # Strip single wrapping [ ] (but not [[literal]])
        if run_text.startswith('[') and run_text.endswith(']') and not run_text.startswith('[['):
            run_text = run_text[1:-1]

        literals = []
        operators = []
        pos = 0

        while pos < len(run_text):
            # Skip whitespace
            while pos < len(run_text) and run_text[pos].isspace():
                pos += 1
            if pos >= len(run_text):
                break

            if run_text[pos:pos+2] == '[[':
                end = run_text.find(']]', pos + 2)
                if end == -1:
                    raise ValueError(f"Unclosed literal at position {pos}")
                literal_value = run_text[pos+2:end]
                literals.append(literal_value)
                pos = end + 2
            else:
                name_start = pos
                # Allow leading ! for negation
                if run_text[pos] == '!':
                    pos += 1
                while pos < len(run_text) and (run_text[pos].isalnum() or run_text[pos] in '_:!-'):
                    pos += 1
                operator_name = run_text[name_start:pos]
                if not operator_name:
                    raise ValueError(f"Unexpected character '{run_text[pos]}' at position {pos}")

                if pos < len(run_text) and run_text[pos] in '[{<':
                    param_exprs = []

                    def parse_param_expression(start_pos):
                        opening = run_text[start_pos]
                        if opening == '[':
                            param_start = start_pos + 1
                            bracket_depth = 1
                            param_end = param_start
                            while param_end < len(run_text) and bracket_depth > 0:
                                if run_text[param_end] == '[':
                                    bracket_depth += 1
                                elif run_text[param_end] == ']':
                                    bracket_depth -= 1
                                if bracket_depth > 0:
                                    param_end += 1
                            if bracket_depth != 0:
                                raise ValueError(f"Unclosed operator parameter at position {start_pos}")
                            param_value = run_text[param_start:param_end]
                            return ('hard', param_value), param_end + 1
                        if opening == '{':
                            end = run_text.find('}', start_pos + 1)
                            if end == -1:
                                raise ValueError(f"Unclosed operator parameter at position {start_pos}")
                            return ('soft', run_text[start_pos + 1:end]), end + 1
                        if opening == '<':
                            end = run_text.find('>', start_pos + 1)
                            if end == -1:
                                raise ValueError(f"Unclosed operator parameter at position {start_pos}")
                            return ('variable', run_text[start_pos + 1:end]), end + 1
                        raise ValueError(f"Unexpected character '{opening}' at position {start_pos}")

                    while pos < len(run_text) and run_text[pos] in '[{<':
                        expr, next_pos = parse_param_expression(pos)
                        param_exprs.append(expr)
                        pos = next_pos

                        while pos < len(run_text) and run_text[pos].isspace():
                            pos += 1
                        if pos < len(run_text) and run_text[pos] == ',':
                            pos += 1
                            while pos < len(run_text) and run_text[pos].isspace():
                                pos += 1
                            continue
                        break

                    operators.append((operator_name, param_exprs))
                else:
                    operators.append((operator_name, None))

        parsed_runs.append({
            'prefix': prefix,
            'literals': literals,
            'operators': operators
        })

    return parsed_runs


def apply_operator(operator_name, param, value):
    """Apply a single operator to a single value."""
    name = operator_name
    name_lower = name.lower()
    base_name = name
    flag_text = None
    if ':' in name:
        base_name, flag_text = name.split(':', 1)
        name_lower = base_name.lower()
    s = safe_str(value)
    case_sensitive = True
    if flag_text is not None and name_lower in ('prefix', 'suffix', 'match', 'removeprefix', 'removesuffix'):
        flags = [part.strip().lower() for part in flag_text.split(',') if part.strip()]
        if 'caseinsensitive' in flags:
            case_sensitive = False
    if isinstance(param, list) and name_lower not in ('search-replace',):
        param = param[0] if param else ''

    # Filtering / matching operators on strings
    if name_lower == 'prefix':
        text = param if param is not None else ''
        if not case_sensitive:
            return value if s.lower().startswith(text.lower()) else None
        return value if s.startswith(text) else None
    if name_lower == 'suffix':
        text = param if param is not None else ''
        if not case_sensitive:
            return value if s.lower().endswith(text.lower()) else None
        return value if s.endswith(text) else None
    if name_lower == 'match':
        pattern = param if param is not None else ''
        if not case_sensitive:
            return value if s.lower() == pattern.lower() else None
        return value if s == pattern else None
    if name_lower == 'regexp':
        pattern = param if param is not None else ''
        try:
            return value if re.search(pattern, s) else None
        except re.error:
            return None
    if name_lower == 'compare':
        if flag_text:
            parts = [part.strip() for part in flag_text.split(':')]
            compare_type = parts[0].lower() if len(parts) > 0 and parts[0] else 'number'
            compare_mode = parts[1].lower() if len(parts) > 1 and parts[1] else 'eq'

            def normalize_version(text):
                cleaned = safe_str(text).strip()
                if cleaned.lower().startswith('v'):
                    cleaned = cleaned[1:]
                pieces = cleaned.split('.')
                if not pieces:
                    return [0, 0, 0]
                nums = []
                for part in pieces:
                    match = re.match(r'(\d+)', part)
                    nums.append(int(match.group(1)) if match else 0)
                if not nums:
                    nums = [0, 0, 0]
                return nums

            def normalize_date_or_default(text):
                normalized = normalize_date(safe_str(text))
                return normalized if normalized else '19700101000000000'

            def convert_value(text):
                if compare_type == 'number':
                    return to_number(text, 0.0)
                if compare_type == 'integer':
                    try:
                        return int(float(text))
                    except (ValueError, TypeError):
                        return 0
                if compare_type == 'string':
                    return safe_str(text)
                if compare_type == 'date':
                    return normalize_date_or_default(text)
                if compare_type == 'version':
                    return normalize_version(text)
                return to_number(text, 0.0)

            left = convert_value(s)
            right = convert_value(param if param is not None else '')
            if compare_type == 'version':
                max_len = max(len(left), len(right))
                left = left + [0] * (max_len - len(left))
                right = right + [0] * (max_len - len(right))

            def compare_values(a, b):
                if compare_mode == 'eq':
                    return a == b
                if compare_mode == 'ne':
                    return a != b
                if compare_mode == 'gteq':
                    return a >= b
                if compare_mode == 'gt':
                    return a > b
                if compare_mode == 'lteq':
                    return a <= b
                if compare_mode == 'lt':
                    return a < b
                return a == b

            return value if compare_values(left, right) else None

        target = param if param is not None else ''
        # Support numeric comparisons if target starts with < or >
        if target.startswith('>='):
            cmp_val = to_number(target[2:], None)
            num_val = to_number(s, None)
            return value if cmp_val is not None and num_val is not None and num_val >= cmp_val else None
        if target.startswith('<='):
            cmp_val = to_number(target[2:], None)
            num_val = to_number(s, None)
            return value if cmp_val is not None and num_val is not None and num_val <= cmp_val else None
        if target.startswith('!='):
            return value if s != target[2:] else None
        if target.startswith('=='):
            return value if s == target[2:] else None
        if target.startswith('>'):
            cmp_val = to_number(target[1:], None)
            return value if cmp_val is not None and to_number(s, None) is not None and to_number(s) > cmp_val else None
        if target.startswith('<'):
            cmp_val = to_number(target[1:], None)
            return value if cmp_val is not None and to_number(s, None) is not None and to_number(s) < cmp_val else None
        return value if s == target else None
    if name_lower == 'contains':
        pattern = param if param is not None else ''
        return value if pattern.lower() in s.lower() else None
    if name_lower == 'minlength':
        min_len = int(param) if param not in (None, '') else 0
        return value if len(s) >= min_len else None

    # String manipulation operators
    if name_lower == 'removeprefix':
        text = param if param is not None else ''
        if not text:
            return s
        if not case_sensitive:
            return s[len(text):] if s.lower().startswith(text.lower()) else None
        return s[len(text):] if s.startswith(text) else None
    if name_lower == 'removesuffix':
        text = param if param is not None else ''
        if not text:
            return s
        if not case_sensitive:
            return s[:-len(text)] if s.lower().endswith(text.lower()) else None
        return s[:-len(text)] if s.endswith(text) else None
    if name_lower == 'addprefix':
        text = param if param is not None else ''
        return text + s
    if name_lower == 'addsuffix':
        text = param if param is not None else ''
        return s + text

    # String formatting/transform
    if name_lower == 'uppercase':
        return s.upper()
    if name_lower == 'lowercase':
        return s.lower()
    if name_lower == 'titlecase':
        return s.title()
    if name_lower == 'sentencecase':
        return s[0].upper() + s[1:].lower() if s else s
    if name_lower == 'trim':
        # If a parameter is supplied, strip that string from both ends; otherwise strip whitespace
        if param not in (None, ''):
            parts = split_param_values_preserve_empty(param, maxsplit=2)
            if len(parts) >= 2:
                direction = parts[-1].lower()
                if direction in ('left', 'right', 'both', 'start', 'end'):
                    trim_chars = parts[0]
                    if trim_chars == '':
                        if direction in ('left', 'start'):
                            return s.lstrip()
                        if direction in ('right', 'end'):
                            return s.rstrip()
                        return s.strip()
                    if direction in ('left', 'start'):
                        return s.lstrip(trim_chars)
                    if direction in ('right', 'end'):
                        return s.rstrip(trim_chars)
                    return s.strip(trim_chars)
            return s.strip(param)
        return s.strip()
    if name_lower == 'length':
        return len(s)
    if name_lower == 'slugify':
        return slugify_text(s)
    if name_lower == 'pad':
        # param can be "length", "length,char", or "length,char,direction"
        text = '' if param is None else str(param)
        if ',' not in text and '|' not in text and ';' not in text:
            parts = split_param_values(param)
        else:
            parts = split_param_values_preserve_empty(param, maxsplit=2)
        if not parts or parts[0] == '':
            return s
        target_len = int(parts[0]) if parts[0] else len(s)
        fill_char = ' '
        direction = None
        if len(parts) > 1:
            candidate = parts[1].lower()
            if len(parts) == 2 and candidate in ('left', 'right', 'center', 'centre', 'both', 'start', 'end'):
                direction = candidate
            else:
                fill_char = parts[1] if parts[1] else ' '
        if len(parts) > 2 and parts[2]:
            direction = parts[2].lower()
        if direction in ('left', 'start'):
            return s.rjust(target_len, fill_char)
        if direction in ('center', 'centre', 'both'):
            return s.center(target_len, fill_char)
        if direction in ('right', 'end'):
            return s.ljust(target_len, fill_char)
        return s.ljust(target_len, fill_char)
    if name_lower == 'split':
        if param is None or param == '':
            return s.split()
        return s.split(param)
    if name_lower == 'splitregexp':
        pattern = param if param is not None else '\\s+'
        try:
            return re.split(pattern, s)
        except re.error:
            return [s]
    if name_lower == 'splitbefore':
        delim = param if param is not None else ''
        if not delim:
            return s
        idx = s.find(delim)
        if idx == -1:
            return s
        return s[:idx]
    if name_lower == 'search-replace':
        search = ''
        repl = ''
        flags_text = ''
        regex_mode = ''
        if flag_text:
            parts = [part.strip().lower() for part in flag_text.split(':') if part.strip()]
            if len(parts) == 1:
                if parts[0] == 'regexp':
                    regex_mode = 'regexp'
                else:
                    flags_text = parts[0]
            elif len(parts) >= 2:
                flags_text = parts[0]
                regex_mode = parts[1]

        if isinstance(param, list):
            search = param[0] if len(param) > 0 else ''
            repl = param[1] if len(param) > 1 else ''
        else:
            if flag_text:
                search = param if param is not None else ''
            else:
                search, repl, flags = parse_search_replace_with_flags(param)
                if flags:
                    flags_text = flags.lower()

        if search == '':
            return s

        use_regex = regex_mode == 'regexp'
        re_flags = 0
        if 'i' in flags_text:
            re_flags |= re.IGNORECASE
        if 'm' in flags_text:
            re_flags |= re.MULTILINE

        global_replace = 'g' in flags_text
        if not flag_text and not isinstance(param, list):
            # Legacy behavior defaults to global replace unless flags override
            use_regex, global_replace, legacy_flags = parse_search_replace_flags(flags_text)
            re_flags |= legacy_flags

        if not use_regex and re_flags == 0:
            return s.replace(search, repl) if global_replace else s.replace(search, repl, 1)
        pattern = search if use_regex else re.escape(search)
        count = 0 if global_replace else 1
        try:
            return re.sub(pattern, repl, s, count=count, flags=re_flags)
        except re.error:
            return s
    if name_lower == 'format':
        if param in (None, ''):
            return s
        try:
            # Attempt numeric formatting first
            num = float(s) if s else 0.0
            return format(num, param)
        except Exception:
            try:
                return param.format(s)
            except Exception:
                return s

    # Encoding/decoding and hashing
    if name_lower == 'encodebase64':
        return base64.b64encode(s.encode('utf-8')).decode('utf-8')
    if name_lower == 'decodebase64':
        try:
            return base64.b64decode(s.encode('utf-8')).decode('utf-8')
        except Exception:
            return ''
    if name_lower == 'encodeuri':
        return urllib.parse.quote(s, safe='/:')
    if name_lower == 'encodeuricomponent':
        return urllib.parse.quote(s, safe='')
    if name_lower == 'decodeuri':
        return urllib.parse.unquote(s)
    if name_lower == 'decodeuricomponent':
        return urllib.parse.unquote_plus(s)
    if name_lower == 'encodehtml':
        import html
        return html.escape(s)
    if name_lower == 'decodehtml':
        import html
        return html.unescape(s)
    if name_lower == 'escaperegexp':
        return re.escape(s)
    if name_lower == 'escapecss':
        return css_escape(s)
    if name_lower == 'stringify':
        return json.dumps(s)
    if name_lower == 'jsonstringify':
        return json.dumps(s)
    if name_lower in ('jsonget', 'jsonextract', 'jsonindexes', 'jsontype', 'jsonset'):
        try:
            data = json.loads(s)
        except Exception:
            data = None
        if data is None:
            return ''
        if name_lower == 'jsonindexes':
            return list(data.keys()) if isinstance(data, dict) else []
        if name_lower == 'jsonset':
            key, val = parse_search_replace(param)
            if key:
                if isinstance(data, dict):
                    data[key] = val
                    return json.dumps(data)
            return s
        if isinstance(data, dict) and param in data:
            value = data[param]
            if name_lower == 'jsontype':
                return type(value).__name__
            if name_lower == 'jsonextract':
                return json.dumps(value)
            return str(value)
        return ''
    if name_lower == 'sha256':
        return hashlib.sha256(s.encode('utf-8')).hexdigest()
    if name_lower == 'charcode':
        # value is numeric code; if missing use param
        if s == '' and param:
            s = safe_str(param)
        try:
            return chr(int(float(s)))
        except Exception:
            return ''
    if name_lower == 'levenshtein':
        target = safe_str(param)
        a, b = s, target
        if a == b:
            return 0
        if len(a) == 0:
            return len(b)
        if len(b) == 0:
            return len(a)
        prev_row = list(range(len(b) + 1))
        for i, ca in enumerate(a, 1):
            curr = [i]
            for j, cb in enumerate(b, 1):
                ins = prev_row[j] + 1
                del_cost = curr[j-1] + 1
                sub = prev_row[j-1] + (ca != cb)
                curr.append(min(ins, del_cost, sub))
            prev_row = curr
        return prev_row[-1]

    # Math operators (per item)
    num_value = to_number(value)
    if name_lower == 'add':
        return num_value + to_number(param)
    if name_lower == 'subtract':
        return num_value - to_number(param)
    if name_lower == 'multiply':
        return num_value * to_number(param, 1.0)
    if name_lower == 'divide':
        denom = to_number(param, 1.0)
        if denom == 0:
            raise ValueError("Division by zero")
        return num_value / denom
    if name_lower == 'remainder':
        denom = to_number(param, 1.0)
        if denom == 0:
            raise ValueError("Modulo by zero")
        return num_value % denom
    if name_lower == 'negate':
        return -num_value
    if name_lower == 'abs':
        return abs(num_value)
    if name_lower == 'power':
        return math.pow(num_value, to_number(param, 1.0))
    if name_lower == 'log':
        base = to_number(param, math.e)
        try:
            return math.log(num_value, base)
        except ValueError:
            return 0
    if name_lower == 'sin':
        return math.sin(num_value)
    if name_lower == 'cos':
        return math.cos(num_value)
    if name_lower == 'tan':
        return math.tan(num_value)
    if name_lower == 'asin':
        try:
            return math.asin(num_value)
        except ValueError:
            return 0
    if name_lower == 'acos':
        try:
            return math.acos(num_value)
        except ValueError:
            return 0
    if name_lower == 'atan':
        return math.atan(num_value)
    if name_lower == 'atan2':
        x_val = to_number(param, 0.0)
        return math.atan2(num_value, x_val)
    if name_lower == 'round':
        return round(num_value)
    if name_lower == 'ceil':
        return math.ceil(num_value)
    if name_lower == 'floor':
        return math.floor(num_value)
    if name_lower == 'trunc':
        return math.trunc(num_value)
    if name_lower == 'untrunc':
        # Round away from zero
        return math.ceil(num_value) if num_value > 0 else math.floor(num_value)
    if name_lower == 'sign':
        return -1 if num_value < 0 else (1 if num_value > 0 else 0)
    if name_lower == 'precision':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}g') if digits > 0 else str(num_value)
    if name_lower == 'fixed':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}f')
    if name_lower == 'exponential':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}e')
    if name_lower == 'max':
        return max(num_value, to_number(param))
    if name_lower == 'min':
        return min(num_value, to_number(param))

    raise ValueError(f"Unknown operator: {operator_name}")


def apply_list_operator(operator_name, param, values, negated=False):
    """Apply a list-level operator to the entire list of values."""
    name = operator_name
    name_lower = name.lower()
    base_name, suffix = (name_lower.split(':', 1) + [None])[:2]

    def param_as_list(param_value):
        if isinstance(param_value, list):
            return [safe_str(p) for p in param_value if p is not None]
        return split_param_values(param_value)

    def parse_suffix_int(default, max_value=None):
        if suffix in (None, ''):
            return default
        try:
            num = int(suffix)
        except ValueError:
            return default
        if max_value is not None:
            num = max(0, min(max_value, num))
        return num

    # Selection and slicing
    if base_name == 'first':
        n = int(param) if param not in (None, '') else 1
        return values[:n]
    if base_name == 'last':
        n = int(param) if param not in (None, '') else 1
        return values[-n:] if n != 0 else []
    if base_name in ('rest', 'butfirst', 'bf'):
        n = int(param) if param not in (None, '') else 1
        return values[n:] if len(values) > n else []
    if base_name == 'butlast':
        n = int(param) if param not in (None, '') else 1
        return values[:-n] if n <= len(values) else []
    if base_name == 'limit':
        n = int(param) if param not in (None, '') else 1
        return values[:n] if n >= 0 else values[n:]
    if base_name == 'nth':
        n = int(param) if param not in (None, '') else 1
        return [values[n - 1]] if 1 <= n <= len(values) else []
    if base_name == 'zth':
        n = int(param) if param not in (None, '') else 0
        return [values[n]] if 0 <= n < len(values) else []
    if base_name == 'after':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[idx + 1:idx + 2]
        return []
    if base_name == 'before':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[idx - 1:idx] if idx > 0 else []
        return []
    if base_name == 'allafter':
        marker = param if param is not None else ''
        include_marker = suffix == 'include'
        if marker in values:
            idx = values.index(marker)
            return values[idx:] if include_marker else values[idx + 1:]
        return []
    if base_name == 'allbefore':
        marker = param if param is not None else ''
        include_marker = suffix == 'include'
        if marker in values:
            idx = values.index(marker)
            return values[:idx + 1] if include_marker else values[:idx]
        return []
    if base_name == 'next':
        if param:
            return apply_list_operator('after', param, values)
        return values[1:] if values else []
    if base_name == 'previous':
        if param:
            return apply_list_operator('before', param, values)
        return values[:-1] if values else []

    # Ordering and uniqueness
    if base_name == 'reverse':
        return list(reversed(values))
    if base_name == 'order':
        if not param:
            return values
        param_text = str(param)
        if param_text.lower().startswith('rev'):
            return list(reversed(values))
        order_list = param_as_list(param)
        if not order_list:
            return values
        order_map = {val: idx for idx, val in enumerate(order_list)}
        ordered = [(order_map[v], idx, v) for idx, v in enumerate(values) if v in order_map]
        ordered.sort(key=lambda item: (item[0], item[1]))
        ordered_values = [v for _, _, v in ordered]
        rest = [v for v in values if v not in order_map]
        return ordered_values + rest
    if base_name == 'unique':
        seen = set()
        unique_values = []
        for item in values:
            if item not in seen:
                seen.add(item)
                unique_values.append(item)
        return unique_values
    if base_name == 'join':
        sep = param if param is not None else ''
        return [sep.join(values)]

    # Sorting for raw values (field-aware sorts handled in wiki operators)
    if base_name in ('sort', 'sortcs'):
        case_sensitive = base_name == 'sortcs'
        if case_sensitive:
            return sorted(values)
        return sorted(values, key=lambda v: safe_str(v).lower())
    if base_name in ('nsort', 'nsortcs', 'sortan'):
        case_sensitive = base_name == 'nsortcs'
        def natural_key(val):
            parts = re.split(r'(\\d+)', safe_str(val))
            processed = []
            for part in parts:
                if part.isdigit():
                    processed.append(int(part))
                else:
                    processed.append(part if case_sensitive else part.lower())
            return processed
        return sorted(values, key=natural_key)

    # Aggregations over the entire list
    if base_name == 'count':
        return [str(len(values))]
    if base_name == 'sum':
        nums = [to_number(v, 0.0) for v in values]
        return [str(sum(nums))]
    if base_name == 'product':
        nums = [to_number(v, 0.0) for v in values]
        result = 1
        for n in nums:
            result *= n
        return [str(result)]
    if base_name == 'average':
        nums = [to_number(v, 0.0) for v in values]
        return [str(sum(nums) / len(nums))] if nums else ['0']
    if base_name == 'median':
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.median(nums))] if nums else ['0']
    if base_name == 'minall':
        nums = [to_number(v, 0.0) for v in values]
        return [str(min(nums))] if nums else []
    if base_name == 'maxall':
        nums = [to_number(v, 0.0) for v in values]
        return [str(max(nums))] if nums else []
    if base_name == 'variance':
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.pvariance(nums))] if len(nums) > 1 else ['0']
    if base_name in ('standard-deviation', 'standard_deviation'):
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.pstdev(nums))] if len(nums) > 1 else ['0']

    # List construction helpers
    if base_name == 'range':
        parts = param_as_list(param)
        if not parts:
            return []
        # Determine begin, end, step according to docs
        if len(parts) == 1:
            end = float(parts[0])
            begin = 1 if end >= 1 else -1
            step = 1
        elif len(parts) == 2:
            begin, end = float(parts[0]), float(parts[1])
            step = 1
        else:
            begin, end, step = float(parts[0]), float(parts[1]), float(parts[2])
            if step == 0:
                step = 1
        step = abs(step) if step != 0 else 1
        direction = 1 if end >= begin else -1
        step = step * direction
        results = []
        limit = 10000
        count = 0
        current = begin
        if step > 0:
            while current <= end + 1e-9 and count < limit:
                results.append(current)
                current += step
                count += 1
        else:
            while current >= end - 1e-9 and count < limit:
                results.append(current)
                current += step
                count += 1
        # Format numbers preserving decimal places from parameters
        max_decimals = max([len(p.split('.')[-1]) if '.' in p else 0 for p in parts])
        formatted = []
        for num in results:
            if max_decimals > 0:
                formatted.append(f"{num:.{max_decimals}f}")
            else:
                # Avoid .0 for integers
                formatted.append(str(int(num)) if num == int(num) else str(num))
        return list(reversed(formatted)) if negated else formatted

    # Mutation/combination of list contents
    if base_name == 'append':
        extras = param_as_list(param)
        count = parse_suffix_int(len(extras), max_value=len(extras))
        if count == 0:
            return values
        chosen = extras[-count:] if negated else extras[:count]
        return values + chosen
    if base_name == 'prepend':
        extras = param_as_list(param)
        count = parse_suffix_int(len(extras), max_value=len(extras))
        if count == 0:
            return values
        chosen = extras[-count:] if negated else extras[:count]
        return chosen + values
    if base_name == 'remove':
        extras = param_as_list(param)
        count = parse_suffix_int(len(extras), max_value=len(extras))
        if count == 0:
            return values
        chosen = extras[-count:] if negated else extras[:count]
        targets = set(chosen)
        if not targets:
            return values
        return [v for v in values if v not in targets]
    if base_name == 'replace':
        marker = param if not isinstance(param, list) else (param[0] if param else '')
        if not marker:
            return values
        count = parse_suffix_int(1, max_value=len(values))
        if count <= 0:
            return values
        if len(values) <= count:
            return values
        trailing = values[-count:]
        base = values[:-count]
        if marker in base:
            idx = base.index(marker)
            return base[:idx] + trailing + base[idx + 1:]
        return values
    if base_name == 'toggle':
        if isinstance(param, list):
            toggle_values = [safe_str(p) for p in param if p is not None]
        else:
            toggle_values = split_param_values(param)
        if not toggle_values:
            return values
        if len(toggle_values) == 1:
            target = toggle_values[0]
            if target in values:
                return [v for v in values if v != target]
            return values + [target]
        toggled = []
        for v in values:
            if v in toggle_values:
                idx = toggle_values.index(v)
                toggled.append(toggle_values[(idx + 1) % len(toggle_values)])
            else:
                toggled.append(v)
        if not toggled:
            toggled.append(toggle_values[0])
        return toggled
    if base_name == 'cycle':
        if isinstance(param, list):
            cycle_values = [safe_str(p) for p in param if p is not None]
        else:
            cycle_values = split_param_values(param)
        step_size = 1
        if len(cycle_values) > 1:
            last = cycle_values[-1]
            try:
                step_size = int(last)
                cycle_values = cycle_values[:-1]
            except ValueError:
                step_size = 1
        if not cycle_values:
            return values
        cycled = []
        for v in values:
            if v in cycle_values:
                idx = cycle_values.index(v)
                cycled.append(cycle_values[(idx + step_size) % len(cycle_values)])
            else:
                cycled.append(v)
        if not cycled:
            cycled.append(cycle_values[0])
        return cycled
    if base_name in ('insertafter', 'insertbefore'):
        parts = param_as_list(param)
        if len(parts) >= 2:
            marker, new_item = parts[0], parts[1]
            result = values[:]
            if marker in result:
                idx = result.index(marker)
                insert_at = idx + 1 if base_name == 'insertafter' else idx
                result.insert(insert_at, new_item)
                return result
        return values
    if base_name == 'move':
        marker = param if not isinstance(param, list) else (param[0] if param else '')
        if not marker or marker not in values:
            return values
        offset = parse_suffix_int(1)
        if offset == 0:
            return values
        result = values[:]
        idx = result.index(marker)
        item = result.pop(idx)
        new_index = max(0, min(len(result), idx + offset))
        result.insert(new_index, item)
        return result
    if base_name in ('putafter', 'putbefore', 'putfirst', 'putlast'):
        count = parse_suffix_int(1, max_value=len(values))
        if count <= 0:
            return values
        if base_name == 'putlast':
            leading = values[:count]
            rest = values[count:]
            return rest + leading
        if base_name == 'putfirst':
            trailing = values[-count:]
            rest = values[:-count]
            return trailing + rest
        marker = param if not isinstance(param, list) else (param[0] if param else '')
        trailing = values[-count:] if count > 0 else []
        rest = values[:-count] if count > 0 else values[:]
        if marker in rest:
            idx = rest.index(marker)
            if base_name == 'putafter':
                return rest[:idx + 1] + trailing + rest[idx + 1:]
            return rest[:idx] + trailing + rest[idx:]
        return values

    # Substitution helpers
    if base_name == 'then':
        replacement = param if param is not None else ''
        if not values:
            return [replacement]
        return [replacement for _ in values]
    if base_name == 'else':
        if values:
            return values
        return [param if param is not None else '']

    return values


def normalize_date(date_str):
    """Normalize a date string to TiddlyWiki format (YYYYMMDDHHMMSSMMM).

    Supports:
    - YYYY-MM-DD -> YYYYMMDD000000000
    - YYYYMMDD -> YYYYMMDD000000000
    - YYYYMMDDHHMMSSMMM -> as-is

    Args:
        date_str: Date string in various formats

    Returns:
        Normalized date string in YYYYMMDDHHMMSSMMM format
    """
    if not date_str:
        return None

    # Remove any hyphens or colons
    clean_date = date_str.replace('-', '').replace(':', '').replace(' ', '')

    # Pad to 17 characters (TiddlyWiki format)
    if len(clean_date) == 8:  # YYYYMMDD
        clean_date += '000000000'
    elif len(clean_date) < 17:
        # Pad with zeros to reach 17 characters
        clean_date += '0' * (17 - len(clean_date))
    elif len(clean_date) > 17:
        # Truncate if too long
        clean_date = clean_date[:17]

    return clean_date


def extract_links_from_content(content):
    """Extract all [[Tiddler Name]] links from content.

    Args:
        content: The tiddler content as a string

    Returns:
        List of tiddler names that are linked to
    """
    import re
    if not content:
        return []

    # Pattern to match [[...]] links
    # This captures the content between [[ and ]]
    pattern = r'\[\[([^\]]+)\]\]'
    matches = re.findall(pattern, content)

    return matches


def find_backlinks(target_tiddler, tiddlers_dict):
    """Find all tiddlers that link TO the target tiddler.

    Args:
        target_tiddler: The tiddler name to find backlinks to
        tiddlers_dict: Dictionary mapping title -> tiddler data

    Returns:
        List of tiddler titles that link to the target
    """
    backlinks = []

    for title, tiddler in tiddlers_dict.items():
        # Get the tiddler's text content
        text = tiddler.get('text', '')
        if not text:
            continue

        # Extract links from this tiddler
        links = extract_links_from_content(text)

        # Check if target_tiddler is in the links
        if target_tiddler in links:
            backlinks.append(title)

    return backlinks


def find_forward_links(source_tiddler, tiddlers_dict):
    """Find all tiddlers that the source tiddler links TO.

    Args:
        source_tiddler: The tiddler name to find links from
        tiddlers_dict: Dictionary mapping title -> tiddler data

    Returns:
        List of tiddler titles that the source links to
    """
    if source_tiddler not in tiddlers_dict:
        return []

    tiddler = tiddlers_dict[source_tiddler]
    text = tiddler.get('text', '')

    if not text:
        return []

    return extract_links_from_content(text)


def extract_transcludes_from_content(content):
    """Extract transcluded tiddler titles from wiki text ({{Title}})."""
    if not content:
        return []
    pattern = r'\{\{([^\|\}]+)'
    return re.findall(pattern, content)


def find_backtranscludes(target_tiddler, tiddlers_dict):
    """Find tiddlers that transclude the target tiddler."""
    results = []
    for title, tiddler in tiddlers_dict.items():
        text = tiddler.get('text', '')
        if not text:
            continue
        targets = extract_transcludes_from_content(text)
        if target_tiddler in targets:
            results.append(title)
    return results


def find_forward_transcludes(source_tiddler, tiddlers_dict):
    """Find tiddlers that the source tiddler transcludes."""
    if source_tiddler not in tiddlers_dict:
        return []
    text = tiddlers_dict[source_tiddler].get('text', '')
    return extract_transcludes_from_content(text)



def apply_wiki_operator(operator_name, param, tiddler_titles, tiddlers_dict):
    """Apply a wiki operator that works with tiddlers."""
    name_lower = operator_name.lower()
    results = []

    # Tag-related operators
    if name_lower == 'tag':
        tag_name = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                tags = tiddler.get('tags', '')
                if isinstance(tags, str):
                    tag_list = tags.split() if tags else []
                else:
                    tag_list = tags or []
                if tag_name in tag_list:
                    results.append(title)
        return results

    if name_lower == 'tagging':
        tags_to_find = [param] if param else tiddler_titles
        found = []
        for tag in tags_to_find:
            for title, tiddler in tiddlers_dict.items():
                tags = tiddler.get('tags', '')
                if isinstance(tags, str):
                    tag_list = tags.split() if tags else []
                else:
                    tag_list = tags or []
                if tag in tag_list and title not in found:
                    found.append(title)
        return found

    if name_lower == 'tags':
        seen = set()
        tag_values = []
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tags = tiddlers_dict[title].get('tags', '')
                if isinstance(tags, str):
                    tag_list = tags.split() if tags else []
                else:
                    tag_list = tags or []
                for tag in tag_list:
                    if tag not in seen:
                        seen.add(tag)
                        tag_values.append(tag)
        return tag_values

    if name_lower == 'untagged':
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tags = tiddlers_dict[title].get('tags', '')
                tag_list = tags.split() if isinstance(tags, str) else (tags or [])
                if not tag_list:
                    results.append(title)
        return results

    # Field and data operators
    if name_lower == 'has':
        field_name = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict and field_name in tiddlers_dict[title]:
                results.append(title)
        return results

    if name_lower == 'get':
        field_name = param if param else 'text'
        for title in tiddler_titles:
            if title in tiddlers_dict and field_name in tiddlers_dict[title]:
                field_value = tiddlers_dict[title][field_name]
                if isinstance(field_value, list):
                    results.append(' '.join(str(v) for v in field_value))
                else:
                    results.append(str(field_value))
        return results

    if name_lower in ('getindex', 'jsonget', 'jsonextract', 'jsonindexes', 'jsontype'):
        index_name = param
        for title in tiddler_titles:
            data_source = None
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                if isinstance(tiddler.get('data'), dict):
                    data_source = tiddler['data']
                else:
                    try:
                        data_source = json.loads(tiddler.get('text', ''))
                    except Exception:
                        data_source = None
            if isinstance(data_source, dict):
                if name_lower == 'jsonindexes':
                    results.extend(list(data_source.keys()))
                elif index_name and index_name in data_source:
                    value = data_source[index_name]
                    if name_lower == 'jsontype':
                        results.append(type(value).__name__)
                    elif name_lower == 'jsonextract':
                        results.append(json.dumps(value))
                    else:
                        results.append(str(value))
        return results

    if name_lower == 'indexes':
        for title in tiddler_titles:
            if title in tiddlers_dict:
                data_field = tiddlers_dict[title].get('data')
                if isinstance(data_field, dict):
                    results.extend(list(data_field.keys()))
        return results

    if name_lower == 'field' or name_lower.startswith('field:'):
        field_name = None
        if ':' in operator_name:
            _, field_name = operator_name.split(':', 1)
            target_value = param if param is not None else ''
        else:
            field_name = param if param else ''
            target_value = ''
        if not field_name:
            return []
        for title in tiddler_titles:
            if title not in tiddlers_dict:
                continue
            tiddler = tiddlers_dict[title]
            field_value = tiddler.get(field_name, None)
            if target_value == '':
                if field_value is None or field_value == '':
                    results.append(title)
            else:
                if field_value is not None:
                    if isinstance(field_value, list):
                        field_str = ' '.join(str(v) for v in field_value)
                    else:
                        field_str = str(field_value)
                    if field_str == target_value:
                        results.append(title)
        return results

    # List/listed
    if name_lower == 'list':
        if isinstance(param, list):
            refs = param
        elif param is None or param == '':
            refs = ['']
        else:
            refs = [param]
        collected = []
        for ref in refs:
            ref_text = safe_str(ref)
            target_title = None
            field_name = 'list'
            index_name = None
            if '!!' in ref_text:
                target_title, field_name = ref_text.split('!!', 1)
            elif '##' in ref_text:
                target_title, index_name = ref_text.split('##', 1)
            else:
                target_title = ref_text if ref_text else None

            if not target_title:
                target_title = tiddler_titles[0] if tiddler_titles else None
            if not target_title or target_title not in tiddlers_dict:
                continue
            tiddler = tiddlers_dict[target_title]
            if index_name:
                data_source = None
                if isinstance(tiddler.get('data'), dict):
                    data_source = tiddler.get('data')
                else:
                    try:
                        data_source = json.loads(tiddler.get('text', ''))
                    except Exception:
                        data_source = None
                if isinstance(data_source, dict) and index_name in data_source:
                    value = data_source[index_name]
                    if isinstance(value, list):
                        collected.extend([str(v) for v in value])
                    elif value not in (None, ''):
                        collected.append(str(value))
            else:
                list_field = tiddler.get(field_name, '')
                if isinstance(list_field, str):
                    items = list_field.split() if list_field else []
                else:
                    items = list_field or []
                collected.extend(items)
        return collected

    if name_lower == 'listed':
        targets = tiddler_titles if tiddler_titles else ([param] if param else [])
        found = []
        for title, tiddler in tiddlers_dict.items():
            list_field = tiddler.get('list', '')
            if isinstance(list_field, str):
                items = list_field.split() if list_field else []
            else:
                items = list_field or []
            for target in targets:
                if target in items and title not in found:
                    found.append(title)
        return found

    if name_lower.startswith('contains'):
        field_name = 'list'
        if ':' in operator_name:
            _, field_name = operator_name.split(':', 1)
        if isinstance(param, list):
            target = param[0] if param else ''
        else:
            target = param if param else ''
        for title in tiddler_titles:
            if title not in tiddlers_dict:
                continue
            tiddler = tiddlers_dict[title]
            field_value = tiddler.get(field_name, '')
            if isinstance(field_value, list):
                list_values = field_value
            elif isinstance(field_value, str):
                list_values = field_value.split() if field_value else []
            else:
                list_values = []
            if target in list_values:
                results.append(title)
        return results

    if name_lower.startswith('regexp'):
        field_name = 'title'
        if ':' in operator_name:
            _, field_name = operator_name.split(':', 1)
        if isinstance(param, list):
            pattern = param[0] if param else ''
        else:
            pattern = param if param is not None else ''
        if pattern == '':
            return list(tiddler_titles)
        re_flags = 0
        if pattern.startswith('(?i)'):
            re_flags |= re.IGNORECASE
            pattern = pattern[4:]
        if pattern.endswith('(?i)'):
            re_flags |= re.IGNORECASE
            pattern = pattern[:-4]
        for title in tiddler_titles:
            if title not in tiddlers_dict:
                continue
            tiddler = tiddlers_dict[title]
            field_value = tiddler.get(field_name, '')
            if isinstance(field_value, list):
                field_text = ' '.join(str(v) for v in field_value)
            else:
                field_text = safe_str(field_value)
            try:
                if re.search(pattern, field_text, flags=re_flags):
                    results.append(title)
            except re.error:
                continue
        return results

    if name_lower.startswith('fields'):
        mode = None
        if ':' in operator_name:
            _, mode = operator_name.split(':', 1)
        if isinstance(param, list):
            field_filter = set(param)
        else:
            field_filter = set(split_param_values(param)) if param else set()
        for title in tiddler_titles:
            if title not in tiddlers_dict:
                continue
            field_names = list(tiddlers_dict[title].keys())
            if mode == 'include' and field_filter:
                field_names = [f for f in field_names if f in field_filter]
            elif mode == 'exclude' and field_filter:
                field_names = [f for f in field_names if f not in field_filter]
            results.extend(field_names)
        return results

    # Fundamental categories
    if name_lower == 'is':
        category = (param or '').lower()
        for title in tiddler_titles:
            if title not in tiddlers_dict:
                continue
            tiddler = tiddlers_dict[title]
            if category == 'system' and title.startswith('$:/'):
                results.append(title)
            elif category == 'shadow' and (title.startswith('$:/plugins/') or title.startswith('$:/themes/') or title.startswith('$:/languages/')):
                results.append(title)
            elif category == 'draft' and 'draft.of' in tiddler:
                results.append(title)
            elif category in ('tiddler', 'ordinary') and not title.startswith('$:/'):
                results.append(title)
        return results

    if name_lower == 'haschanged':
        return list(tiddler_titles)

    # Sorting by field
    if name_lower in ('sort', 'sortcs', 'nsort', 'nsortcs', 'sortan'):
        field_name = param if param else 'title'
        case_sensitive = name_lower in ('sortcs', 'nsortcs')

        def get_sort_key(title):
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                value = tiddler.get(field_name, title)
                if isinstance(value, list):
                    value = ' '.join(str(v) for v in value)
                value_str = str(value)
                return value_str if case_sensitive else value_str.lower()
            return title.lower() if not case_sensitive else title

        if name_lower in ('nsort', 'nsortcs', 'sortan'):
            def natural_key(title):
                key_text = get_sort_key(title)
                parts = re.split(r'(\d+)', key_text)
                processed = []
                for part in parts:
                    if part.isdigit():
                        processed.append(int(part))
                    else:
                        processed.append(part if case_sensitive else part.lower())
                return processed
            return sorted(tiddler_titles, key=natural_key)

        return sorted(tiddler_titles, key=get_sort_key)

    if name_lower == 'sortby':
        order_list = []
        if param:
            if param in tiddlers_dict:
                list_field = tiddlers_dict[param].get('list', '') or tiddlers_dict[param].get('text', '')
                if isinstance(list_field, str):
                    order_list = list_field.split() if list_field else []
                elif isinstance(list_field, list):
                    order_list = list_field
            else:
                order_list = split_param_values(param)
        if not order_list:
            return tiddler_titles
        order_map = {title: idx for idx, title in enumerate(order_list)}
        return sorted(tiddler_titles, key=lambda t: order_map.get(t, len(order_list) + tiddler_titles.index(t)))

    if name_lower == 'sortsub':
        key_results = []
        for title in tiddler_titles:
            sub_expr = f"[[{title}]]{param or ''}"
            try:
                sub_out = evaluate_filter(sub_expr, wiki_path=None)
            except Exception:
                sub_out = []
            key_results.append((title, sub_out[0] if sub_out else ''))
        return [title for title, _ in sorted(key_results, key=lambda item: safe_str(item[1]).lower())]

    # Unique per field
    if name_lower == 'each':
        field_name = param if param else 'title'
        seen = set()
        chosen = []
        for title in tiddler_titles:
            if title in tiddlers_dict:
                val = tiddlers_dict[title].get(field_name, None)
                if isinstance(val, list):
                    val = ' '.join(str(v) for v in val)
                val_str = str(val) if val is not None else None
                if val_str not in seen:
                    seen.add(val_str)
                    chosen.append(title)
        return chosen

    if name_lower == 'eachday':
        seen = set()
        chosen = []
        for title in tiddler_titles:
            created = tiddlers_dict.get(title, {}).get('created', '')
            day = str(created)[:8] if created else ''
            if day not in seen:
                seen.add(day)
                chosen.append(title)
        return chosen

    if name_lower in ('min', 'max'):
        field_name = param if param else 'title'
        is_min = name_lower == 'min'
        numeric_values = []
        for title in tiddler_titles:
            if title in tiddlers_dict:
                value = tiddlers_dict[title].get(field_name, None)
                if value is None:
                    continue
                if isinstance(value, list):
                    value = value[0] if value else None
                try:
                    numeric_values.append((title, float(value)))
                except (ValueError, TypeError):
                    continue
        if not numeric_values:
            return []
        target_value = min(numeric_values, key=lambda x: x[1])[1] if is_min else max(numeric_values, key=lambda x: x[1])[1]
        return [title for title, val in numeric_values if val == target_value]

    if name_lower == 'all':
        if not param:
            return tiddler_titles
        categories = param.split('+')
        result_list = []
        seen = set()
        for category in categories:
            category = category.strip()
            if category == 'tiddlers':
                for title in tiddlers_dict.keys():
                    if not title.startswith('$:/') and title not in seen:
                        result_list.append(title)
                        seen.add(title)
            elif category == 'system':
                for title in tiddlers_dict.keys():
                    if title.startswith('$:/') and title not in seen:
                        result_list.append(title)
                        seen.add(title)
            elif category == 'shadows':
                for title in tiddlers_dict.keys():
                    if (title.startswith('$:/plugins/') or title.startswith('$:/themes/') or title.startswith('$:/languages/')) and title not in seen:
                        result_list.append(title)
                        seen.add(title)
        return result_list

    # Date comparisons and day grouping
    if name_lower in ['created:after', 'created:before', 'modified:after', 'modified:before']:
        field_name, comparison = name_lower.split(':')
        target_date = normalize_date(param)
        if not target_date:
            return []
        results = []
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                tiddler_date = tiddler.get(field_name, None)
                if not tiddler_date:
                    continue
                normalized = normalize_date(str(tiddler_date))
                if comparison == 'after' and normalized > target_date:
                    results.append(title)
                elif comparison == 'before' and normalized < target_date:
                    results.append(title)
        return results

    if name_lower in ('days', 'sameday'):
        target = normalize_date(param) if param else None
        if not target:
            return tiddler_titles
        day_prefix = target[:8]
        return [title for title in tiddler_titles if str(tiddlers_dict.get(title, {}).get('created', '')).startswith(day_prefix)]

    # Pattern matching on fields (field:contains etc.)
    if ':' in operator_name and name_lower not in ['created:after', 'created:before', 'modified:after', 'modified:before']:
        parts = operator_name.split(':', 1)
        if len(parts) == 2:
            field_name, operation = parts
            if operation in ['contains', 'prefix', 'suffix', 'regexp']:
                for title in tiddler_titles:
                    if title in tiddlers_dict:
                        field_value = tiddlers_dict[title].get(field_name, None)
                        if field_value is None:
                            continue
                        if isinstance(field_value, list):
                            field_str = ' '.join(str(v) for v in field_value)
                        else:
                            field_str = str(field_value)
                        pattern = param if param is not None else ''
                        try:
                            if operation == 'contains' and pattern.lower() in field_str.lower():
                                results.append(title)
                            elif operation == 'prefix' and field_str.lower().startswith(pattern.lower()):
                                results.append(title)
                            elif operation == 'suffix' and field_str.lower().endswith(pattern.lower()):
                                results.append(title)
                            elif operation == 'regexp' and re.search(pattern, field_str, re.IGNORECASE):
                                results.append(title)
                        except re.error:
                            continue
                return results

    # Link and transclusion graph
    if name_lower == 'backlinks':
        targets = [param] if param else tiddler_titles
        res = []
        for tgt in targets:
            res.extend(find_backlinks(tgt, tiddlers_dict))
        unique = []
        seen = set()
        for item in res:
            if item not in seen:
                seen.add(item)
                unique.append(item)
        return unique

    if name_lower == 'links':
        res = []
        for title in tiddler_titles:
            res.extend(find_forward_links(title, tiddlers_dict))
        unique = []
        seen = set()
        for item in res:
            if item not in seen:
                seen.add(item)
                unique.append(item)
        return unique

    if name_lower == 'backtranscludes':
        targets = [param] if param else tiddler_titles
        res = []
        for tgt in targets:
            res.extend(find_backtranscludes(tgt, tiddlers_dict))
        unique = []
        seen = set()
        for item in res:
            if item not in seen:
                seen.add(item)
                unique.append(item)
        return unique

    if name_lower == 'transcludes':
        res = []
        for title in tiddler_titles:
            res.extend(find_forward_transcludes(title, tiddlers_dict))
        unique = []
        seen = set()
        for item in res:
            if item not in seen:
                seen.add(item)
                unique.append(item)
        return unique

    if name_lower == 'search':
        pattern = param if param else ''
        for title in tiddler_titles:
            text = tiddlers_dict.get(title, {}).get('text', '')
            if pattern.lower() in safe_str(text).lower():
                results.append(title)
        return results

    if name_lower == 'duplicateslugs':
        target_titles = tiddler_titles if tiddler_titles else list(tiddlers_dict.keys())
        slugs = {}
        for title in target_titles:
            slug = slugify_text(title)
            slugs.setdefault(slug, []).append(title)
        dupes = []
        for group in slugs.values():
            if len(group) > 1:
                dupes.extend(group)
        return dupes

    if name_lower == 'filter':
        subfilter = param if param is not None else ''
        selected = []
        for title in tiddler_titles:
            expr = f"[[{title}]]{subfilter}"
            try:
                if evaluate_filter(expr, wiki_path=None):
                    selected.append(title)
            except Exception:
                continue
        return selected

    if name_lower in ('subfilter', 'enlist'):
        expr = param if param is not None else ''
        if name_lower == 'enlist':
            return split_param_values(expr)
        return evaluate_filter(expr, wiki_path=None)

    if name_lower == 'enlist-input':
        gathered = []
        for title in tiddler_titles:
            gathered.extend(split_param_values(title))
        return gathered

    if name_lower == 'reduce':
        expr = param if param is not None else ''
        accumulator = []
        for title in tiddler_titles:
            accumulator.extend(evaluate_filter(f"[[{title}]]{expr}", wiki_path=None))
        return accumulator

    if name_lower.startswith('lookup'):
        # lookup[:default][:index][prefix,target]
        suffixes = name_lower.split(':')[1:]
        default_value = ''
        default_target = 'text'
        if suffixes:
            if suffixes[-1] == 'index':
                default_target = 'index'
                suffixes = suffixes[:-1]
            if suffixes:
                default_value = suffixes[0]

        if isinstance(param, list):
            prefix = param[0] if len(param) > 0 else ''
            target = param[1] if len(param) > 1 else None
        else:
            params = split_param_values_preserve_empty(param, maxsplit=1) if param else ['']
            prefix = params[0] if params else ''
            target = params[1] if len(params) > 1 else None

        field_name = 'text'
        index_part = None
        if prefix and '!!' in prefix:
            prefix, field_name = prefix.split('!!', 1)
        elif prefix and '##' in prefix:
            prefix, index_part = prefix.split('##', 1)
        elif target:
            if target.startswith('!!'):
                field_name = target[2:]
            elif target.startswith('##'):
                index_part = target[2:]
            else:
                if default_target == 'index':
                    index_part = target
                else:
                    field_name = target
        elif default_target == 'index':
            index_part = default_value

        resolved = []
        for title in tiddler_titles:
            target_title = prefix + title
            target_tiddler = tiddlers_dict.get(target_title)
            if not target_tiddler:
                if default_value != '':
                    resolved.append(default_value)
                continue
            if index_part:
                data_source = None
                if isinstance(target_tiddler.get('data'), dict):
                    data_source = target_tiddler.get('data')
                else:
                    try:
                        data_source = json.loads(target_tiddler.get('text', ''))
                    except Exception:
                        data_source = None
                if isinstance(data_source, dict) and index_part in data_source:
                    resolved.append(str(data_source[index_part]))
                elif default_value != '':
                    resolved.append(default_value)
            else:
                if field_name in target_tiddler:
                    val = target_tiddler[field_name]
                    resolved.append(val if isinstance(val, str) else str(val))
                elif default_value != '':
                    resolved.append(default_value)
        return resolved

    if name_lower == 'title':
        if param and param in tiddlers_dict:
            return [param]
        return []

    # Special Node.js / module oriented operators not applicable in this environment
    if name_lower in ['commands', 'deserialize', 'deserializers', 'editiondescription', 'editions', 'getvariable',
                      'modulesproperty', 'modules', 'moduletypes', 'plugintiddlers', 'shadowsource', 'storyviews',
                      'subtiddlerfields', 'variables']:
        return []

    # Fallback: treat as field filter
    field_name = operator_name
    for title in tiddler_titles:
        if title in tiddlers_dict:
            tiddler = tiddlers_dict[title]
            field_value = tiddler.get(field_name, None)
            if param is None or param == '':
                if field_value is None or field_value == '':
                    results.append(title)
            else:
                if field_value is not None:
                    if isinstance(field_value, list):
                        field_str = ' '.join(str(v) for v in field_value)
                    else:
                        field_str = str(field_value)
                    if field_str == param:
                        results.append(title)

    return results


def evaluate_filter(filter_expr, wiki_path=None):
    """Evaluate a TiddlyWiki filter expression and return the results.

    Args:
        filter_expr: Filter expression string
        wiki_path: Optional path to wiki file (required for wiki operators)

    Returns a list of string values.
    """
    runs = parse_filter_expression(filter_expr)

    # Load tiddlers if wiki_path provided
    tiddlers_dict = {}
    if wiki_path:
        tiddlers_list = tw_module.load_all_tiddlers(wiki_path)
        # Create dictionary mapping title -> tiddler
        tiddlers_dict = {t['title']: t for t in tiddlers_list if 'title' in t}

    wiki_ops = {
        'tag', 'tagging', 'tags', 'untagged', 'has', 'get', 'getindex', 'indexes', 'field', 'list', 'listed', 'contains', 'is', 'haschanged',
        'sort', 'sortcs', 'nsort', 'nsortcs', 'sortan', 'sortby', 'sortsub', 'each', 'eachday', 'min',
        'max', 'all', 'days', 'sameday', 'backlinks', 'links', 'backtranscludes', 'transcludes',
        'search', 'duplicateslugs', 'filter', 'subfilter', 'reduce', 'enlist', 'enlist-input', 'lookup', 'regexp', 'fields',
        'title', 'commands', 'deserialize', 'deserializers', 'editiondescription', 'editions',
        'getvariable', 'modulesproperty', 'modules', 'moduletypes', 'plugintiddlers', 'shadowsource',
        'storyviews', 'subtiddlerfields', 'variables'
    }

    # Operators that can work with or without a wiki (on literal values or tiddlers)
    flexible_wiki_ops = {'jsonget', 'jsonextract', 'jsonindexes', 'jsontype'}

    list_ops = {
        'first', 'last', 'rest', 'butfirst', 'bf', 'butlast', 'limit', 'nth', 'zth', 'after', 'before',
        'allafter', 'allbefore', 'reverse', 'order', 'unique', 'join', 'sort', 'sortcs', 'nsort', 'nsortcs',
        'sortan', 'count', 'sum', 'product', 'average', 'median', 'minall', 'maxall', 'variance',
        'standard-deviation', 'standard_deviation', 'range', 'append', 'prepend', 'remove', 'replace',
        'toggle', 'cycle', 'insertafter', 'insertbefore', 'move', 'putafter', 'putbefore', 'putfirst',
        'putlast', 'then', 'else', 'next', 'previous'
    }

    def normalize_prefix(raw_prefix):
        if raw_prefix is None or raw_prefix == '':
            return 'or'
        mapping = {
            '+': 'and',
            '-': 'except',
            '~': 'else',
            '=': 'all',
            'and': 'and',
            'or': 'or',
            'except': 'except',
            'else': 'else',
            'all': 'all',
            'intersection': 'intersection',
            'filter': 'filter',
            'map': 'map',
            'reduce': 'reduce',
            'sort': 'sort',
            'cascade': 'cascade',
            'then': 'then',
            'let': 'let'
        }
        return mapping.get(raw_prefix.lower(), 'or')

    def resolve_variable(name, current_title):
        if name == 'currentTiddler':
            return current_title or ''
        if name in variables:
            value = variables[name]
            if isinstance(value, list):
                return ' '.join(str(v) for v in value)
            return safe_str(value)
        return ''

    def resolve_text_ref(ref, current_title):
        if not wiki_path:
            return ''
        text = safe_str(ref)
        title = None
        field = None
        index = None
        if '!!' in text:
            title, field = text.split('!!', 1)
        elif '##' in text:
            title, index = text.split('##', 1)
        else:
            title = current_title
            field = text
        if title == '' or title is None:
            title = current_title
        if not title or title not in tiddlers_dict:
            return ''
        tiddler = tiddlers_dict[title]
        if index:
            data_source = None
            if isinstance(tiddler.get('data'), dict):
                data_source = tiddler.get('data')
            else:
                try:
                    data_source = json.loads(tiddler.get('text', ''))
                except Exception:
                    data_source = None
            if isinstance(data_source, dict) and index in data_source:
                return str(data_source[index])
            return ''
        if field is None:
            field = 'text'
        if field in tiddler:
            val = tiddler[field]
            if isinstance(val, list):
                return ' '.join(str(v) for v in val)
            return safe_str(val)
        return ''

    def resolve_param_exprs(param_exprs, current_title):
        if param_exprs is None:
            return None
        resolved = []
        for kind, text in param_exprs:
            if kind == 'hard':
                resolved.append(text)
            elif kind == 'soft':
                resolved.append(resolve_text_ref(text, current_title))
            elif kind == 'variable':
                resolved.append(resolve_variable(text, current_title))
        return resolved

    def collapse_params(resolved):
        if resolved is None:
            return None
        if len(resolved) == 0:
            return ''
        if len(resolved) == 1:
            return resolved[0]
        return resolved

    def apply_operators(values, operators):
        current = [str(v) for v in values]
        for operator_name, param in operators:
            negated = operator_name.startswith('!')
            op_clean = operator_name[1:] if negated else operator_name
            name_lower = op_clean.lower()
            list_base = name_lower.split(':', 1)[0]
            item_flag_ops = {'prefix', 'suffix', 'match', 'removeprefix', 'removesuffix', 'compare', 'search-replace'}

            resolved_param = collapse_params(resolve_param_exprs(param, current[0] if current else None))

            if (name_lower in wiki_ops
                    or name_lower in ['created:after', 'created:before', 'modified:after', 'modified:before']
                    or (':' in op_clean and list_base not in list_ops and list_base not in item_flag_ops)):
                if not wiki_path:
                    raise ValueError(f"Operator '{op_clean}' requires a wiki file")
                param_for_wiki = resolved_param
                if isinstance(resolved_param, list) and list_base not in ('lookup', 'fields'):
                    param_for_wiki = resolved_param[0] if resolved_param else ''
                step_output = apply_wiki_operator(op_clean, param_for_wiki, current, tiddlers_dict)
            elif name_lower in flexible_wiki_ops:
                # These operators can work with or without wiki
                if wiki_path:
                    step_output = apply_wiki_operator(op_clean, resolved_param, current, tiddlers_dict)
                else:
                    # Apply to literal values as JSON strings
                    param_value = resolved_param[0] if isinstance(resolved_param, list) and resolved_param else resolved_param
                    step_output = []
                    for v in current:
                        try:
                            data_source = json.loads(v)
                        except Exception:
                            continue
                        if isinstance(data_source, dict):
                            if name_lower == 'jsonindexes':
                                step_output.extend(list(data_source.keys()))
                            elif param_value and param_value in data_source:
                                value = data_source[param_value]
                                if name_lower == 'jsontype':
                                    step_output.append(type(value).__name__)
                                elif name_lower == 'jsonextract':
                                    step_output.append(json.dumps(value))
                                else:  # jsonget
                                    step_output.append(str(value))
            elif list_base in list_ops:
                use_negation = negated and list_base in ('append', 'prepend', 'range')
                step_output = apply_list_operator(op_clean, resolved_param, current, negated=use_negation)
                if use_negation:
                    negated = False
            else:
                # Try as value operator first, fall back to field operator if we have a wiki
                step_output = []
                try:
                    for v in current:
                        per_value_param = collapse_params(resolve_param_exprs(param, v))
                        result = apply_operator(op_clean, per_value_param, v)
                        if isinstance(result, list):
                            step_output.extend([str(item) for item in result])
                        elif result is not None:
                            step_output.append(str(result))
                except ValueError as e:
                    # Unknown operator - try as field operator if we have wiki
                    if wiki_path and 'Unknown operator' in str(e):
                        step_output = apply_wiki_operator(op_clean, resolved_param, current, tiddlers_dict)
                    else:
                        raise

            if negated:
                exclusion = set(step_output)
                current = [v for v in current if v not in exclusion]
            else:
                current = [str(v) for v in step_output]
        return current

    current_values = []
    variables = {}  # Variable storage for :let prefix

    for run in runs:
        prefix = normalize_prefix(run.get('prefix'))
        operators = run.get('operators', [])

        if run['literals']:
            base_input = [str(v) for v in run['literals']]
        elif prefix in ['and', 'filter', 'map', 'reduce', 'sort', 'intersection', 'then', 'cascade', 'let']:
            base_input = current_values[:]
        elif wiki_path:
            base_input = list(tiddlers_dict.keys())
        else:
            base_input = []

        if prefix == 'cascade':
            # :cascade - evaluate filter run to get list of filters, then evaluate each on input
            # and return first non-empty result
            filter_list = apply_operators(base_input, operators)
            cascade_result = []
            for item in base_input:
                found = False
                for filter_expr in filter_list:
                    try:
                        # Evaluate each filter in the cascade on this item
                        test_result = evaluate_filter(f"[[{item}]]{filter_expr}", wiki_path=wiki_path)
                        if test_result:
                            cascade_result.extend(test_result)
                            found = True
                            break
                    except Exception:
                        continue
                if not found and item not in cascade_result:
                    # If no filter matched, item is not included
                    pass
            new_values = cascade_result
        elif prefix == 'then':
            # :then - if accumulated results are non-empty, replace with this run's output
            if current_values:
                new_values = apply_operators(base_input, operators)
            else:
                new_values = []
        elif prefix == 'let':
            # :let - assign filter run result to a variable
            # Variable name should be in the operators somehow
            # For now, store the result with a generated name
            new_values = apply_operators(base_input, operators)
            # Store in variables (would need variable extraction logic for proper implementation)
            variables['_let_result'] = new_values
            # :let doesn't change current_values by itself
            new_values = current_values[:]
        elif prefix == 'filter':
            filtered = []
            for item in base_input:
                if apply_operators([item], operators):
                    if item not in filtered:
                        filtered.append(str(item))
            new_values = filtered
        elif prefix == 'map':
            mapped = []
            for item in base_input:
                mapped.extend(apply_operators([item], operators))
            new_values = [str(v) for v in mapped]
        elif prefix == 'sort':
            def sort_key(item):
                res = apply_operators([item], operators)
                return safe_str(res[0]) if res else ''
            new_values = sorted(base_input, key=sort_key)
        elif prefix == 'reduce':
            accumulator = []
            for item in base_input:
                seed = accumulator + [item]
                accumulator = apply_operators(seed, operators) if operators else seed
            new_values = [str(v) for v in accumulator]
        else:
            new_values = apply_operators(base_input, operators)

        if prefix == 'and':
            current_values = new_values
        elif prefix == 'except':
            base_current = current_values if current_values else base_input
            exclusion = set(new_values)
            current_values = [v for v in base_current if v not in exclusion]
        elif prefix == 'else':
            if not current_values:
                for v in new_values:
                    if v not in current_values:
                        current_values.append(v)
        elif prefix == 'all':
            current_values.extend(new_values)
        elif prefix == 'intersection':
            base_current = current_values if current_values else base_input
            inclusion = set(new_values)
            current_values = [v for v in base_current if v in inclusion]
        elif prefix in ('filter', 'map', 'reduce', 'sort', 'cascade', 'then', 'let'):
            current_values = new_values
        else:  # default 'or' behaviour (append without duplicates)
            for v in new_values:
                if v not in current_values:
                    current_values.append(v)

    return current_values


def filter_command(filter_expr, wiki_path=None):
    """Execute a filter expression and print results.

    Args:
        filter_expr: Filter expression string
        wiki_path: Optional path to wiki file (required for wiki operators)
    """
    try:
        results = evaluate_filter(filter_expr, wiki_path=wiki_path)
        for result in results:
            # Format numbers nicely (remove trailing .0 for integers)
            try:
                num = float(result)
                if num == int(num):
                    print(int(num))
                else:
                    print(num)
            except (ValueError, TypeError):
                print(result)
    except Exception as e:
        print(f"Error evaluating filter: {e}", file=sys.stderr)
        sys.exit(1)
