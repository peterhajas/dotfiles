#!/usr/bin/env python3
"""
Test suite for the tw (TiddlyWiki) command-line tool.

Run tests with:
    python3 test_tw.py                    # Run all tests
    python3 test_tw.py -v                 # Run with verbose output
    python3 test_tw.py TestClassName      # Run specific test class
    python3 test_tw.py TestClassName.test_method  # Run specific test

This test suite uses Python's built-in unittest framework (no dependencies).
"""

import unittest
import json
import os
import sys
import tempfile
import shutil

# Import the tw script
# Since tw has no .py extension, we need to import it specially
import importlib.util
import importlib.machinery

script_dir = os.path.dirname(os.path.abspath(__file__))
tw_path = os.path.join(script_dir, "tw")

# Use SourceFileLoader directly since the file doesn't have .py extension
loader = importlib.machinery.SourceFileLoader("tw", tw_path)
tw_module = loader.load_module()

class TestTiddlyWikiScript(unittest.TestCase):

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000"},
            {"title": "TestTiddler2", "text": "Content with <angle> brackets", "created": "20230102000000000"},
            {"title": "TestTiddler3", "text": "Content with \"quotes\" and special chars", "created": "20230103000000000"},
        ]

        # Create the HTML file
        tiddlers_json = json.dumps(self.test_tiddlers, ensure_ascii=False, separators=(',', ':'))
        # Format like TiddlyWiki
        tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in self.test_tiddlers]
        formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
        formatted_json = formatted_json.replace('<', '\\u003C')

        html_content = f'''<!DOCTYPE html>
<html>
<head><title>Test Wiki</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>
</body>
</html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(html_content)

    def tearDown(self):
        """Clean up temporary files after each test"""
        shutil.rmtree(self.test_dir)

    def test_extract_tiddler_stores(self):
        """Test extracting tiddler stores from HTML"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        self.assertEqual(len(stores), 1)
        self.assertEqual(len(stores[0]['tiddlers']), 3)

    def test_load_all_tiddlers(self):
        """Test loading all tiddlers from a wiki"""
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 3)

        titles = [t['title'] for t in tiddlers]
        self.assertIn("TestTiddler1", titles)
        self.assertIn("TestTiddler2", titles)
        self.assertIn("TestTiddler3", titles)

    def test_remove_tiddler(self):
        """Test removing a tiddler"""
        # Remove TestTiddler2
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler2")

        # Verify it's gone
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        titles = [t['title'] for t in tiddlers]
        self.assertNotIn("TestTiddler2", titles)
        self.assertIn("TestTiddler1", titles)
        self.assertIn("TestTiddler3", titles)

    def test_remove_nonexistent_tiddler(self):
        """Test that removing a non-existent tiddler exits with error"""
        with self.assertRaises(SystemExit):
            tw_module.remove_tiddler(self.test_wiki, "NonExistentTiddler")

    def test_formatting_after_removal(self):
        """Test that JSON formatting is preserved after removal"""
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler1")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract the JSON
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # Verify formatting
        self.assertTrue(json_str.startswith('[\n{'))  # Newline after [
        self.assertIn('},\n{', json_str)  # Newlines between tiddlers
        self.assertIn('\\u003C', json_str)  # < is escaped

        # Verify it's valid JSON
        tiddlers = json.loads(json_str, strict=False)
        self.assertEqual(len(tiddlers), 2)

    def test_unicode_preservation(self):
        """Test that Unicode characters are preserved (not escaped)"""
        # Add a tiddler with Unicode
        unicode_tiddler = {"title": "UnicodeTest", "text": "Curly quotes: \u201ctest\u201d"}

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        stores[0]['tiddlers'].append(unicode_tiddler)

        # Save it back
        import json
        tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in stores[0]['tiddlers']]
        formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
        formatted_json = formatted_json.replace('<', '\\u003C')
        new_store = f'<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>'

        new_content = content[:stores[0]['start']] + new_store + content[stores[0]['end']:]
        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(new_content)

        # Now remove a different tiddler
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler1")

        # Verify Unicode is still there (not escaped as \u201c)
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn('\u201ctest\u201d', content)  # Literal curly quotes
        self.assertNotIn('\\u201c', content)  # Not escaped

    def test_angle_bracket_escaping(self):
        """Test that < is escaped but > is not"""
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler1")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find TestTiddler2 which has <angle> brackets
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # < should be escaped as \u003C
        self.assertIn('\\u003C', json_str)
        # > should be literal
        self.assertIn('>', json_str)
        # > should NOT be escaped
        self.assertNotIn('\\u003E', json_str)

    def test_wiki_is_readable_after_removal(self):
        """Test that the wiki can be read back after removal"""
        # Remove a tiddler
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler2")

        # Try to load it again (this would fail if JSON is malformed)
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        # Verify data integrity
        tiddler1 = next(t for t in tiddlers if t['title'] == 'TestTiddler1')
        self.assertEqual(tiddler1['text'], 'Content 1')

        tiddler3 = next(t for t in tiddlers if t['title'] == 'TestTiddler3')
        self.assertEqual(tiddler3['text'], 'Content with "quotes" and special chars')

class TestTiddlerStoreExtraction(unittest.TestCase):
    """Test edge cases in tiddler store extraction"""

    def test_multiple_stores(self):
        """Test handling multiple tiddler stores in one file"""
        html = '''<html>
