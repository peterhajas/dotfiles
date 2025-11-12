#!/usr/bin/env python3
"""
TiddlyWiki Filter Expression Evaluator

This module provides functionality to parse and evaluate TiddlyWiki filter expressions
with support for various operator types: math, string, string manipulation, list, and wiki operators.

Based on TiddlyWiki's filter syntax: https://tiddlywiki.com/static/Filters.html
"""

import sys
import os

# Import wiki loading functionality from tw script
script_dir = os.path.dirname(os.path.abspath(__file__))
tw_path = os.path.join(script_dir, "tw")

# Import tw module
import importlib.util
import importlib.machinery
loader = importlib.machinery.SourceFileLoader("tw", tw_path)
tw_module = loader.load_module()


def parse_filter_expression(filter_expr):
    """Parse a TiddlyWiki filter expression into tokens.

    Returns a list of filter runs, where each run contains literals and operators.
    Example: "[[5]]add[7]" -> [{'literals': ['5'], 'operators': [('add', '7')]}]
    Example: "[[1]] [[2]]+[add[10]]" -> [
        {'literals': ['1', '2'], 'operators': []},
        {'literals': [], 'operators': [('add', '10')]}
    ]
    """
    # Split into filter runs
    runs = []
    current_pos = 0

    while current_pos < len(filter_expr):
        # Skip whitespace
        while current_pos < len(filter_expr) and filter_expr[current_pos].isspace():
            current_pos += 1

        if current_pos >= len(filter_expr):
            break

        # Check for filter run prefix +[...]
        if filter_expr[current_pos:current_pos+2] == '+[':
            # Find matching ]
            bracket_count = 0
            pos = current_pos + 1  # Start after +
            while pos < len(filter_expr):
                if filter_expr[pos] == '[':
                    bracket_count += 1
                elif filter_expr[pos] == ']':
                    bracket_count -= 1
                    if bracket_count == 0:
                        # Found matching ]
                        run_text = filter_expr[current_pos+2:pos]  # Content inside +[...]
                        runs.append((True, run_text))
                        current_pos = pos + 1
                        break
                pos += 1
            else:
                raise ValueError("Unclosed filter run bracket")
        else:
            # Regular run (not additive) - continues until +[ or end
            # Check if it starts with [ AND is a single wrapped run (not [[literal]])
            if current_pos < len(filter_expr) and filter_expr[current_pos] == '[' and filter_expr[current_pos:current_pos+2] != '[[':
                # Find matching ] for outer brackets
                bracket_count = 0
                pos = current_pos
                found_wrapped = False
                while pos < len(filter_expr):
                    if filter_expr[pos] == '[':
                        bracket_count += 1
                    elif filter_expr[pos] == ']':
                        bracket_count -= 1
                        if bracket_count == 0:
                            # Found matching ] - check if this is the end of the run
                            # (i.e., nothing follows except whitespace or +[)
                            rest = filter_expr[pos+1:].lstrip()
                            if not rest or rest.startswith('+['):
                                # This is a wrapped run
                                run_text = filter_expr[current_pos+1:pos]  # Content inside [...]
                                if run_text:
                                    runs.append((False, run_text))
                                current_pos = pos + 1
                                found_wrapped = True
                                break
                            else:
                                # Not a wrapped run, treat as unwrapped
                                break
                    pos += 1
                else:
                    raise ValueError("Unclosed filter run bracket")

                # If we didn't find a wrapped run, treat as unwrapped
                if not found_wrapped:
                    next_run = filter_expr.find('+[', current_pos)
                    if next_run == -1:
                        run_end = len(filter_expr)
                    else:
                        run_end = next_run

                    run_text = filter_expr[current_pos:run_end].strip()
                    if run_text:
                        runs.append((False, run_text))
                    current_pos = run_end
            else:
                # No brackets or starts with [[, continues until +[ or end
                next_run = filter_expr.find('+[', current_pos)
                if next_run == -1:
                    run_end = len(filter_expr)
                else:
                    run_end = next_run

                run_text = filter_expr[current_pos:run_end].strip()
                if run_text:
                    runs.append((False, run_text))
                current_pos = run_end

    # Parse each run into literals and operators
    parsed_runs = []
    for is_additive, run_text in runs:
        literals = []
        operators = []
        pos = 0

        while pos < len(run_text):
            # Skip whitespace
            while pos < len(run_text) and run_text[pos].isspace():
                pos += 1

            if pos >= len(run_text):
                break

            # Check for literal [[...]]
            if run_text[pos:pos+2] == '[[':
                end = run_text.find(']]', pos + 2)
                if end == -1:
                    raise ValueError(f"Unclosed literal at position {pos}")
                literal_value = run_text[pos+2:end]
                literals.append(literal_value)
                pos = end + 2
            # Check for operator name[param]
            elif run_text[pos].isalpha():
                # Find operator name
                name_start = pos
                while pos < len(run_text) and (run_text[pos].isalnum() or run_text[pos] == '_'):
                    pos += 1
                operator_name = run_text[name_start:pos]

                # Check if it has a parameter [...]
                if pos < len(run_text) and run_text[pos] == '[':
                    param_start = pos + 1
                    param_end = run_text.find(']', param_start)
                    if param_end == -1:
                        raise ValueError(f"Unclosed operator parameter at position {pos}")
                    param_value = run_text[param_start:param_end]
                    operators.append((operator_name, param_value))
                    pos = param_end + 1
                else:
                    # Operator with no parameter
                    operators.append((operator_name, None))
            else:
                raise ValueError(f"Unexpected character '{run_text[pos]}' at position {pos}")

        parsed_runs.append({
            'is_additive': is_additive,
            'literals': literals,
            'operators': operators
        })

    return parsed_runs


