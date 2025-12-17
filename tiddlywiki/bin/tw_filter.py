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
    parts = split_param_values(param, delimiters=(',', '|'))
    if len(parts) >= 2:
        return parts[0], parts[1]
    elif len(parts) == 1:
        return parts[0], ''
    return '', ''


def parse_filter_expression(filter_expr):
    """Parse a TiddlyWiki filter expression into runs with optional prefixes."""
    # Split runs when we see a run prefix at depth 0; whitespace alone does not split runs
    runs_raw = []
    buf = ''
    depth = 0
    for idx, ch in enumerate(filter_expr):
        if ch == '[':
            depth += 1
        elif ch == ']':
            depth = max(0, depth - 1)

        is_prefix_char = ch in '+-~=' and (idx + 1 < len(filter_expr) and filter_expr[idx + 1] == '[')
        named_prefix_split = ch == ':' and buf.strip()

        if depth == 0 and (is_prefix_char or named_prefix_split):
            if buf.strip():
                runs_raw.append(buf.strip())
                buf = ch
                continue
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

                if pos < len(run_text) and run_text[pos] == '[':
                    param_start = pos + 1
                    param_end = run_text.find(']', param_start)
                    if param_end == -1:
                        raise ValueError(f"Unclosed operator parameter at position {pos}")
                    param_value = run_text[param_start:param_end]
                    operators.append((operator_name, param_value))
                    pos = param_end + 1
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
    s = safe_str(value)

    # Filtering / matching operators on strings
    if name == 'prefix':
        text = param if param is not None else ''
        return value if s.startswith(text) else None
    if name == 'suffix':
        text = param if param is not None else ''
        return value if s.endswith(text) else None
    if name == 'match':
        pattern = param if param is not None else ''
        return value if pattern.lower() in s.lower() else None
    if name == 'regexp':
        pattern = param if param is not None else ''
        try:
            return value if re.search(pattern, s) else None
        except re.error:
            return None
    if name == 'compare':
        target = param if param is not None else ''
        # Support numeric comparisons if target starts with < or >
        if target.startswith('>'):
            cmp_val = to_number(target[1:], None)
            return value if cmp_val is not None and to_number(s, None) is not None and to_number(s) > cmp_val else None
        if target.startswith('<'):
            cmp_val = to_number(target[1:], None)
            return value if cmp_val is not None and to_number(s, None) is not None and to_number(s) < cmp_val else None
        return value if s == target else None
    if name == 'contains':
        pattern = param if param is not None else ''
        return value if pattern.lower() in s.lower() else None
    if name == 'minlength':
        min_len = int(param) if param not in (None, '') else 0
        return value if len(s) >= min_len else None

    # String manipulation operators
    if name == 'removeprefix':
        text = param if param is not None else ''
        return s[len(text):] if text and s.startswith(text) else s
    if name == 'removesuffix':
        text = param if param is not None else ''
        return s[:-len(text)] if text and s.endswith(text) else s
    if name == 'addprefix':
        text = param if param is not None else ''
        return text + s
    if name == 'addsuffix':
        text = param if param is not None else ''
        return s + text

    # String formatting/transform
    if name == 'uppercase':
        return s.upper()
    if name == 'lowercase':
        return s.lower()
    if name == 'titlecase':
        return s.title()
    if name == 'sentencecase':
        return s[0].upper() + s[1:].lower() if s else s
    if name == 'trim':
        # If a parameter is supplied, strip that string from both ends; otherwise strip whitespace
        if param not in (None, ''):
            return s.strip(param)
        return s.strip()
    if name == 'length':
        return len(s)
    if name == 'slugify':
        return slugify_text(s)
    if name == 'pad':
        # param can be "length" or "length,char"
        parts = split_param_values(param)
        if not parts:
            return s
        target_len = int(parts[0]) if parts[0] else len(s)
        fill_char = parts[1] if len(parts) > 1 and parts[1] else ' '
        return s.ljust(target_len, fill_char)
    if name == 'split':
        if param is None or param == '':
            return s.split()
        return s.split(param)
    if name == 'splitregexp':
        pattern = param if param is not None else '\\s+'
        try:
            return re.split(pattern, s)
        except re.error:
            return [s]
    if name == 'splitbefore':
        delim = param if param is not None else ''
        if not delim:
            return s
        idx = s.find(delim)
        if idx == -1:
            return s
        return s[:idx]
    if name == 'search-replace':
        search, repl = parse_search_replace(param)
        if not search:
            return s
        return s.replace(search, repl)
    if name == 'format':
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
    if name == 'encodebase64':
        return base64.b64encode(s.encode('utf-8')).decode('utf-8')
    if name == 'decodebase64':
        try:
            return base64.b64decode(s.encode('utf-8')).decode('utf-8')
        except Exception:
            return ''
    if name == 'encodeuri':
        return urllib.parse.quote(s, safe='/:')
    if name == 'encodeuricomponent':
        return urllib.parse.quote(s, safe='')
    if name == 'decodeuri':
        return urllib.parse.unquote(s)
    if name == 'decodeuricomponent':
        return urllib.parse.unquote_plus(s)
    if name == 'encodehtml':
        import html
        return html.escape(s)
    if name == 'decodehtml':
        import html
        return html.unescape(s)
    if name == 'escaperegexp':
        return re.escape(s)
    if name == 'escapecss':
        return css_escape(s)
    if name == 'stringify':
        return json.dumps(s)
    if name == 'jsonstringify':
        return json.dumps(s)
    if name in ('jsonget', 'jsonextract', 'jsonindexes', 'jsontype', 'jsonset'):
        try:
            data = json.loads(s)
        except Exception:
            data = None
        if data is None:
            return ''
        if name == 'jsonindexes':
            return list(data.keys()) if isinstance(data, dict) else []
        if name == 'jsonset':
            key, val = parse_search_replace(param)
            if key:
                if isinstance(data, dict):
                    data[key] = val
                    return json.dumps(data)
            return s
        if isinstance(data, dict) and param in data:
            value = data[param]
            if name == 'jsontype':
                return type(value).__name__
            if name == 'jsonextract':
                return json.dumps(value)
            return str(value)
        return ''
    if name == 'sha256':
        return hashlib.sha256(s.encode('utf-8')).hexdigest()
    if name == 'charcode':
        # value is numeric code; if missing use param
        if s == '' and param:
            s = safe_str(param)
        try:
            return chr(int(float(s)))
        except Exception:
            return ''
    if name == 'levenshtein':
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
    if name == 'add':
        return num_value + to_number(param)
    if name == 'subtract':
        return num_value - to_number(param)
    if name == 'multiply':
        return num_value * to_number(param, 1.0)
    if name == 'divide':
        denom = to_number(param, 1.0)
        if denom == 0:
            raise ValueError("Division by zero")
        return num_value / denom
    if name == 'remainder':
        denom = to_number(param, 1.0)
        if denom == 0:
            raise ValueError("Modulo by zero")
        return num_value % denom
    if name == 'negate':
        return -num_value
    if name == 'abs':
        return abs(num_value)
    if name == 'power':
        return math.pow(num_value, to_number(param, 1.0))
    if name == 'log':
        base = to_number(param, math.e)
        try:
            return math.log(num_value, base)
        except ValueError:
            return 0
    if name == 'sin':
        return math.sin(num_value)
    if name == 'cos':
        return math.cos(num_value)
    if name == 'tan':
        return math.tan(num_value)
    if name == 'asin':
        try:
            return math.asin(num_value)
        except ValueError:
            return 0
    if name == 'acos':
        try:
            return math.acos(num_value)
        except ValueError:
            return 0
    if name == 'atan':
        return math.atan(num_value)
    if name == 'atan2':
        x_val = to_number(param, 0.0)
        return math.atan2(num_value, x_val)
    if name == 'round':
        return round(num_value)
    if name == 'ceil':
        return math.ceil(num_value)
    if name == 'floor':
        return math.floor(num_value)
    if name == 'trunc':
        return math.trunc(num_value)
    if name == 'untrunc':
        # Round away from zero
        return math.ceil(num_value) if num_value > 0 else math.floor(num_value)
    if name == 'sign':
        return -1 if num_value < 0 else (1 if num_value > 0 else 0)
    if name == 'precision':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}g') if digits > 0 else str(num_value)
    if name == 'fixed':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}f')
    if name == 'exponential':
        digits = int(param) if param else 0
        return format(num_value, f'.{digits}e')
    if name == 'max':
        return max(num_value, to_number(param))
    if name == 'min':
        return min(num_value, to_number(param))

    raise ValueError(f"Unknown operator: {operator_name}")


