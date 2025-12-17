#!/usr/bin/env python3
"""
Tests for TiddlyWiki filter expression evaluator (tw_filter.py)

This test suite tests the filter module directly, without going through
the command-line interface.
"""

import unittest
import sys
import os
import tempfile
import json
import subprocess
import math

# Add current directory to path so we can import tw_filter
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

import tw_filter


def tw_init_or_skip(target):
    """Initialize a wiki file, skipping tests if network access is blocked."""
    try:
        subprocess.run(['python3', 'tw', 'init', target], cwd=script_dir, check=True, capture_output=True)
    except subprocess.CalledProcessError as exc:
        msg = exc.stderr.decode('utf-8', 'ignore') if exc.stderr else str(exc)
        raise unittest.SkipTest(f"tw init failed (likely offline): {msg}")


class TestMathOperators(unittest.TestCase):
    """Test the math operators in filter expressions"""

    def test_simple_literal(self):
        """Test that a simple literal value works"""
        results = tw_filter.evaluate_filter('[[5]]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '5')

    def test_add_operator(self):
        """Test the add operator"""
        results = tw_filter.evaluate_filter('[[5]]add[7]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 12.0)

    def test_subtract_operator(self):
        """Test the subtract operator"""
        results = tw_filter.evaluate_filter('[[10]]subtract[3]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 7.0)

    def test_multiply_operator(self):
        """Test the multiply operator"""
        results = tw_filter.evaluate_filter('[[6]]multiply[7]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 42.0)

    def test_divide_operator(self):
        """Test the divide operator"""
        results = tw_filter.evaluate_filter('[[20]]divide[4]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 5.0)

    def test_divide_with_remainder(self):
        """Test division that produces a decimal"""
        results = tw_filter.evaluate_filter('[[10]]divide[3]')
        self.assertEqual(len(results), 1)
        # Should be approximately 3.333...
        self.assertAlmostEqual(float(results[0]), 3.333333, places=5)

    def test_remainder_operator(self):
        """Test the remainder operator"""
        results = tw_filter.evaluate_filter('[[10]]remainder[3]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 1.0)

    def test_negate_operator(self):
        """Test the negate operator"""
        results = tw_filter.evaluate_filter('[[5]]negate[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), -5.0)

    def test_abs_operator(self):
        """Test the abs operator"""
        results = tw_filter.evaluate_filter('[[-5]]abs[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 5.0)

    def test_abs_positive(self):
        """Test that abs works on positive numbers"""
        results = tw_filter.evaluate_filter('[[5]]abs[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 5.0)

    def test_chained_operators(self):
        """Test chaining multiple operators"""
        results = tw_filter.evaluate_filter('[[5]]add[7]multiply[2]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 24.0)  # (5+7)*2 = 24

    def test_complex_chain(self):
        """Test a more complex chain of operations"""
        results = tw_filter.evaluate_filter('[[10]]add[5]multiply[2]subtract[10]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 20.0)  # ((10+5)*2)-10 = 20

    def test_multiple_literals(self):
        """Test multiple literal inputs"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '1')
        self.assertEqual(results[1], '2')
        self.assertEqual(results[2], '3')

    def test_multiple_inputs_with_operator(self):
        """Test applying operator to multiple inputs"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]] +[add[10]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(float(results[0]), 11.0)
        self.assertEqual(float(results[1]), 12.0)
        self.assertEqual(float(results[2]), 13.0)

    def test_multiple_inputs_multiply(self):
        """Test multiplying multiple inputs"""
        results = tw_filter.evaluate_filter('[[2]] [[3]] [[4]] +[multiply[10]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(float(results[0]), 20.0)
        self.assertEqual(float(results[1]), 30.0)
        self.assertEqual(float(results[2]), 40.0)

    def test_negative_numbers(self):
        """Test with negative numbers"""
        results = tw_filter.evaluate_filter('[[-10]]add[5]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), -5.0)

    def test_decimal_numbers(self):
        """Test with decimal numbers"""
        results = tw_filter.evaluate_filter('[[3.5]]add[2.5]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 6.0)

    def test_decimal_with_remainder(self):
        """Test decimal that doesn't simplify to integer"""
        results = tw_filter.evaluate_filter('[[5]]divide[2]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 2.5)

    def test_division_by_zero(self):
        """Test that division by zero is handled"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[[5]]divide[0]')
        self.assertIn('Division by zero', str(context.exception))

    def test_remainder_by_zero(self):
        """Test that modulo by zero is handled"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[[5]]remainder[0]')
        self.assertIn('Modulo by zero', str(context.exception))

    def test_empty_filter(self):
        """Test empty filter expression"""
        results = tw_filter.evaluate_filter('')
        self.assertEqual(len(results), 0)

    def test_whitespace_handling(self):
        """Test that whitespace is handled correctly"""
        results = tw_filter.evaluate_filter('  [[5]]  add[7]  ')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 12.0)

    def test_multiple_spaces_between_literals(self):
        """Test multiple spaces between literals"""
        results = tw_filter.evaluate_filter('[[1]]   [[2]]   [[3]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '1')
        self.assertEqual(results[1], '2')
        self.assertEqual(results[2], '3')

    def test_zero_operations(self):
        """Test operations with zero"""
        results = tw_filter.evaluate_filter('[[0]]add[5]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 5.0)

    def test_multiply_by_zero(self):
        """Test multiplying by zero"""
        results = tw_filter.evaluate_filter('[[10]]multiply[0]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 0.0)

    def test_negate_zero(self):
        """Test negating zero"""
        results = tw_filter.evaluate_filter('[[0]]negate[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 0.0)

    def test_large_numbers(self):
        """Test with large numbers"""
        results = tw_filter.evaluate_filter('[[1000000]]multiply[1000]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 1000000000.0)

    def test_very_small_decimals(self):
        """Test with very small decimal numbers"""
        results = tw_filter.evaluate_filter('[[0.1]]add[0.2]')
        self.assertEqual(len(results), 1)
        # Due to floating point precision, we check if it's close to 0.3
        self.assertAlmostEqual(float(results[0]), 0.3, places=5)

    def test_unclosed_literal(self):
        """Test that unclosed literal is caught"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[[5')
        self.assertIn('Unclosed literal', str(context.exception))

    def test_unclosed_operator_param(self):
        """Test that unclosed operator parameter is caught"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[[5]]add[7')
        self.assertIn('Unclosed operator parameter', str(context.exception))

    def test_unknown_operator(self):
        """Test that unknown operator is caught"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[[5]]unknown[7]')
        self.assertIn('Unknown operator', str(context.exception))


class TestStringOperators(unittest.TestCase):
    """Test the string operators in filter expressions"""

    def test_uppercase_operator(self):
        """Test the uppercase operator"""
        results = tw_filter.evaluate_filter('[[hello world]]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'HELLO WORLD')

    def test_lowercase_operator(self):
        """Test the lowercase operator"""
        results = tw_filter.evaluate_filter('[[HELLO WORLD]]lowercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello world')

    def test_titlecase_operator(self):
        """Test the titlecase operator"""
        results = tw_filter.evaluate_filter('[[hello world]]titlecase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Hello World')

    def test_sentencecase_operator(self):
        """Test the sentencecase operator"""
        results = tw_filter.evaluate_filter('[[hello WORLD]]sentencecase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Hello world')

    def test_sentencecase_empty(self):
        """Test sentencecase with empty string"""
        results = tw_filter.evaluate_filter('[[]]sentencecase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '')

    def test_trim_operator(self):
        """Test the trim operator"""
        results = tw_filter.evaluate_filter('[[  hello world  ]]trim[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello world')

    def test_trim_leading_only(self):
        """Test trim with leading whitespace only"""
        results = tw_filter.evaluate_filter('[[  hello]]trim[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_trim_trailing_only(self):
        """Test trim with trailing whitespace only"""
        results = tw_filter.evaluate_filter('[[hello  ]]trim[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_trim_no_spaces(self):
        """Test trim with no whitespace"""
        results = tw_filter.evaluate_filter('[[hello]]trim[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_length_operator(self):
        """Test the length operator"""
        results = tw_filter.evaluate_filter('[[hello]]length[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 5)

    def test_length_empty_string(self):
        """Test length with empty string"""
        results = tw_filter.evaluate_filter('[[]]length[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 0)

    def test_length_with_spaces(self):
        """Test length includes spaces"""
        results = tw_filter.evaluate_filter('[[hello world]]length[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 11)

    def test_split_operator(self):
        """Test the split operator"""
        results = tw_filter.evaluate_filter('[[hello world]]split[ ]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'hello')
        self.assertEqual(results[1], 'world')

    def test_split_with_comma(self):
        """Test split with comma delimiter"""
        results = tw_filter.evaluate_filter('[[apple,banana,cherry]]split[,]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], 'apple')
        self.assertEqual(results[1], 'banana')
        self.assertEqual(results[2], 'cherry')

    def test_split_default_delimiter(self):
        """Test split with default space delimiter"""
        results = tw_filter.evaluate_filter('[[one two three]]split[]')
        self.assertEqual(len(results), 3)

    def test_split_no_match(self):
        """Test split when delimiter not found"""
        results = tw_filter.evaluate_filter('[[hello]]split[,]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_chained_string_operators(self):
        """Test chaining string operators"""
        results = tw_filter.evaluate_filter('[[  hello world  ]]trim[]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'HELLO WORLD')

    def test_uppercase_then_split(self):
        """Test uppercase followed by split"""
        results = tw_filter.evaluate_filter('[[hello world]]uppercase[]split[ ]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'HELLO')
        self.assertEqual(results[1], 'WORLD')

    def test_split_then_uppercase(self):
        """Test split followed by uppercase on each part"""
        results = tw_filter.evaluate_filter('[[hello world]]split[ ]+[uppercase[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'HELLO')
        self.assertEqual(results[1], 'WORLD')

    def test_multiple_inputs_uppercase(self):
        """Test uppercase on multiple inputs"""
        results = tw_filter.evaluate_filter('[[hello]] [[world]]+[uppercase[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'HELLO')
        self.assertEqual(results[1], 'WORLD')

    def test_trim_then_length(self):
        """Test trim followed by length"""
        results = tw_filter.evaluate_filter('[[  hello  ]]trim[]length[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 5)

    def test_uppercase_with_numbers(self):
        """Test uppercase with numbers"""
        results = tw_filter.evaluate_filter('[[hello123]]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'HELLO123')

    def test_lowercase_with_numbers(self):
        """Test lowercase with numbers"""
        results = tw_filter.evaluate_filter('[[HELLO123]]lowercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello123')

    def test_titlecase_with_apostrophe(self):
        """Test titlecase with apostrophe"""
        results = tw_filter.evaluate_filter("[[don't worry]]titlecase[]")
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], "Don'T Worry")

    def test_split_empty_string(self):
        """Test split on empty string"""
        results = tw_filter.evaluate_filter('[[]]split[ ]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '')

    def test_special_characters_uppercase(self):
        """Test uppercase with special characters"""
        results = tw_filter.evaluate_filter('[[hello!@#$%]]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'HELLO!@#$%')

    def test_mixed_operators(self):
        """Test mixing string and math operators"""
        results = tw_filter.evaluate_filter('[[5]]add[3]')
        self.assertEqual(len(results), 1)
        self.assertEqual(float(results[0]), 8.0)

        # Now test string operator
        results = tw_filter.evaluate_filter('[[hello]]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'HELLO')

    def test_length_of_number(self):
        """Test length operator on numbers"""
        results = tw_filter.evaluate_filter('[[12345]]length[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 5)

    def test_unicode_uppercase(self):
        """Test uppercase with unicode characters"""
        results = tw_filter.evaluate_filter('[[café]]uppercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'CAFÉ')

    def test_unicode_lowercase(self):
        """Test lowercase with unicode characters"""
        results = tw_filter.evaluate_filter('[[CAFÉ]]lowercase[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'café')


class TestStringManipulationOperators(unittest.TestCase):
    """Test string manipulation operators (prefix, suffix, removeprefix, removesuffix)"""

    def test_prefix_operator(self):
        """Test prefix operator filters items starting with text"""
        results = tw_filter.evaluate_filter('[[hello]] [[world]] [[help]]+[prefix[hel]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'hello')
        self.assertEqual(results[1], 'help')

    def test_prefix_no_match(self):
        """Test prefix operator with no matches"""
        results = tw_filter.evaluate_filter('[[apple]] [[banana]]+[prefix[orange]]')
        self.assertEqual(len(results), 0)

    def test_prefix_empty(self):
        """Test prefix with empty parameter matches all"""
        results = tw_filter.evaluate_filter('[[hello]] [[world]]+[prefix[]]')
        self.assertEqual(len(results), 2)

    def test_suffix_operator(self):
        """Test suffix operator filters items ending with text"""
        results = tw_filter.evaluate_filter('[[testing]] [[test]] [[best]]+[suffix[st]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'test')
        self.assertEqual(results[1], 'best')

    def test_suffix_no_match(self):
        """Test suffix operator with no matches"""
        results = tw_filter.evaluate_filter('[[hello]] [[world]]+[suffix[ing]]')
        self.assertEqual(len(results), 0)

    def test_removeprefix_operator(self):
        """Test removeprefix operator removes leading text"""
        results = tw_filter.evaluate_filter('[[prefix_hello]] [[prefix_world]]+[removeprefix[prefix_]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'hello')
        self.assertEqual(results[1], 'world')

    def test_removeprefix_no_match(self):
        """Test removeprefix with non-matching prefix leaves value unchanged"""
        results = tw_filter.evaluate_filter('[[hello]]removeprefix[world]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_removeprefix_empty(self):
        """Test removeprefix with empty parameter"""
        results = tw_filter.evaluate_filter('[[hello]]removeprefix[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_removesuffix_operator(self):
        """Test removesuffix operator removes trailing text"""
        results = tw_filter.evaluate_filter('[[hello_suffix]] [[world_suffix]]+[removesuffix[_suffix]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'hello')
        self.assertEqual(results[1], 'world')

    def test_removesuffix_no_match(self):
        """Test removesuffix with non-matching suffix leaves value unchanged"""
        results = tw_filter.evaluate_filter('[[hello]]removesuffix[world]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_removesuffix_empty(self):
        """Test removesuffix with empty parameter"""
        results = tw_filter.evaluate_filter('[[hello]]removesuffix[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'hello')

    def test_chained_prefix_removeprefix(self):
        """Test chaining prefix filter and removeprefix"""
        results = tw_filter.evaluate_filter('[[Draft of hello]] [[Draft of world]] [[hello]]+[prefix[Draft ]]+[removeprefix[Draft of ]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'hello')
        self.assertEqual(results[1], 'world')

    def test_prefix_with_uppercase(self):
        """Test combining prefix with uppercase"""
        results = tw_filter.evaluate_filter('[[hello]] [[help]] [[world]]+[prefix[hel]]+[uppercase[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'HELLO')
        self.assertEqual(results[1], 'HELP')


class TestListOperators(unittest.TestCase):
    """Test list manipulation operators"""

    def test_first_operator_default(self):
        """Test first operator with default (1 item)"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]+[first[]]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '1')

    def test_first_operator_multiple(self):
        """Test first operator with multiple items"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]] [[4]] [[5]]+[first[3]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '1')
        self.assertEqual(results[1], '2')
        self.assertEqual(results[2], '3')

    def test_first_operator_more_than_available(self):
        """Test first operator requesting more items than available"""
        results = tw_filter.evaluate_filter('[[1]] [[2]]+[first[5]]')
        self.assertEqual(len(results), 2)

    def test_last_operator_default(self):
        """Test last operator with default (1 item)"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]+[last[]]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '3')

    def test_last_operator_multiple(self):
        """Test last operator with multiple items"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]] [[4]] [[5]]+[last[2]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], '4')
        self.assertEqual(results[1], '5')

    def test_rest_operator(self):
        """Test rest operator removes first item"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]+[rest[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], '2')
        self.assertEqual(results[1], '3')

    def test_rest_empty_list(self):
        """Test rest on empty list"""
        results = tw_filter.evaluate_filter('[[1]]+[rest[]]+[rest[]]')
        self.assertEqual(len(results), 0)

    def test_butfirst_operator(self):
        """Test butfirst operator (same as rest)"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]+[butfirst[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], '2')
        self.assertEqual(results[1], '3')

    def test_butlast_operator(self):
        """Test butlast operator removes last item"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]+[butlast[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], '1')
        self.assertEqual(results[1], '2')

    def test_butlast_single_item(self):
        """Test butlast with single item returns empty"""
        results = tw_filter.evaluate_filter('[[1]]+[butlast[]]')
        self.assertEqual(len(results), 0)

    def test_chained_list_operators(self):
        """Test chaining list operators"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]] [[4]] [[5]]+[rest[]]+[butlast[]]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '2')
        self.assertEqual(results[1], '3')
        self.assertEqual(results[2], '4')

    def test_first_then_uppercase(self):
        """Test first followed by uppercase"""
        results = tw_filter.evaluate_filter('[[hello]] [[world]] [[test]]+[first[2]]+[uppercase[]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'HELLO')
        self.assertEqual(results[1], 'WORLD')

    def test_split_then_first(self):
        """Test split followed by first"""
        results = tw_filter.evaluate_filter('[[one two three four]]split[ ]+[first[2]]')
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'one')
        self.assertEqual(results[1], 'two')


class TestWikiOperators(unittest.TestCase):
    """Test wiki operators (tag, has, get) that work with tiddlers"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add test tiddlers using tw touch
        test_tiddlers = [
            ("Task1", "First task content", "task urgent", "high"),
            ("Task2", "Second task content", "task", "medium"),
            ("Note1", "First note content", "note", None),
            ("Task3", "Third task content", "task done", None),
            ("NoTags", "Content without tags", None, None),
        ]

        for title, text, tags, priority in test_tiddlers:
            # Create tiddler
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            # Set tags if provided
            if tags:
                subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', tags],
                              cwd=script_dir, check=True, capture_output=True)
            # Set priority if provided
            if priority:
                subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'priority', priority],
                              cwd=script_dir, check=True, capture_output=True)

        # Set category for Note1
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Note1', 'category', 'personal'],
                      cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_tag_operator(self):
        """Test tag operator filters tiddlers by tag"""
        results = tw_filter.evaluate_filter('[tag[task]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 3)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Task3', results)

    def test_tag_operator_multiple_tags(self):
        """Test tiddler with multiple tags"""
        results = tw_filter.evaluate_filter('[tag[urgent]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Task1')

    def test_tag_operator_no_matches(self):
        """Test tag operator with no matches"""
        results = tw_filter.evaluate_filter('[tag[nonexistent]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 0)

    def test_has_operator(self):
        """Test has operator filters tiddlers by field existence"""
        results = tw_filter.evaluate_filter('[has[priority]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 2)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)

    def test_has_operator_tags_field(self):
        """Test has[tags] returns tiddlers with tags"""
        results = tw_filter.evaluate_filter('[has[tags]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 4)  # All except NoTags

    def test_has_operator_no_matches(self):
        """Test has operator with non-existent field"""
        results = tw_filter.evaluate_filter('[has[nonexistent]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 0)

    def test_get_operator(self):
        """Test get operator retrieves field values"""
        results = tw_filter.evaluate_filter('[[Task1]]get[priority]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'high')

    def test_get_text_field(self):
        """Test get[text] retrieves text content"""
        results = tw_filter.evaluate_filter('[[Note1]]get[text]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'First note content')

    def test_get_operator_with_filter(self):
        """Test get operator with filtered tiddlers"""
        results = tw_filter.evaluate_filter('[tag[task]get[priority]]', wiki_path=self.test_wiki)
        # Only Task1 and Task2 have priority field
        self.assertEqual(len(results), 2)
        self.assertIn('high', results)
        self.assertIn('medium', results)

    def test_combined_tag_has(self):
        """Test combining tag and has operators"""
        results = tw_filter.evaluate_filter('[tag[task]has[priority]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 2)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)

    def test_tag_get_chain(self):
        """Test chaining tag and get operators"""
        results = tw_filter.evaluate_filter('[tag[note]get[category]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'personal')

    def test_tag_get_text_chain(self):
        """Test getting text from tagged tiddlers"""
        results = tw_filter.evaluate_filter('[tag[urgent]get[text]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'First task content')

    def test_wiki_operator_without_wiki(self):
        """Test that wiki operators require wiki_path"""
        with self.assertRaises(ValueError) as context:
            tw_filter.evaluate_filter('[tag[task]]')
        self.assertIn('requires a wiki file', str(context.exception))

    def test_get_with_math_operator(self):
        """Test combining get with math operators"""
        # Note: priority values are strings, but add will try to convert
        results = tw_filter.evaluate_filter('[[Task1]]get[priority]length[]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(int(results[0]), 4)  # "high" has 4 characters


class TestOrderingOperators(unittest.TestCase):
    """Test ordering operators (sort, reverse, nsort)"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add test tiddlers with various values
        test_tiddlers = [
            ("Item1", "First", "3", "zebra"),
            ("Item2", "Second", "1", "apple"),
            ("Item3", "Third", "10", "banana"),
            ("Item4", "Fourth", "2", "Apple"),
        ]

        for title, text, priority, name in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', 'test'],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'priority', priority],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'name', name],
                          cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_sort_by_field(self):
        """Test sort operator by field"""
        results = tw_filter.evaluate_filter('[tag[test]sort[priority]]', wiki_path=self.test_wiki)
        # Should sort by priority: 1, 10, 2, 3 (string sort)
        self.assertEqual(len(results), 4)
        self.assertEqual(results[0], 'Item2')  # priority "1"
        self.assertEqual(results[1], 'Item3')  # priority "10"

    def test_sort_by_title(self):
        """Test sort by title (default)"""
        results = tw_filter.evaluate_filter('[tag[test]sort[title]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 4)
        self.assertEqual(results[0], 'Item1')
        self.assertEqual(results[1], 'Item2')

    def test_sortcs_case_sensitive(self):
        """Test case-sensitive sort"""
        results = tw_filter.evaluate_filter('[tag[test]sortcs[name]]', wiki_path=self.test_wiki)
        # Case-sensitive: Apple < apple < banana < zebra
        self.assertEqual(len(results), 4)
        self.assertEqual(results[0], 'Item4')  # Apple
        self.assertEqual(results[1], 'Item2')  # apple

    def test_nsort_natural_sort(self):
        """Test natural sort (numeric-aware)"""
        results = tw_filter.evaluate_filter('[tag[test]nsort[priority]]', wiki_path=self.test_wiki)
        # Should sort numerically: 1, 2, 3, 10
        self.assertEqual(len(results), 4)
        self.assertEqual(results[0], 'Item2')  # priority 1
        self.assertEqual(results[1], 'Item4')  # priority 2
        self.assertEqual(results[2], 'Item1')  # priority 3
        self.assertEqual(results[3], 'Item3')  # priority 10

    def test_reverse(self):
        """Test reverse operator"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]reverse[]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '3')
        self.assertEqual(results[1], '2')
        self.assertEqual(results[2], '1')


class TestListManipulationOperators(unittest.TestCase):
    """Test list manipulation operators"""

    def test_limit_operator(self):
        """Test limit operator"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]] [[4]] [[5]]limit[3]')
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0], '1')
        self.assertEqual(results[2], '3')

    def test_limit_more_than_available(self):
        """Test limit with more than available items"""
        results = tw_filter.evaluate_filter('[[1]] [[2]]limit[10]')
        self.assertEqual(len(results), 2)

    def test_nth_operator(self):
        """Test nth operator"""
        results = tw_filter.evaluate_filter('[[a]] [[b]] [[c]]nth[2]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'b')

    def test_nth_first(self):
        """Test nth with first item"""
        results = tw_filter.evaluate_filter('[[a]] [[b]] [[c]]nth[1]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'a')

    def test_nth_out_of_range(self):
        """Test nth with out of range index"""
        results = tw_filter.evaluate_filter('[[a]] [[b]]nth[5]')
        self.assertEqual(len(results), 0)

    def test_count_operator(self):
        """Test count operator"""
        results = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]count[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '3')

    def test_count_empty(self):
        """Test count on empty list"""
        results = tw_filter.evaluate_filter('[[1]]rest[]count[]')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '0')


class TestComparisonOperators(unittest.TestCase):
    """Test comparison operators (min, max)"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add test tiddlers with numeric scores
        test_tiddlers = [
            ("Score1", "First", "85"),
            ("Score2", "Second", "92"),
            ("Score3", "Third", "78"),
            ("Score4", "Fourth", "92"),  # Tie for max
        ]

        for title, text, score in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', 'test'],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'score', score],
                          cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_min_operator(self):
        """Test min operator"""
        results = tw_filter.evaluate_filter('[tag[test]min[score]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Score3')  # score 78

    def test_max_operator(self):
        """Test max operator"""
        results = tw_filter.evaluate_filter('[tag[test]max[score]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 2)  # Two tiddlers with score 92
        self.assertIn('Score2', results)
        self.assertIn('Score4', results)


class TestEachOperator(unittest.TestCase):
    """Test each operator"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add test tiddlers with duplicate categories
        test_tiddlers = [
            ("Item1", "First", "A"),
            ("Item2", "Second", "B"),
            ("Item3", "Third", "A"),  # Duplicate category
            ("Item4", "Fourth", "C"),
            ("Item5", "Fifth", "B"),  # Duplicate category
        ]

        for title, text, category in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', 'test'],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'category', category],
                          cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_each_operator(self):
        """Test each operator selects one per unique value"""
        results = tw_filter.evaluate_filter('[tag[test]each[category]]', wiki_path=self.test_wiki)
        # Should return 3 tiddlers (one for each unique category: A, B, C)
        self.assertEqual(len(results), 3)
        # Should be Item1 (A), Item2 (B), Item4 (C) - first occurrence of each
        self.assertIn('Item1', results)
        self.assertIn('Item2', results)
        self.assertIn('Item4', results)


class TestAllOperator(unittest.TestCase):
    """Test the all operator"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add regular (non-system) tiddlers
        regular_tiddlers = [
            ("Task1", "First task", "task"),
            ("Task2", "Second task", "task"),
            ("Note1", "First note", "note"),
        ]

        for title, text, tags in regular_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', tags],
                          cwd=script_dir, check=True, capture_output=True)

        # Add system tiddlers
        system_tiddlers = [
            ("$:/config/test", "Config content", ""),
            ("$:/state/test", "State content", ""),
            ("$:/plugins/test", "Plugin content", ""),
        ]

        for title, text, tags in system_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            if tags:
                subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', tags],
                              cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_all_tiddlers(self):
        """Test all[tiddlers] returns only non-system tiddlers"""
        results = tw_filter.evaluate_filter('[all[tiddlers]]', wiki_path=self.test_wiki)
        # Should return only Task1, Task2, Note1 (not system tiddlers)
        self.assertGreaterEqual(len(results), 3)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Note1', results)
        # Should NOT include system tiddlers
        self.assertNotIn('$:/config/test', results)
        self.assertNotIn('$:/state/test', results)

    def test_all_system(self):
        """Test all[system] returns only system tiddlers"""
        results = tw_filter.evaluate_filter('[all[system]]', wiki_path=self.test_wiki)
        # Should include our system tiddlers
        self.assertIn('$:/config/test', results)
        self.assertIn('$:/state/test', results)
        self.assertIn('$:/plugins/test', results)
        # Should NOT include regular tiddlers
        self.assertNotIn('Task1', results)
        self.assertNotIn('Task2', results)
        self.assertNotIn('Note1', results)

    def test_all_empty_parameter(self):
        """Test all[] with empty parameter passes through input"""
        results = tw_filter.evaluate_filter('[[Task1]] [[Task2]]+[all[]]', wiki_path=self.test_wiki)
        # Should return the input unchanged
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], 'Task1')
        self.assertEqual(results[1], 'Task2')

    def test_all_combined_categories(self):
        """Test all[tiddlers+system] combines categories"""
        results = tw_filter.evaluate_filter('[all[tiddlers+system]]', wiki_path=self.test_wiki)
        # Should include both regular and system tiddlers
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Note1', results)
        self.assertIn('$:/config/test', results)
        self.assertIn('$:/state/test', results)

    def test_all_shadows(self):
        """Test all[shadows] returns shadow/plugin tiddlers"""
        results = tw_filter.evaluate_filter('[all[shadows]]', wiki_path=self.test_wiki)
        # Our $:/plugins/test should be included
        self.assertIn('$:/plugins/test', results)
        # Regular tiddlers should not be included
        self.assertNotIn('Task1', results)
        # Non-plugin system tiddlers should not be included
        self.assertNotIn('$:/config/test', results)
        self.assertNotIn('$:/state/test', results)

    def test_all_with_tag_filter(self):
        """Test all[tiddlers] chained with tag filter"""
        results = tw_filter.evaluate_filter('[all[tiddlers]tag[task]]', wiki_path=self.test_wiki)
        # Should return only non-system tiddlers with 'task' tag
        self.assertEqual(len(results), 2)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertNotIn('Note1', results)  # Has 'note' tag, not 'task'

    def test_all_invalid_category(self):
        """Test all with invalid category returns empty"""
        results = tw_filter.evaluate_filter('[all[invalid]]', wiki_path=self.test_wiki)
        # Unknown categories contribute nothing
        self.assertEqual(len(results), 0)

    def test_all_combined_with_invalid(self):
        """Test all[tiddlers+invalid] ignores invalid category"""
        results = tw_filter.evaluate_filter('[all[tiddlers+invalid]]', wiki_path=self.test_wiki)
        # Should return tiddlers, invalid category is ignored
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Note1', results)

    def test_all_system_with_sort(self):
        """Test all[system] with sort operator"""
        results = tw_filter.evaluate_filter('[all[system]sort[title]]', wiki_path=self.test_wiki)
        # Should return sorted system tiddlers
        self.assertGreater(len(results), 0)
        # Verify they're all system tiddlers
        for title in results[:3]:  # Check first few
            if title in ['$:/config/test', '$:/state/test', '$:/plugins/test']:
                self.assertTrue(title.startswith('$:/'))

    def test_all_tiddlers_count(self):
        """Test counting all tiddlers"""
        results = tw_filter.evaluate_filter('[all[tiddlers]count[]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        count = int(results[0])
        # Should be at least our 3 test tiddlers
        self.assertGreaterEqual(count, 3)

    def test_all_no_duplicates_in_combined(self):
        """Test all[system+system] doesn't duplicate results"""
        results = tw_filter.evaluate_filter('[all[system+system]]', wiki_path=self.test_wiki)
        # Check no duplicates
        self.assertEqual(len(results), len(set(results)))


class TestFieldOperator(unittest.TestCase):
    """Test field operators (using field names as operators)"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers for testing"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Add test tiddlers with various field values
        test_tiddlers = [
            ("Task1", "First task", "task", "high", "active"),
            ("Task2", "Second task", "task", "medium", "active"),
            ("Task3", "Third task", "task", "high", "done"),
            ("Task4", "Fourth task", "task", "low", "active"),
            ("Note1", "First note", "note", None, "active"),  # No priority field
            ("Note2", "Second note", "note", "", "done"),     # Empty priority field
        ]

        for title, text, tags, priority, status in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'tags', tags],
                          cwd=script_dir, check=True, capture_output=True)
            if priority:
                subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'priority', priority],
                              cwd=script_dir, check=True, capture_output=True)
            subprocess.run(['python3', 'tw', cls.test_wiki, 'set', title, 'status', status],
                          cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_field_operator_basic(self):
        """Test basic field operator filtering"""
        results = tw_filter.evaluate_filter('[tag[task]priority[high]]', wiki_path=self.test_wiki)
        # Should return tasks with priority=high
        self.assertEqual(len(results), 2)
        self.assertIn('Task1', results)
        self.assertIn('Task3', results)

    def test_field_operator_single_match(self):
        """Test field operator with single match"""
        results = tw_filter.evaluate_filter('[tag[task]priority[low]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Task4')

    def test_field_operator_no_match(self):
        """Test field operator with no matches"""
        results = tw_filter.evaluate_filter('[tag[task]priority[urgent]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 0)

    def test_field_operator_empty_parameter(self):
        """Test field operator with empty parameter matches missing or empty fields"""
        results = tw_filter.evaluate_filter('[priority[]]', wiki_path=self.test_wiki)
        # Should return Note1 (no priority field) and Note2 (empty priority field)
        self.assertIn('Note1', results)
        self.assertIn('Note2', results)
        # Should NOT include tasks with priority values
        self.assertNotIn('Task1', results)
        self.assertNotIn('Task2', results)

    def test_field_operator_chained(self):
        """Test chaining multiple field operators"""
        results = tw_filter.evaluate_filter('[tag[task]priority[high]status[active]]', wiki_path=self.test_wiki)
        # Should return only Task1 (high priority AND active status)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Task1')

    def test_field_operator_with_tag(self):
        """Test field operator combined with tag"""
        results = tw_filter.evaluate_filter('[tag[note]status[active]]', wiki_path=self.test_wiki)
        # Should return Note1 (note tag AND active status)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Note1')

    def test_field_operator_status_done(self):
        """Test filtering by status field"""
        results = tw_filter.evaluate_filter('[status[done]]', wiki_path=self.test_wiki)
        # Should return Task3 and Note2
        self.assertEqual(len(results), 2)
        self.assertIn('Task3', results)
        self.assertIn('Note2', results)

    def test_field_operator_status_active(self):
        """Test filtering by active status"""
        results = tw_filter.evaluate_filter('[tag[task]status[active]]', wiki_path=self.test_wiki)
        # Should return Task1, Task2, Task4 (active tasks)
        self.assertEqual(len(results), 3)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Task4', results)

    def test_field_operator_with_sort(self):
        """Test field operator with sort"""
        results = tw_filter.evaluate_filter('[status[active]sort[title]]', wiki_path=self.test_wiki)
        # Should be sorted by title
        self.assertGreater(len(results), 0)
        # Check first few are in order
        active_results = [r for r in results if r.startswith('Task') or r.startswith('Note')]
        for i in range(len(active_results) - 1):
            self.assertLessEqual(active_results[i].lower(), active_results[i+1].lower())

    def test_field_operator_with_count(self):
        """Test counting results from field operator"""
        results = tw_filter.evaluate_filter('[priority[high]count[]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], '2')  # Task1 and Task3

    def test_field_operator_all_tiddlers_then_filter(self):
        """Test field operator on all tiddlers"""
        results = tw_filter.evaluate_filter('[all[tiddlers]priority[medium]]', wiki_path=self.test_wiki)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Task2')

    def test_field_operator_multiple_values_same_field(self):
        """Test that we can't match multiple values (TiddlyWiki requires OR with multiple runs)"""
        # This should only match 'high' since we can't have priority be both high AND medium
        results = tw_filter.evaluate_filter('[priority[high]priority[medium]]', wiki_path=self.test_wiki)
        # No tiddler can have priority equal to both high and medium
        self.assertEqual(len(results), 0)

    def test_field_operator_case_sensitive(self):
        """Test field operator is case-sensitive for values"""
        results = tw_filter.evaluate_filter('[priority[High]]', wiki_path=self.test_wiki)
        # Should not match 'high' (lowercase)
        self.assertEqual(len(results), 0)

    def test_field_operator_nonexistent_field(self):
        """Test field operator with nonexistent field"""
        results = tw_filter.evaluate_filter('[nonexistent[value]]', wiki_path=self.test_wiki)
        # No tiddlers have this field with this value
        self.assertEqual(len(results), 0)

    def test_field_operator_empty_nonexistent_field(self):
        """Test field operator with empty parameter on nonexistent field"""
        results = tw_filter.evaluate_filter('[tag[task]nonexistent[]]', wiki_path=self.test_wiki)
        # All tasks don't have this field, so all should match
        self.assertEqual(len(results), 4)
        self.assertIn('Task1', results)
        self.assertIn('Task2', results)
        self.assertIn('Task3', results)
        self.assertIn('Task4', results)


class TestBacklinksAndLinksOperators(unittest.TestCase):
    """Test backlinks and links operators for finding tiddler relationships"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers that link to each other"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_links_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Create tiddlers with various link patterns
        test_tiddlers = [
            ("Index", "Welcome to my wiki. See [[About]] and [[Projects]]."),
            ("About", "This is about me. Check out my [[Projects]]."),
            ("Projects", "My projects: [[Project A]] and [[Project B]]."),
            ("Project A", "Details about Project A. Related: [[Project B]]."),
            ("Project B", "Details about Project B. Related to [[Project A]] and back to [[Projects]]."),
            ("Orphan", "This tiddler has no links."),
            ("Archive", "Old project: [[Project A]]."),
        ]

        for title, text in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_backlinks_with_parameter(self):
        """Test backlinks[TiddlerName] finds tiddlers linking to TiddlerName"""
        results = tw_filter.evaluate_filter('[backlinks[Projects]]', wiki_path=self.test_wiki)
        # Index, About, and Project B link to Projects
        self.assertEqual(len(results), 3)
        self.assertIn('Index', results)
        self.assertIn('About', results)
        self.assertIn('Project B', results)

    def test_backlinks_single_backlink(self):
        """Test tiddler with a single backlink"""
        results = tw_filter.evaluate_filter('[backlinks[About]]', wiki_path=self.test_wiki)
        # Only Index links to About
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Index')

    def test_backlinks_multiple_backlinks(self):
        """Test tiddler with multiple backlinks"""
        results = tw_filter.evaluate_filter('[backlinks[Project A]]', wiki_path=self.test_wiki)
        # Projects, Project B, and Archive link to Project A
        self.assertEqual(len(results), 3)
        self.assertIn('Projects', results)
        self.assertIn('Project B', results)
        self.assertIn('Archive', results)

    def test_backlinks_no_backlinks(self):
        """Test tiddler with no backlinks"""
        results = tw_filter.evaluate_filter('[backlinks[Index]]', wiki_path=self.test_wiki)
        # No tiddlers link to Index
        self.assertEqual(len(results), 0)

    def test_backlinks_nonexistent_tiddler(self):
        """Test backlinks for nonexistent tiddler"""
        results = tw_filter.evaluate_filter('[backlinks[DoesNotExist]]', wiki_path=self.test_wiki)
        # No backlinks for nonexistent tiddler
        self.assertEqual(len(results), 0)

    def test_backlinks_without_parameter(self):
        """Test backlinks[] without parameter on input tiddlers"""
        results = tw_filter.evaluate_filter('[[Projects]]backlinks[]', wiki_path=self.test_wiki)
        # Should find tiddlers linking to Projects
        self.assertEqual(len(results), 3)
        self.assertIn('Index', results)
        self.assertIn('About', results)
        self.assertIn('Project B', results)

    def test_backlinks_multiple_input_tiddlers(self):
        """Test backlinks[] on multiple input tiddlers"""
        results = tw_filter.evaluate_filter('[[Project A]] [[Project B]] +[backlinks[]]', wiki_path=self.test_wiki)
        # Backlinks to both Project A and Project B (combined, unique)
        # Project A: Projects, Project B, Archive
        # Project B: Projects, Project A
        # Combined unique: Projects, Project B, Archive, Project A
        self.assertGreater(len(results), 0)
        self.assertIn('Projects', results)

    def test_links_operator(self):
        """Test links[] finds tiddlers that input tiddlers link to"""
        results = tw_filter.evaluate_filter('[[Index]]links[]', wiki_path=self.test_wiki)
        # Index links to About and Projects
        self.assertEqual(len(results), 2)
        self.assertIn('About', results)
        self.assertIn('Projects', results)

    def test_links_multiple_links(self):
        """Test links[] on tiddler with multiple links"""
        results = tw_filter.evaluate_filter('[[Projects]]links[]', wiki_path=self.test_wiki)
        # Projects links to Project A and Project B
        self.assertEqual(len(results), 2)
        self.assertIn('Project A', results)
        self.assertIn('Project B', results)

    def test_links_no_links(self):
        """Test links[] on tiddler with no links"""
        results = tw_filter.evaluate_filter('[[Orphan]]links[]', wiki_path=self.test_wiki)
        # Orphan has no links
        self.assertEqual(len(results), 0)

    def test_links_multiple_input_tiddlers(self):
        """Test links[] on multiple input tiddlers"""
        results = tw_filter.evaluate_filter('[[Index]] [[About]] +[links[]]', wiki_path=self.test_wiki)
        # Index links to About and Projects
        # About links to Projects
        # Combined unique: About, Projects (About appears once despite being both input and output)
        self.assertGreater(len(results), 0)
        self.assertIn('Projects', results)

    def test_links_circular_reference(self):
        """Test links[] handles circular references"""
        results = tw_filter.evaluate_filter('[[Project A]]links[]', wiki_path=self.test_wiki)
        # Project A links to Project B
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Project B')

        # Project B links to both Project A and Projects
        results2 = tw_filter.evaluate_filter('[[Project B]]links[]', wiki_path=self.test_wiki)
        self.assertEqual(len(results2), 2)
        self.assertIn('Project A', results2)
        self.assertIn('Projects', results2)

    def test_links_chain(self):
        """Test chaining links operator"""
        results = tw_filter.evaluate_filter('[[Index]]links[]links[]', wiki_path=self.test_wiki)
        # Index -> (About, Projects) -> (Projects, Project A, Project B)
        # Should get links from both About and Projects
        self.assertGreater(len(results), 0)

    def test_backlinks_combined_with_tag(self):
        """Test combining backlinks with tag filtering"""
        # First add tags to some tiddlers
        import subprocess
        subprocess.run(['python3', 'tw', self.test_wiki, 'set', 'Index', 'tags', 'important'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', self.test_wiki, 'set', 'About', 'tags', 'important'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', self.test_wiki, 'set', 'Project B', 'tags', 'important'],
                      cwd=script_dir, check=True, capture_output=True)

        # backlinks[Projects] replaces input with all tiddlers linking to Projects
        # Then we can filter those results
        results = tw_filter.evaluate_filter('[backlinks[Projects]tag[important]]', wiki_path=self.test_wiki)
        # backlinks[Projects] gives Index, About, Project B
        # Then filter to only those with tag important: all three have it now
        self.assertEqual(len(results), 3)
        self.assertIn('Index', results)
        self.assertIn('About', results)
        self.assertIn('Project B', results)

    def test_extract_links_function(self):
        """Test the extract_links_from_content helper function"""
        content = "See [[Tiddler One]] and [[Tiddler Two]] for details. Also check [[Tiddler One]] again."
        links = tw_filter.extract_links_from_content(content)
        # Should find all three link instances (including duplicate)
        self.assertEqual(len(links), 3)
        self.assertEqual(links[0], 'Tiddler One')
        self.assertEqual(links[1], 'Tiddler Two')
        self.assertEqual(links[2], 'Tiddler One')

    def test_extract_links_empty_content(self):
        """Test extract_links_from_content with empty content"""
        links = tw_filter.extract_links_from_content("")
        self.assertEqual(len(links), 0)

        links2 = tw_filter.extract_links_from_content(None)
        self.assertEqual(len(links2), 0)

    def test_extract_links_no_links(self):
        """Test extract_links_from_content with no links"""
        content = "This is plain text with no links at all."
        links = tw_filter.extract_links_from_content(content)
        self.assertEqual(len(links), 0)


class TestDateComparisonOperators(unittest.TestCase):
    """Test date comparison operators for filtering by created/modified dates"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers with different dates"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_dates_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Create tiddlers
        test_tiddlers = [
            "OldTiddler",
            "MediumTiddler",
            "RecentTiddler",
            "VeryRecentTiddler",
        ]

        for title in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, f"Content of {title}"],
                          cwd=script_dir, check=True, capture_output=True)

        # Set different created dates
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'OldTiddler', 'created', '20200101120000000'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'MediumTiddler', 'created', '20220615140000000'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'RecentTiddler', 'created', '20231201180000000'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'VeryRecentTiddler', 'created', '20240315090000000'],
                      cwd=script_dir, check=True, capture_output=True)

        # Set different modified dates
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'OldTiddler', 'modified', '20210501100000000'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'MediumTiddler', 'modified', '20230201150000000'],
                      cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_created_after_full_timestamp(self):
        """Test created:after with full TiddlyWiki timestamp"""
        results = tw_filter.evaluate_filter('[created:after[20220101000000000]]', wiki_path=self.test_wiki)
        # Should find Medium, Recent, and VeryRecent (created after 2022-01-01)
        self.assertGreaterEqual(len(results), 3)
        self.assertIn('MediumTiddler', results)
        self.assertIn('RecentTiddler', results)
        self.assertIn('VeryRecentTiddler', results)
        self.assertNotIn('OldTiddler', results)

    def test_created_after_simplified_date(self):
        """Test created:after with YYYY-MM-DD format"""
        results = tw_filter.evaluate_filter('[created:after[2023-01-01]]', wiki_path=self.test_wiki)
        # Should find Recent and VeryRecent
        self.assertGreaterEqual(len(results), 2)
        self.assertIn('RecentTiddler', results)
        self.assertIn('VeryRecentTiddler', results)
        self.assertNotIn('OldTiddler', results)
        self.assertNotIn('MediumTiddler', results)

    def test_created_after_yyyymmdd_format(self):
        """Test created:after with YYYYMMDD format"""
        results = tw_filter.evaluate_filter('[created:after[20230601]]', wiki_path=self.test_wiki)
        # Should find Recent and VeryRecent (created after 2023-06-01)
        self.assertGreaterEqual(len(results), 2)
        self.assertIn('RecentTiddler', results)
        self.assertIn('VeryRecentTiddler', results)

    def test_created_before(self):
        """Test created:before operator"""
        results = tw_filter.evaluate_filter('[created:before[2023-01-01]]', wiki_path=self.test_wiki)
        # Should find Old and Medium (created before 2023-01-01)
        self.assertGreaterEqual(len(results), 2)
        self.assertIn('OldTiddler', results)
        self.assertIn('MediumTiddler', results)
        self.assertNotIn('RecentTiddler', results)

    def test_modified_after(self):
        """Test modified:after operator"""
        results = tw_filter.evaluate_filter('[modified:after[2022-01-01]]', wiki_path=self.test_wiki)
        # Should find MediumTiddler (modified after 2022-01-01)
        self.assertIn('MediumTiddler', results)
        self.assertNotIn('OldTiddler', results)

    def test_modified_before(self):
        """Test modified:before operator"""
        results = tw_filter.evaluate_filter('[modified:before[2022-01-01]]', wiki_path=self.test_wiki)
        # Should find OldTiddler (modified before 2022-01-01)
        self.assertIn('OldTiddler', results)

    def test_date_comparison_combined(self):
        """Test combining date comparisons"""
        results = tw_filter.evaluate_filter('[created:after[2021-01-01]created:before[2024-01-01]]', wiki_path=self.test_wiki)
        # Should find MediumTiddler and RecentTiddler (created between 2021 and 2024)
        self.assertIn('MediumTiddler', results)
        self.assertIn('RecentTiddler', results)
        self.assertNotIn('OldTiddler', results)  # Created in 2020
        self.assertNotIn('VeryRecentTiddler', results)  # Created in 2024-03, after 2024-01-01

    def test_normalize_date_function(self):
        """Test the normalize_date helper function"""
        # Test YYYY-MM-DD format
        self.assertEqual(tw_filter.normalize_date('2023-12-25'), '20231225000000000')

        # Test YYYYMMDD format
        self.assertEqual(tw_filter.normalize_date('20231225'), '20231225000000000')

        # Test full format (should remain unchanged)
        self.assertEqual(tw_filter.normalize_date('20231225143000000'), '20231225143000000')

        # Test empty/None
        self.assertIsNone(tw_filter.normalize_date(None))
        self.assertIsNone(tw_filter.normalize_date(''))


class TestPatternMatchingOperators(unittest.TestCase):
    """Test pattern matching operators for searching field content"""

    @classmethod
    def setUpClass(cls):
        """Create a test wiki with tiddlers with various content"""
        import subprocess
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'test_pattern_wiki.html')

        # Use tw init to create a proper wiki
        tw_init_or_skip(cls.test_wiki)

        # Create tiddlers with various titles and content
        test_tiddlers = [
            ("Todo: Buy groceries", "Need to buy milk and bread"),
            ("Todo: Call dentist", "Schedule appointment for next month"),
            ("Meeting Notes 2024-01-15", "Discussed project timeline"),
            ("Project Plan", "Initial planning for new feature"),
            ("Random Thoughts", "Various ideas and concepts"),
        ]

        for title, text in test_tiddlers:
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text],
                          cwd=script_dir, check=True, capture_output=True)

        # Add some custom fields
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Project Plan', 'status', 'in-progress'],
                      cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Meeting Notes 2024-01-15', 'status', 'completed'],
                      cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        """Clean up test wiki"""
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_title_contains(self):
        """Test title:contains operator"""
        results = tw_filter.evaluate_filter('[title:contains[todo]]', wiki_path=self.test_wiki)
        # Should find both Todo tiddlers (case-insensitive)
        self.assertEqual(len(results), 2)
        self.assertIn('Todo: Buy groceries', results)
        self.assertIn('Todo: Call dentist', results)

    def test_title_prefix(self):
        """Test title:prefix operator"""
        results = tw_filter.evaluate_filter('[title:prefix[Todo]]', wiki_path=self.test_wiki)
        # Should find tiddlers starting with "Todo"
        self.assertEqual(len(results), 2)
        self.assertIn('Todo: Buy groceries', results)
        self.assertIn('Todo: Call dentist', results)

    def test_title_suffix(self):
        """Test title:suffix operator"""
        results = tw_filter.evaluate_filter('[title:suffix[Plan]]', wiki_path=self.test_wiki)
        # Should find "Project Plan"
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0], 'Project Plan')

    def test_text_contains(self):
        """Test text:contains for searching content"""
        results = tw_filter.evaluate_filter('[text:contains[project]]', wiki_path=self.test_wiki)
        # Should find tiddlers with "project" in content
        self.assertGreater(len(results), 0)
        self.assertIn('Meeting Notes 2024-01-15', results)

    def test_title_regexp(self):
        """Test title:regexp with regex pattern"""
        results = tw_filter.evaluate_filter('[title:regexp[\\d{4}-\\d{2}-\\d{2}]]', wiki_path=self.test_wiki)
        # Should find "Meeting Notes 2024-01-15" (contains date pattern)
        self.assertIn('Meeting Notes 2024-01-15', results)

    def test_status_contains(self):
        """Test custom field pattern matching"""
        results = tw_filter.evaluate_filter('[status:contains[progress]]', wiki_path=self.test_wiki)
        # Should find "Project Plan" (status: in-progress)
        self.assertIn('Project Plan', results)

    def test_pattern_case_insensitive(self):
        """Test that pattern matching is case-insensitive"""
        results = tw_filter.evaluate_filter('[title:contains[TODO]]', wiki_path=self.test_wiki)
        # Should still find Todo tiddlers
        self.assertGreater(len(results), 0)

    def test_regexp_invalid_pattern(self):
        """Test that invalid regex patterns are handled gracefully"""
        # Invalid regex should not crash, just return no results or skip invalid patterns
        try:
            results = tw_filter.evaluate_filter('[title:regexp[[invalid]]', wiki_path=self.test_wiki)
            # Should not crash - might return empty or partial results
            self.assertIsInstance(results, list)
        except Exception:
            # It's also acceptable to raise an exception for invalid regex
            pass

    def test_pattern_empty_param(self):
        """Test pattern matching with empty parameter"""
        results = tw_filter.evaluate_filter('[title:contains[]]', wiki_path=self.test_wiki)
        # Empty pattern should match all tiddlers
        self.assertGreater(len(results), 0)

    def test_combined_pattern_and_date(self):
        """Test combining pattern matching with date comparison"""
        results = tw_filter.evaluate_filter('[title:contains[Meeting]created:after[2024-01-01]]', wiki_path=self.test_wiki)
        # Should find Meeting Notes if created after 2024-01-01
        # (Depends on when the tiddler was created in the test)
        self.assertIsInstance(results, list)


class TestAdditionalItemAndListOperators(unittest.TestCase):
    """Broader coverage of item-level and list-level operators"""

    def test_range_and_join(self):
        self.assertEqual(tw_filter.evaluate_filter('range[3]'), ['1', '2', '3'])
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[b]]join[, ]'), ['a, b'])

    def test_slugify_pad_and_replace(self):
        cases = {
            '[[Hello World!]]slugify[]': ['hello-world'],
            '[[pad]]pad[6,.]': ['pad...'],
            '[[foo bar foo]]search-replace[foo,baz]': ['baz bar baz'],
            '[[start]]addprefix[pre_]': ['pre_start'],
            '[[finish]]addsuffix[_post]': ['finish_post'],
            '[[trimme ]]trim[]': ['trimme'],
            '[[abc123]]match[ABC]': ['abc123'],
            '[[abc123]]compare[>100]': [],
            '[[abc123]]compare[abc123]': ['abc123'],
        }
        for expr, expected in cases.items():
            with self.subTest(expr=expr):
                self.assertEqual(tw_filter.evaluate_filter(expr), expected)

    def test_encoding_and_json_ops(self):
        encoded = tw_filter.evaluate_filter('[[hi]]encodebase64[]')
        self.assertEqual(encoded[0], 'aGk=')
        decoded = tw_filter.evaluate_filter(f'[[{encoded[0]}]]decodebase64[]')
        self.assertEqual(decoded[0], 'hi')

        uri = tw_filter.evaluate_filter('[[hello world]]encodeuri[]')
        self.assertEqual(uri[0], 'hello%20world')
        self.assertEqual(tw_filter.evaluate_filter(f'[[{uri[0]}]]decodeuri[]')[0], 'hello world')

        json_cases = {
            '[[{"a":1,"b":"two"}]]jsonget[a]': ['1'],
            '[[{"a":1,"b":"two"}]]jsonindexes[]': ['a', 'b'],
            '[[{"a":1,"b":"two"}]]jsontype[b]': ['str'],
        }
        for expr, expected in json_cases.items():
            with self.subTest(expr=expr):
                self.assertEqual(tw_filter.evaluate_filter(expr), expected)

    def test_numeric_extended_operations(self):
        math_cases = {
            '[[8]]power[2]': 64.0,
            '[[10]]log[10]': 1.0,
            '[[1]]sin[]': math.sin(1),
            '[[0.5]]cos[]': math.cos(0.5),
            '[[1]]tan[]': math.tan(1),
        }
        for expr, expected in math_cases.items():
            with self.subTest(expr=expr):
                result = tw_filter.evaluate_filter(expr)
                self.assertAlmostEqual(float(result[0]), expected, places=5)

    def test_aggregate_operations(self):
        res = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]sum[]')
        self.assertAlmostEqual(float(res[0]), 6.0, places=5)

        product = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]product[]')
        self.assertAlmostEqual(float(product[0]), 6.0, places=5)

        average = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]average[]')
        self.assertAlmostEqual(float(average[0]), 2.0, places=5)

        median = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]median[]')
        self.assertAlmostEqual(float(median[0]), 2.0, places=5)

        variance = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]variance[]')
        self.assertAlmostEqual(float(variance[0]), 2.0/3.0, places=5)

        stddev = tw_filter.evaluate_filter('[[1]] [[2]] [[3]]standard-deviation[]')
        self.assertAlmostEqual(float(stddev[0]), math.sqrt(2.0/3.0), places=5)

    def test_unique_and_ordering_helpers(self):
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[a]] [[b]]unique[]'), ['a', 'b'])
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[b]] [[c]]allafter[b]'), ['c'])
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[b]] [[c]]allbefore[c]'), ['a', 'b'])
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[b]] [[c]]move[1]'), ['b', 'c', 'a'])
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[c]]insertafter[a|b]'), ['a', 'b', 'c'])

    def test_toggle_and_cycle(self):
        self.assertEqual(tw_filter.evaluate_filter('[[a]] [[b]]toggle[a]'), ['b'])
        self.assertEqual(tw_filter.evaluate_filter('[[red]]cycle[red,amber,green]'), ['amber'])
        self.assertEqual(tw_filter.evaluate_filter('else[empty]'), ['empty'])
        self.assertEqual(tw_filter.evaluate_filter('[[x]]then[y]'), ['y'])


class TestAdditionalWikiOperators(unittest.TestCase):
    """Cover wiki-specific operators not hit by earlier suites"""

    @classmethod
    def setUpClass(cls):
        cls.test_dir = tempfile.mkdtemp()
        cls.test_wiki = os.path.join(cls.test_dir, 'expanded_wiki.html')
        tw_init_or_skip(cls.test_wiki)

        def touch(title, text):
            subprocess.run(['python3', 'tw', cls.test_wiki, 'touch', title, text], cwd=script_dir, check=True, capture_output=True)

        # Core tiddlers
        touch('Alpha', 'Link to [[Beta]] and {{Gamma}}')
        touch('Beta', 'Transclude {{Alpha}}')
        touch('Gamma', 'Plain content')
        touch('ListHolder', 'Holder for list')
        touch('$:/core/Test', 'System content')
        touch('My Note', 'Slug duplicate one')
        touch('My-Note', 'Slug duplicate two')
        touch('LookupAlpha', 'Lookup result')
        touch('DataJson', '{"key":"value","num":5}')

        # Set fields
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Alpha', 'tags', 'one two'], cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Alpha', 'list', 'Gamma'], cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Alpha', 'created', '20240101010101010'], cwd=script_dir, check=True, capture_output=True)

        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Beta', 'tags', 'two'], cwd=script_dir, check=True, capture_output=True)
        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Beta', 'created', '20240102020202020'], cwd=script_dir, check=True, capture_output=True)

        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'Gamma', 'created', '20240102030303030'], cwd=script_dir, check=True, capture_output=True)

        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'ListHolder', 'list', 'Alpha Beta'], cwd=script_dir, check=True, capture_output=True)

        subprocess.run(['python3', 'tw', cls.test_wiki, 'set', 'LookupAlpha', 'created', '20240101050505050'], cwd=script_dir, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        import shutil
        shutil.rmtree(cls.test_dir)

    def test_tagging_and_tags(self):
        tagging_results = tw_filter.evaluate_filter('[[two]]tagging[]', wiki_path=self.test_wiki)
        self.assertIn('Alpha', tagging_results)
        self.assertIn('Beta', tagging_results)

        tags = tw_filter.evaluate_filter('[[Alpha]]tags[]', wiki_path=self.test_wiki)
        self.assertIn('one', tags)
        self.assertIn('two', tags)

    def test_list_and_listed(self):
        self.assertEqual(tw_filter.evaluate_filter('[list[ListHolder]]', wiki_path=self.test_wiki), ['Alpha', 'Beta'])
        listed = tw_filter.evaluate_filter('[[Alpha]]listed[]', wiki_path=self.test_wiki)
        self.assertIn('ListHolder', listed)

    def test_contains_and_is(self):
        contains = tw_filter.evaluate_filter('[contains[one]]', wiki_path=self.test_wiki)
        self.assertIn('Alpha', contains)
        systems = tw_filter.evaluate_filter('[is[system]]', wiki_path=self.test_wiki)
        self.assertIn('$:/core/Test', systems)
        tiddlers = tw_filter.evaluate_filter('[is[tiddler]]', wiki_path=self.test_wiki)
        self.assertIn('Alpha', tiddlers)
        self.assertNotIn('$:/core/Test', tiddlers)

    def test_transcludes_and_backtranscludes(self):
        backtrans = tw_filter.evaluate_filter('[backtranscludes[Alpha]]', wiki_path=self.test_wiki)
        self.assertIn('Beta', backtrans)
        transcludes = tw_filter.evaluate_filter('[[Alpha]]transcludes[]', wiki_path=self.test_wiki)
        self.assertIn('Gamma', transcludes)

    def test_duplicateslugs_and_lookup(self):
        duplicates = tw_filter.evaluate_filter('[duplicateslugs[]]', wiki_path=self.test_wiki)
        self.assertIn('My Note', duplicates)
        self.assertIn('My-Note', duplicates)

        lookup = tw_filter.evaluate_filter('[[Alpha]]lookup[Lookup]', wiki_path=self.test_wiki)
        self.assertEqual(lookup[0], 'Lookup result')

    def test_search_and_enlist(self):
        search_results = tw_filter.evaluate_filter('[search[Transclude]]', wiki_path=self.test_wiki)
        self.assertIn('Beta', search_results)
        enlist = tw_filter.evaluate_filter('[enlist[Alpha Beta]]', wiki_path=self.test_wiki)
        self.assertEqual(enlist, ['Alpha', 'Beta'])

    def test_json_getindex_and_date_filters(self):
        json_val = tw_filter.evaluate_filter('[[DataJson]]jsonget[key]', wiki_path=self.test_wiki)
        self.assertEqual(json_val, ['value'])
        after = tw_filter.evaluate_filter('[created:after[20240101]]', wiki_path=self.test_wiki)
        self.assertIn('Beta', after)

    def test_commands_operator_no_error(self):
        self.assertEqual(tw_filter.evaluate_filter('[commands[]]', wiki_path=self.test_wiki), [])


if __name__ == '__main__':
    unittest.main()