def apply_operator(operator_name, param, value):
    """Apply a single operator to a single value.

    Based on TiddlyWiki's operators:

    Math operators:
    - add[N] - add N to the value
    - subtract[N] - subtract N from the value
    - multiply[N] - multiply the value by N
    - divide[N] - divide the value by N
    - remainder[N] - value modulo N
    - negate - negate the value
    - abs - absolute value

    String operators:
    - uppercase - convert to uppercase
    - lowercase - convert to lowercase
    - titlecase - convert to title case
    - sentencecase - convert to sentence case
    - trim - remove leading/trailing whitespace
    - length - return string length
    - split[delimiter] - split string by delimiter (returns list)

    String manipulation operators:
    - prefix[text] - keeps only items starting with text (filter operator)
    - suffix[text] - keeps only items ending with text (filter operator)
    - removeprefix[text] - removes prefix from items
    - removesuffix[text] - removes suffix from items
    """
    # String manipulation operators (prefix/suffix)
    if operator_name == 'prefix':
        # Filter operator - returns None if doesn't match (filtered out)
        text = param if param is not None else ''
        if str(value).startswith(text):
            return value
        return None  # Signal to filter this out
    elif operator_name == 'suffix':
        # Filter operator - returns None if doesn't match (filtered out)
        text = param if param is not None else ''
        if str(value).endswith(text):
            return value
        return None  # Signal to filter this out
    elif operator_name == 'removeprefix':
        text = param if param is not None else ''
        s = str(value)
        if s.startswith(text):
            return s[len(text):]
        return s
    elif operator_name == 'removesuffix':
        text = param if param is not None else ''
        s = str(value)
        if s.endswith(text):
            return s[:-len(text)] if text else s
        return s

    # String operators
    if operator_name == 'uppercase':
        return str(value).upper()
    elif operator_name == 'lowercase':
        return str(value).lower()
    elif operator_name == 'titlecase':
        return str(value).title()
    elif operator_name == 'sentencecase':
        s = str(value)
        if s:
            return s[0].upper() + s[1:].lower()
        return s
    elif operator_name == 'trim':
        return str(value).strip()
    elif operator_name == 'length':
        return len(str(value))
    elif operator_name == 'split':
        # Split returns multiple values, so we need to handle this specially
        # If param is None or empty string, use default whitespace splitting
        if param is None or param == '':
            return str(value).split()
        else:
            return str(value).split(param)

    # Math operators
    try:
        num_value = float(value) if value else 0.0
    except (ValueError, TypeError):
        num_value = 0.0

    if operator_name == 'add':
        param_num = float(param) if param else 0.0
        return num_value + param_num
    elif operator_name == 'subtract':
        param_num = float(param) if param else 0.0
        return num_value - param_num
    elif operator_name == 'multiply':
        param_num = float(param) if param else 0.0
        return num_value * param_num
    elif operator_name == 'divide':
        param_num = float(param) if param else 1.0
        if param_num == 0:
            raise ValueError("Division by zero")
        return num_value / param_num
    elif operator_name == 'remainder':
        param_num = float(param) if param else 1.0
        if param_num == 0:
            raise ValueError("Modulo by zero")
        return num_value % param_num
    elif operator_name == 'negate':
        return -num_value
    elif operator_name == 'abs':
        return abs(num_value)
    else:
        raise ValueError(f"Unknown operator: {operator_name}")


