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

# Add current directory to path so we can import tw_filter
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

import tw_filter


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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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
        subprocess.run(['python3', 'tw', 'init', cls.test_wiki],
                      cwd=script_dir, check=True, capture_output=True)

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


if __name__ == '__main__':
    unittest.main()