<script class="tiddlywiki-tiddler-store" type="application/json">[
{"title":"T1","text":"Content 1"}
]</script>
<script class="tiddlywiki-tiddler-store" type="application/json">[
{"title":"T2","text":"Content 2"}
]</script>
</html>'''

        stores = tw_module.extract_tiddler_stores(html)
        self.assertEqual(len(stores), 2)
        self.assertEqual(stores[0]['tiddlers'][0]['title'], 'T1')
        self.assertEqual(stores[1]['tiddlers'][0]['title'], 'T2')

    def test_no_stores(self):
        """Test handling HTML with no tiddler stores"""
        html = '<html><body>No stores here</body></html>'
        stores = tw_module.extract_tiddler_stores(html)
        self.assertEqual(len(stores), 0)

class TestMultipleStoreRemoval(unittest.TestCase):
    """Test removing tiddlers when there are multiple stores"""

    def setUp(self):
        """Create a test wiki with multiple tiddler stores"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'multi_store_wiki.html')

        # Create tiddlers for two different stores
        store1_tiddlers = [
            {"title": "Store1Tiddler1", "text": "Content from store 1", "store": "1"},
            {"title": "Store1Tiddler2", "text": "More content from store 1", "store": "1"},
            {"title": "DuplicateName", "text": "This is in store 1", "store": "1"},
        ]

        store2_tiddlers = [
            {"title": "Store2Tiddler1", "text": "Content from store 2", "store": "2"},
            {"title": "Store2Tiddler2", "text": "More content from store 2", "store": "2"},
            {"title": "DuplicateName", "text": "This is in store 2 (should also be removed)", "store": "2"},
        ]

        # Format each store
        def format_store(tiddlers):
            tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in tiddlers]
            formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
            formatted_json = formatted_json.replace('<', '\\u003C')
            return formatted_json

        store1_json = format_store(store1_tiddlers)
        store2_json = format_store(store2_tiddlers)

        # Create HTML with two stores
        html_content = f'''<!DOCTYPE html>