def apply_list_operator(operator_name, param, values):
    """Apply a list-level operator to the entire list of values.

    List operators from TiddlyWiki:
    - first[N] - return first N items (default 1)
    - last[N] - return last N items (default 1)
    - rest[] - return all but first item
    - butfirst[] - same as rest
    - butlast[] - return all but last item
    """
    if operator_name == 'first':
        n = int(param) if param else 1
        return values[:n]
    elif operator_name == 'last':
        n = int(param) if param else 1
        return values[-n:] if n > 0 else []
    elif operator_name == 'rest' or operator_name == 'butfirst':
        return values[1:] if len(values) > 0 else []
    elif operator_name == 'butlast':
        return values[:-1] if len(values) > 0 else []
    else:
        raise ValueError(f"Unknown list operator: {operator_name}")


def apply_wiki_operator(operator_name, param, tiddler_titles, tiddlers_dict):
    """Apply a wiki operator that works with tiddlers.

    Wiki operators from TiddlyWiki:
    - tag[TagName] - filter tiddlers by tag
    - has[field] - filter tiddlers that have a field
    - get[field] - get field values from tiddlers

    Args:
        operator_name: The operator name
        param: The operator parameter
        tiddler_titles: List of tiddler titles (input)
        tiddlers_dict: Dictionary mapping title -> tiddler data

    Returns:
        List of results (titles or field values)
    """
    results = []

    if operator_name == 'tag':
        # Filter tiddlers by tag
        tag_name = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                tags = tiddler.get('tags', '')
                # Tags can be space-separated string or list
                if isinstance(tags, list):
                    tag_list = tags
                elif isinstance(tags, str):
                    tag_list = tags.split() if tags else []
                else:
                    tag_list = []

                if tag_name in tag_list:
                    results.append(title)
        return results

    elif operator_name == 'has':
        # Filter tiddlers that have a field
        field_name = param if param else ''
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                if field_name in tiddler:
                    results.append(title)
        return results

    elif operator_name == 'get':
        # Get field values from tiddlers
        field_name = param if param else 'text'
        for title in tiddler_titles:
            if title in tiddlers_dict:
                tiddler = tiddlers_dict[title]
                if field_name in tiddler:
                    field_value = tiddler[field_name]
                    # Convert to string
                    if isinstance(field_value, list):
                        # For lists (like tags), join with spaces
                        results.append(' '.join(str(v) for v in field_value))
                    else:
                        results.append(str(field_value))
        return results

    else:
        raise ValueError(f"Unknown wiki operator: {operator_name}")


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

    # Start with empty list, or all tiddler titles if first run has no literals and wiki_path provided
    current_values = []

    for run_idx, run in enumerate(runs):
        if run['is_additive']:
            # Additive run: apply operators to current values
            new_values = current_values[:]
        else:
            # Replace run: start with literals
            new_values = run['literals'][:]
            # Special case: if first run has no literals and wiki_path provided, start with all tiddlers
            if run_idx == 0 and not new_values and wiki_path:
                new_values = list(tiddlers_dict.keys())

        # Apply each operator to all current values
        for operator_name, param in run['operators']:
            # Check if this is a wiki operator
            if operator_name in ['tag', 'has', 'get']:
                if not wiki_path:
                    raise ValueError(f"Operator '{operator_name}' requires a wiki file")
                new_values = apply_wiki_operator(operator_name, param, new_values, tiddlers_dict)
            # Check if this is a list-level operator
            elif operator_name in ['first', 'last', 'rest', 'butfirst', 'butlast']:
                # These operate on the entire list
                new_values = apply_list_operator(operator_name, param, new_values)
            else:
                # Item-level operators
                temp_values = []
                for v in new_values:
                    result = apply_operator(operator_name, param, v)
                    # Handle operators that return lists (like split)
                    if isinstance(result, list):
                        temp_values.extend([str(item) for item in result])
                    # Handle filtering operators that return None (prefix, suffix)
                    elif result is not None:
                        temp_values.append(str(result))
                    # If result is None, filter it out (don't append)
                new_values = temp_values

        current_values = new_values

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