def apply_list_operator(operator_name, param, values):
    """Apply a list-level operator to the entire list of values."""
    name = operator_name
    name_lower = name.lower()

    # Selection and slicing
    if name_lower == 'first':
        n = int(param) if param not in (None, '') else 1
        return values[:n]
    if name_lower == 'last':
        n = int(param) if param not in (None, '') else 1
        return values[-n:] if n != 0 else []
    if name_lower in ('rest', 'butfirst', 'bf'):
        n = int(param) if param not in (None, '') else 1
        return values[n:] if len(values) > n else []
    if name_lower == 'butlast':
        n = int(param) if param not in (None, '') else 1
        return values[:-n] if n <= len(values) else []
    if name_lower == 'limit':
        n = int(param) if param not in (None, '') else 1
        return values[:n] if n >= 0 else values[n:]
    if name_lower == 'nth':
        n = int(param) if param not in (None, '') else 1
        return [values[n - 1]] if 1 <= n <= len(values) else []
    if name_lower == 'zth':
        n = int(param) if param not in (None, '') else 0
        return [values[n]] if 0 <= n < len(values) else []
    if name_lower == 'after':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[idx + 1:idx + 2]
        return []
    if name_lower == 'before':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[idx - 1:idx] if idx > 0 else []
        return []
    if name_lower == 'allafter':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[idx + 1:]
        return []
    if name_lower == 'allbefore':
        marker = param if param is not None else ''
        if marker in values:
            idx = values.index(marker)
            return values[:idx]
        return []
    if name_lower == 'next':
        if param:
            return apply_list_operator('after', param, values)
        return values[1:] if values else []
    if name_lower == 'previous':
        if param:
            return apply_list_operator('before', param, values)
        return values[:-1] if values else []

    # Ordering and uniqueness
    if name_lower == 'reverse':
        return list(reversed(values))
    if name_lower == 'order':
        # Simple implementation: reverse when asked, otherwise pass through
        if param and str(param).lower().startswith('rev'):
            return list(reversed(values))
        return values
    if name_lower == 'unique':
        seen = set()
        unique_values = []
        for item in values:
            if item not in seen:
                seen.add(item)
                unique_values.append(item)
        return unique_values
    if name_lower == 'join':
        sep = param if param is not None else ''
        return [sep.join(values)]

    # Sorting for raw values (field-aware sorts handled in wiki operators)
    if name_lower in ('sort', 'sortcs'):
        case_sensitive = name_lower == 'sortcs'
        if case_sensitive:
            return sorted(values)
        return sorted(values, key=lambda v: safe_str(v).lower())
    if name_lower in ('nsort', 'nsortcs', 'sortan'):
        case_sensitive = name_lower == 'nsortcs'
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
    if name_lower == 'count':
        return [str(len(values))]
    if name_lower == 'sum':
        nums = [to_number(v, 0.0) for v in values]
        return [str(sum(nums))]
    if name_lower == 'product':
        nums = [to_number(v, 0.0) for v in values]
        result = 1
        for n in nums:
            result *= n
        return [str(result)]
    if name_lower == 'average':
        nums = [to_number(v, 0.0) for v in values]
        return [str(sum(nums) / len(nums))] if nums else ['0']
    if name_lower == 'median':
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.median(nums))] if nums else ['0']
    if name_lower == 'minall':
        nums = [to_number(v, 0.0) for v in values]
        return [str(min(nums))] if nums else []
    if name_lower == 'maxall':
        nums = [to_number(v, 0.0) for v in values]
        return [str(max(nums))] if nums else []
    if name_lower == 'variance':
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.pvariance(nums))] if len(nums) > 1 else ['0']
    if name_lower in ('standard-deviation', 'standard_deviation'):
        nums = [to_number(v, 0.0) for v in values]
        return [str(statistics.pstdev(nums))] if len(nums) > 1 else ['0']

    # List construction helpers
    if name_lower == 'range':
        parts = split_param_values(param)
        if not parts:
            return []
        # Determine begin, end, step according to docs
        if len(parts) == 1:
            end = float(parts[0])
            begin = 1 if end >= 1 else -1
            step = 1 if end >= begin else -1
        elif len(parts) == 2:
            begin, end = float(parts[0]), float(parts[1])
            step = 1 if end >= begin else -1
        else:
            begin, end, step = float(parts[0]), float(parts[1]), float(parts[2])
            if step == 0:
                step = 1
        results = []
        # Limit to avoid runaway loops
        limit = 10000
        count = 0
        current = begin
        # Determine comparison direction
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
        return formatted

    # Mutation/combination of list contents
    if name_lower == 'append':
        extras = split_param_values(param)
        return values + extras
    if name_lower == 'prepend':
        extras = split_param_values(param)
        return extras + values
    if name_lower == 'remove':
        targets = set(split_param_values(param))
        if not targets:
            return values
        return [v for v in values if v not in targets]
    if name_lower == 'replace':
        old, new = parse_search_replace(param)
        if not old:
            return values
        return [new if v == old else v for v in values]
    if name_lower == 'toggle':
        target = param if param is not None else ''
        if target in values:
            return [v for v in values if v != target]
        return values + [target]
    if name_lower == 'cycle':
        cycle_values = split_param_values(param)
        if not cycle_values:
            return values
        cycled = []
        for v in values:
            if v in cycle_values:
                idx = cycle_values.index(v)
                cycled.append(cycle_values[(idx + 1) % len(cycle_values)])
            else:
                cycled.append(v)
        if not cycled:
            cycled.append(cycle_values[0])
        return cycled
    if name_lower in ('insertafter', 'insertbefore'):
        parts = split_param_values(param)
        if len(parts) >= 2:
            marker, new_item = parts[0], parts[1]
            result = values[:]
            if marker in result:
                idx = result.index(marker)
                insert_at = idx + 1 if name_lower == 'insertafter' else idx
                result.insert(insert_at, new_item)
                return result
        return values
    if name_lower == 'move':
        parts = split_param_values(param)
        if len(parts) == 2:
            marker, offset_raw = parts
            try:
                offset = int(offset_raw)
            except ValueError:
                return values
            if marker in values:
                result = values[:]
                idx = result.index(marker)
                item = result.pop(idx)
                new_index = max(0, min(len(result), idx + offset))
                result.insert(new_index, item)
                return result
        elif param not in (None, ''):
            try:
                shift = int(param)
            except ValueError:
                shift = 0
            if shift == 0 or not values:
                return values
            shift = shift % len(values)
            return values[shift:] + values[:shift]
        return values
    if name_lower == 'putafter':
        tokens = split_param_values(param)
        if not tokens:
            return values
        result = [v for v in values if v not in tokens]
        for token in tokens:
            if token in values:
                idx = values.index(token)
                result.insert(idx + 1 if idx + 1 <= len(result) else len(result), token)
        return result
    if name_lower == 'putbefore':
        tokens = split_param_values(param)
        if not tokens:
            return values
        result = [v for v in values if v not in tokens]
        for token in reversed(tokens):
            result.insert(0, token)
        return result
    if name_lower == 'putfirst':
        tokens = split_param_values(param)
        if not tokens:
            return values
        rest = [v for v in values if v not in tokens]
        return tokens + rest
    if name_lower == 'putlast':
        tokens = split_param_values(param)
        if not tokens:
            return values
        rest = [v for v in values if v not in tokens]
        return rest + tokens

    # Substitution helpers
    if name_lower == 'then':
        replacement = param if param is not None else ''
        if not values:
            return [replacement]
        return [replacement for _ in values]
    if name_lower == 'else':
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

    if name_lower == 'field':
        field_name = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict and field_name in tiddlers_dict[title]:
                results.append(title)
        return results

    # List/listed
    if name_lower == 'list':
        if param:
            target_title = param
            tiddler = tiddlers_dict.get(target_title)
            if not tiddler:
                return []
            list_field = tiddler.get('list', '')
            if isinstance(list_field, str):
                return list_field.split() if list_field else []
            return list_field or []
        else:
            collected = []
            for title in tiddler_titles:
                tiddler = tiddlers_dict.get(title)
                if not tiddler:
                    continue
                list_field = tiddler.get('list', '')
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

    if name_lower == 'contains':
        target = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                tag_list = tiddler.get('tags', '')
                list_field = tiddler.get('list', '')
                tag_values = tag_list.split() if isinstance(tag_list, str) else (tag_list or [])
                list_values = list_field.split() if isinstance(list_field, str) else (list_field or [])
                if target in tag_values or target in list_values:
                    results.append(title)
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

    if name_lower == 'lookup':
        prefix = param if param else ''
        field_name = 'text'
        index_part = None
        if '!!' in prefix:
            prefix, field_name = prefix.split('!!', 1)
        elif '##' in prefix:
            prefix, index_part = prefix.split('##', 1)
        resolved = []
        for title in tiddler_titles:
            target_title = prefix + title
            target = tiddlers_dict.get(target_title)
            if not target:
                continue
            if index_part:
                try:
                    data = json.loads(target.get('text', ''))
                    if isinstance(data, dict) and index_part in data:
                        resolved.append(str(data[index_part]))
                except Exception:
                    continue
            else:
                if field_name in target:
                    val = target[field_name]
                    resolved.append(val if isinstance(val, str) else str(val))
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
        'search', 'duplicateslugs', 'filter', 'subfilter', 'reduce', 'enlist', 'enlist-input', 'lookup',
        'title', 'commands', 'deserialize', 'deserializers', 'editiondescription', 'editions',
        'getvariable', 'modulesproperty', 'modules', 'moduletypes', 'plugintiddlers', 'shadowsource',
        'storyviews', 'subtiddlerfields', 'variables'
    }

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
            'filter': 'and',
            'map': 'and',
            'reduce': 'and',
            'sort': 'and',
            'cascade': 'and',
            'then': 'and'
        }
        return mapping.get(raw_prefix.lower(), 'or')

    def evaluate_run(run, current_output):
        prefix = normalize_prefix(run.get('prefix'))

        if run['literals']:
            values = [str(v) for v in run['literals']]
        elif prefix in ['and', 'intersection']:
            values = current_output[:]
        elif wiki_path:
            values = list(tiddlers_dict.keys())
        else:
            values = []

        for operator_name, param in run['operators']:
            negated = operator_name.startswith('!')
            op_clean = operator_name[1:] if negated else operator_name
            name_lower = op_clean.lower()

            if name_lower in wiki_ops or name_lower in ['created:after', 'created:before', 'modified:after', 'modified:before'] or ':' in op_clean:
                if not wiki_path:
                    raise ValueError(f"Operator '{op_clean}' requires a wiki file")
                step_output = apply_wiki_operator(op_clean, param, values, tiddlers_dict)
            elif name_lower in list_ops:
                step_output = apply_list_operator(op_clean, param, values)
            else:
                step_output = []
                for v in values:
                    result = apply_operator(op_clean, param, v)
                    if isinstance(result, list):
                        step_output.extend([str(item) for item in result])
                    elif result is not None:
                        step_output.append(str(result))

            if negated:
                exclusion = set(step_output)
                values = [v for v in values if v not in exclusion]
            else:
                values = [str(v) for v in step_output]

        return values, prefix

    current_values = []

    for run in runs:
        run_output, prefix = evaluate_run(run, current_values)
        if prefix == 'and':
            current_values = run_output
        elif prefix == 'except':
            exclusion = set(run_output)
            current_values = [v for v in current_values if v not in exclusion]
        elif prefix == 'else':
            if not current_values:
                for v in run_output:
                    if v not in current_values:
                        current_values.append(v)
        elif prefix == 'all':
            current_values.extend(run_output)
        elif prefix == 'intersection':
            inclusion = set(run_output)
            current_values = [v for v in current_values if v in inclusion]
        else:  # default 'or' behaviour (append without duplicates)
            for v in run_output:
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