<html>
<head><title>Multi Store Test Wiki</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{store1_json}</script>
<div>Some content between stores</div>
<script class="tiddlywiki-tiddler-store" type="application/json">{store2_json}</script>
</body>
</html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(html_content)

    def tearDown(self):
        """Clean up temporary files"""
        shutil.rmtree(self.test_dir)

    def test_remove_from_first_store_only(self):
        """Test removing a tiddler that exists only in the first store"""
        tw_module.remove_tiddler(self.test_wiki, "Store1Tiddler1")

        # Verify it's removed
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        self.assertNotIn("Store1Tiddler1", titles)
        # Other tiddlers from store 1 should still exist
        self.assertIn("Store1Tiddler2", titles)
        # Store 2 tiddlers should be untouched
        self.assertIn("Store2Tiddler1", titles)
        self.assertIn("Store2Tiddler2", titles)

        # Total should be 5 (started with 6, removed 1)
        self.assertEqual(len(tiddlers), 5)

    def test_remove_from_second_store_only(self):
        """Test removing a tiddler that exists only in the second store"""
        tw_module.remove_tiddler(self.test_wiki, "Store2Tiddler1")

        # Verify it's removed
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        self.assertNotIn("Store2Tiddler1", titles)
        # Other store 2 tiddlers should still exist
        self.assertIn("Store2Tiddler2", titles)
        # Store 1 tiddlers should be untouched
        self.assertIn("Store1Tiddler1", titles)
        self.assertIn("Store1Tiddler2", titles)

        # Total should be 5
        self.assertEqual(len(tiddlers), 5)

    def test_remove_duplicate_tiddler_from_all_stores(self):
        """Test removing a tiddler that exists in multiple stores (should remove from all)"""
        tw_module.remove_tiddler(self.test_wiki, "DuplicateName")

        # Verify it's removed from both stores
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        # Should not exist at all
        self.assertNotIn("DuplicateName", titles)

        # Other tiddlers should still exist
        self.assertIn("Store1Tiddler1", titles)
        self.assertIn("Store1Tiddler2", titles)
        self.assertIn("Store2Tiddler1", titles)
        self.assertIn("Store2Tiddler2", titles)

        # Total should be 4 (started with 6, removed 2)
        self.assertEqual(len(tiddlers), 4)

    def test_both_stores_remain_valid_after_removal(self):
        """Test that both stores remain valid JSON after removal"""
        tw_module.remove_tiddler(self.test_wiki, "Store1Tiddler2")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract both stores
        stores = tw_module.extract_tiddler_stores(content)
        self.assertEqual(len(stores), 2)

        # Verify both stores have valid JSON
        self.assertEqual(len(stores[0]['tiddlers']), 2)  # Lost 1 from store 1
        self.assertEqual(len(stores[1]['tiddlers']), 3)  # Store 2 unchanged

        # Verify formatting is correct in both stores
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start1 = content.find(pattern)
        json_start1 = content.find('[', start1)
        end1 = content.find('</script>', json_start1)
        json1 = content[json_start1:end1]

        # Find second store
        start2 = content.find(pattern, end1)
        json_start2 = content.find('[', start2)
        end2 = content.find('</script>', json_start2)
        json2 = content[json_start2:end2]

        # Both should have proper formatting
        self.assertTrue(json1.startswith('[\n{'))
        self.assertTrue(json2.startswith('[\n{'))
        self.assertIn('},\n{', json1)
        self.assertIn('},\n{', json2)

    def test_remove_all_from_one_store_leaves_empty_array(self):
        """Test that removing all tiddlers from one store leaves an empty array"""
        # Remove all from store 1
        tw_module.remove_tiddler(self.test_wiki, "Store1Tiddler1")
        tw_module.remove_tiddler(self.test_wiki, "Store1Tiddler2")
        tw_module.remove_tiddler(self.test_wiki, "DuplicateName")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        self.assertEqual(len(stores), 2)

        # First store should be empty
        self.assertEqual(len(stores[0]['tiddlers']), 0)
        # Second store should have 2 left (lost DuplicateName)
        self.assertEqual(len(stores[1]['tiddlers']), 2)

        # Total tiddlers should be 2
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

if __name__ == '__main__':
    unittest.main()
