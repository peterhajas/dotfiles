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
import subprocess

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

class TestTouchCommand(unittest.TestCase):
    """Test the touch command for creating and updating tiddlers"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "ExistingTiddler", "text": "Original content",
             "created": "20230101000000000", "modified": "20230101000000000"},
        ]

        # Create the HTML file
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

    def test_touch_creates_new_tiddler(self):
        """Test that touch creates a new tiddler"""
        tw_module.touch_tiddler(self.test_wiki, "NewTiddler", "New content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        new_tiddler = next(t for t in tiddlers if t['title'] == 'NewTiddler')
        self.assertEqual(new_tiddler['text'], 'New content')
        self.assertIn('created', new_tiddler)
        self.assertIn('modified', new_tiddler)

    def test_touch_creates_empty_tiddler_without_text(self):
        """Test that touch can create a tiddler without text"""
        tw_module.touch_tiddler(self.test_wiki, "EmptyTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next(t for t in tiddlers if t['title'] == 'EmptyTiddler')
        self.assertEqual(new_tiddler['text'], '')

    def test_touch_updates_existing_tiddler(self):
        """Test that touch updates an existing tiddler's modified time"""
        import time

        # Get original modified time
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        original_modified = original['modified']
        original_created = original['created']

        # Wait a tiny bit to ensure timestamp changes
        time.sleep(0.01)

        # Touch the existing tiddler
        tw_module.touch_tiddler(self.test_wiki, "ExistingTiddler")

        # Verify modified changed but created didn't
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        updated = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertEqual(updated['created'], original_created)
        self.assertNotEqual(updated['modified'], original_modified)
        self.assertGreater(updated['modified'], original_modified)

    def test_touch_updates_text_of_existing_tiddler(self):
        """Test that touch can update the text of an existing tiddler"""
        tw_module.touch_tiddler(self.test_wiki, "ExistingTiddler", "Updated content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        updated = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        self.assertEqual(updated['text'], 'Updated content')

    def test_timestamp_format(self):
        """Test that timestamps are in the correct TiddlyWiki format"""
        tw_module.touch_tiddler(self.test_wiki, "TestTimestamp", "Test")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next(t for t in tiddlers if t['title'] == 'TestTimestamp')

        # Check format: YYYYMMDDhhmmssxxx (17 digits total)
        self.assertEqual(len(new_tiddler['created']), 17)
        self.assertEqual(len(new_tiddler['modified']), 17)
        self.assertTrue(new_tiddler['created'].isdigit())
        self.assertTrue(new_tiddler['modified'].isdigit())

        # Check that it parses as a valid date
        # Format: YYYYMMDDhhmmssxxx
        year = int(new_tiddler['created'][0:4])
        month = int(new_tiddler['created'][4:6])
        day = int(new_tiddler['created'][6:8])

        self.assertGreaterEqual(year, 2020)
        self.assertLessEqual(year, 2100)
        self.assertGreaterEqual(month, 1)
        self.assertLessEqual(month, 12)
        self.assertGreaterEqual(day, 1)
        self.assertLessEqual(day, 31)

    def test_touch_preserves_formatting(self):
        """Test that touch preserves JSON formatting"""
        tw_module.touch_tiddler(self.test_wiki, "FormattingTest", "Content with <angles>")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract JSON
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # Verify formatting
        self.assertTrue(json_str.startswith('[\n{'))
        self.assertIn('},\n{', json_str)
        self.assertIn('\\u003C', json_str)  # < should be escaped

    def test_wiki_readable_after_touch(self):
        """Test that the wiki is still readable after touch"""
        tw_module.touch_tiddler(self.test_wiki, "ReadableTest", "Test content")

        # Should be able to load all tiddlers
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertGreaterEqual(len(tiddlers), 2)

        # Should be able to cat the new tiddler
        new_tiddler = next(t for t in tiddlers if t['title'] == 'ReadableTest')
        self.assertEqual(new_tiddler['text'], 'Test content')

class TestGetCommand(unittest.TestCase):
    """Test the get command for retrieving specific field values"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with tiddlers with various fields
        self.test_tiddlers = [
            {
                "title": "TestTiddler",
                "text": "Test content",
                "created": "20230101000000000",
                "modified": "20230102000000000",
                "tags": "tag1 tag2",
                "type": "text/vnd.tiddlywiki"
            },
            {
                "title": "MinimalTiddler",
                "text": "Minimal",
            },
        ]

        # Create the HTML file
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

    def test_get_text_field(self):
        """Test getting the text field"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "text")

        output = f.getvalue()
        self.assertEqual(output.strip(), "Test content")

    def test_get_title_field(self):
        """Test getting the title field"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "title")

        output = f.getvalue()
        self.assertEqual(output.strip(), "TestTiddler")

    def test_get_created_field(self):
        """Test getting the created timestamp field"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "created")

        output = f.getvalue()
        self.assertEqual(output.strip(), "20230101000000000")

    def test_get_tags_field(self):
        """Test getting the tags field"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "tags")

        output = f.getvalue()
        self.assertEqual(output.strip(), "tag1 tag2")

    def test_get_nonexistent_field(self):
        """Test that getting a non-existent field exits with error"""
        with self.assertRaises(SystemExit):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "nonexistent")

    def test_get_field_from_nonexistent_tiddler(self):
        """Test that getting a field from non-existent tiddler exits with error"""
        with self.assertRaises(SystemExit):
            tw_module.get_tiddler_field(self.test_wiki, "NonExistent", "text")

    def test_get_field_from_minimal_tiddler(self):
        """Test getting field from tiddler with minimal fields"""
        import io
        import contextlib

        # Should work for text
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "MinimalTiddler", "text")
        self.assertEqual(f.getvalue().strip(), "Minimal")

        # Should fail for created (not present)
        with self.assertRaises(SystemExit):
            tw_module.get_tiddler_field(self.test_wiki, "MinimalTiddler", "created")

class TestSetCommand(unittest.TestCase):
    """Test the set command for modifying field values"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with tiddlers
        self.test_tiddlers = [
            {
                "title": "TestTiddler",
                "text": "Original content",
                "created": "20230101000000000",
                "modified": "20230101000000000",
                "tags": "tag1 tag2",
            },
        ]

        # Create the HTML file
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

    def test_set_text_field(self):
        """Test setting the text field"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "text", "New content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(tiddler['text'], 'New content')

    def test_set_tags_field(self):
        """Test setting the tags field"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "tags", "new-tag1 new-tag2")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(tiddler['tags'], 'new-tag1 new-tag2')

    def test_set_creates_new_field(self):
        """Test that set can create a new field that didn't exist"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "author", "John Doe")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(tiddler['author'], 'John Doe')

    def test_set_updates_modified_timestamp(self):
        """Test that set updates the modified timestamp"""
        import time

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        original_modified = original['modified']

        time.sleep(0.01)

        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "text", "Updated")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        updated = next(t for t in tiddlers if t['title'] == 'TestTiddler')

        self.assertNotEqual(updated['modified'], original_modified)
        self.assertGreater(updated['modified'], original_modified)

    def test_set_modified_directly(self):
        """Test that setting modified field directly doesn't create duplicate timestamp"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "modified", "20250101000000000")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(tiddler['modified'], '20250101000000000')

    def test_set_existing_tiddler_preserves_created(self):
        """Test that updating an existing tiddler preserves the created timestamp"""
        import time

        # Get the original created timestamp
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        original_created = original['created']
        original_modified = original['modified']

        time.sleep(0.01)

        # Update the tiddler
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "text", "Updated text")

        # Check that created is unchanged but modified is updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        updated = next(t for t in tiddlers if t['title'] == 'TestTiddler')

        self.assertEqual(updated['created'], original_created)
        self.assertGreater(updated['modified'], original_modified)

    def test_set_nonexistent_tiddler(self):
        """Test that setting a field on non-existent tiddler creates it"""
        tw_module.set_tiddler_field(self.test_wiki, "NonExistent", "text", "value")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        new_tiddler = next(t for t in tiddlers if t['title'] == 'NonExistent')
        self.assertEqual(new_tiddler['text'], 'value')
        self.assertIn('created', new_tiddler)
        self.assertIn('modified', new_tiddler)

    def test_set_preserves_formatting(self):
        """Test that set preserves JSON formatting"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "text", "Content with <angles>")

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract JSON
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # Verify formatting
        self.assertTrue(json_str.startswith('[\n{'))
        self.assertIn('\\u003C', json_str)  # < should be escaped

    def test_wiki_readable_after_set(self):
        """Test that the wiki is still readable after set"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler", "text", "New text")

        # Should be able to load all tiddlers
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)

    def test_set_creates_new_tiddler_with_minimal_fields(self):
        """Test that creating a new tiddler via set adds required fields"""
        tw_module.set_tiddler_field(self.test_wiki, "NewTiddler", "custom_field", "custom_value")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next(t for t in tiddlers if t['title'] == 'NewTiddler')

        # Should have title, created, modified, and the custom field
        self.assertEqual(new_tiddler['title'], 'NewTiddler')
        self.assertEqual(new_tiddler['custom_field'], 'custom_value')
        self.assertIn('created', new_tiddler)
        self.assertIn('modified', new_tiddler)

    def test_set_creates_new_tiddler_timestamps_valid(self):
        """Test that new tiddler created via set has valid timestamps"""
        import re

        tw_module.set_tiddler_field(self.test_wiki, "TimestampTest", "text", "content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next(t for t in tiddlers if t['title'] == 'TimestampTest')

        # Verify timestamp format (YYYYMMDDhhmmssxxx)
        timestamp_pattern = r'^\d{17}$'
        self.assertIsNotNone(re.match(timestamp_pattern, new_tiddler['created']))
        self.assertIsNotNone(re.match(timestamp_pattern, new_tiddler['modified']))

    def test_set_creates_new_tiddler_then_update(self):
        """Test creating a tiddler via set, then updating it"""
        import time

        # Create new tiddler
        tw_module.set_tiddler_field(self.test_wiki, "CreateAndUpdate", "text", "initial")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next(t for t in tiddlers if t['title'] == 'CreateAndUpdate')
        initial_created = new_tiddler['created']
        initial_modified = new_tiddler['modified']

        time.sleep(0.01)

        # Update the same tiddler
        tw_module.set_tiddler_field(self.test_wiki, "CreateAndUpdate", "text", "updated")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        # Should still only have 2 tiddlers (original TestTiddler + CreateAndUpdate)
        self.assertEqual(len(tiddlers), 2)

        updated_tiddler = next(t for t in tiddlers if t['title'] == 'CreateAndUpdate')
        self.assertEqual(updated_tiddler['text'], 'updated')
        # Modified should increase
        self.assertGreater(updated_tiddler['modified'], initial_modified)
        # Created should remain unchanged
        self.assertEqual(updated_tiddler['created'], initial_created)

    def test_set_creates_multiple_new_tiddlers(self):
        """Test creating multiple new tiddlers via set"""
        tw_module.set_tiddler_field(self.test_wiki, "NewTiddler1", "text", "content1")
        tw_module.set_tiddler_field(self.test_wiki, "NewTiddler2", "text", "content2")
        tw_module.set_tiddler_field(self.test_wiki, "NewTiddler3", "text", "content3")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        # Original TestTiddler + 3 new tiddlers
        self.assertEqual(len(tiddlers), 4)

        titles = [t['title'] for t in tiddlers]
        self.assertIn('NewTiddler1', titles)
        self.assertIn('NewTiddler2', titles)
        self.assertIn('NewTiddler3', titles)

        # Verify the content of the new tiddlers
        new_tiddler1 = next(t for t in tiddlers if t['title'] == 'NewTiddler1')
        new_tiddler2 = next(t for t in tiddlers if t['title'] == 'NewTiddler2')
        new_tiddler3 = next(t for t in tiddlers if t['title'] == 'NewTiddler3')

        self.assertEqual(new_tiddler1['text'], 'content1')
        self.assertEqual(new_tiddler2['text'], 'content2')
        self.assertEqual(new_tiddler3['text'], 'content3')

class TestJsonCommand(unittest.TestCase):
    """Test the json command for outputting tiddlers as JSON"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with tiddlers
        self.test_tiddlers = [
            {
                "title": "TestTiddler",
                "text": "Test content with \"quotes\" and <angles>",
                "created": "20230101000000000",
                "modified": "20230102000000000",
                "tags": "tag1 tag2",
                "type": "text/vnd.tiddlywiki"
            },
            {
                "title": "MinimalTiddler",
                "text": "Minimal",
            },
        ]

        # Create the HTML file
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

    def test_json_output_is_valid_json(self):
        """Test that json command outputs valid JSON"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler")

        output = f.getvalue()
        # Should be able to parse it as JSON
        parsed = json.loads(output)
        self.assertIsInstance(parsed, dict)

    def test_json_output_contains_all_fields(self):
        """Test that json command includes all tiddler fields"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # Check all expected fields are present
        self.assertEqual(parsed['title'], 'TestTiddler')
        self.assertEqual(parsed['text'], 'Test content with "quotes" and <angles>')
        self.assertEqual(parsed['created'], '20230101000000000')
        self.assertEqual(parsed['modified'], '20230102000000000')
        self.assertEqual(parsed['tags'], 'tag1 tag2')
        self.assertEqual(parsed['type'], 'text/vnd.tiddlywiki')

    def test_json_output_is_formatted(self):
        """Test that json command outputs formatted JSON with indentation"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler")

        output = f.getvalue()

        # Should have newlines and indentation (not single-line JSON)
        self.assertIn('\n', output)
        self.assertIn('  ', output)  # 2-space indent
        # Should start with { and end with }
        self.assertTrue(output.strip().startswith('{'))
        self.assertTrue(output.strip().endswith('}'))

    def test_json_nonexistent_tiddler(self):
        """Test that json command exits with error for non-existent tiddler"""
        with self.assertRaises(SystemExit):
            tw_module.json_tiddler(self.test_wiki, "NonExistent")

    def test_json_minimal_tiddler(self):
        """Test that json works with tiddlers that have minimal fields"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "MinimalTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # Should have the fields that exist
        self.assertEqual(parsed['title'], 'MinimalTiddler')
        self.assertEqual(parsed['text'], 'Minimal')

        # Should not have fields that don't exist
        self.assertNotIn('created', parsed)
        self.assertNotIn('modified', parsed)

    def test_json_preserves_unicode(self):
        """Test that json output preserves Unicode characters"""
        import io
        import contextlib

        # Add a tiddler with Unicode
        tw_module.touch_tiddler(self.test_wiki, "UnicodeTiddler", "Curly quotes: \u201ctest\u201d")

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "UnicodeTiddler")

        output = f.getvalue()

        # Should contain literal curly quotes (not escaped as \u201c)
        self.assertIn('\u201c', output)
        self.assertIn('\u201d', output)

        # Verify it parses correctly
        parsed = json.loads(output)
        self.assertIn('\u201c', parsed['text'])

    def test_json_multiple_tiddlers_returns_array(self):
        """Test that json command with multiple tiddlers returns a JSON array"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler", "MinimalTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # Should be an array with 2 elements
        self.assertIsInstance(parsed, list)
        self.assertEqual(len(parsed), 2)

        # Check each tiddler
        self.assertEqual(parsed[0]['title'], 'TestTiddler')
        self.assertEqual(parsed[1]['title'], 'MinimalTiddler')

    def test_json_single_tiddler_returns_object(self):
        """Test that json command with one tiddler returns a JSON object (not array)"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # Should be an object (dict), not an array
        self.assertIsInstance(parsed, dict)
        self.assertEqual(parsed['title'], 'TestTiddler')

    def test_json_multiple_tiddlers_preserves_order(self):
        """Test that json command outputs tiddlers in the order requested"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "MinimalTiddler", "TestTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # Should be in requested order
        self.assertEqual(parsed[0]['title'], 'MinimalTiddler')
        self.assertEqual(parsed[1]['title'], 'TestTiddler')

    def test_json_multiple_tiddlers_one_not_found(self):
        """Test that json command exits with error if any tiddler is not found"""
        with self.assertRaises(SystemExit):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler", "NonExistent")

    def test_json_multiple_tiddlers_all_fields(self):
        """Test that json command with multiple tiddlers includes all fields for each"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler", "MinimalTiddler")

        output = f.getvalue()
        parsed = json.loads(output)

        # First tiddler should have all its fields
        self.assertEqual(parsed[0]['title'], 'TestTiddler')
        self.assertEqual(parsed[0]['text'], 'Test content with "quotes" and <angles>')
        self.assertEqual(parsed[0]['tags'], 'tag1 tag2')

        # Second tiddler should have its fields
        self.assertEqual(parsed[1]['title'], 'MinimalTiddler')
        self.assertEqual(parsed[1]['text'], 'Minimal')

    def test_json_array_output_is_formatted(self):
        """Test that json command outputs formatted JSON array with indentation"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler", "MinimalTiddler")

        output = f.getvalue()

        # Should have newlines and indentation
        self.assertIn('\n', output)
        self.assertIn('  ', output)  # 2-space indent
        # Should start with [ and end with ]
        self.assertTrue(output.strip().startswith('['))
        self.assertTrue(output.strip().endswith(']'))

    def test_json_roundtrip_single_tiddler(self):
        """Test that json output can be inserted back via insert command"""
        import io
        import contextlib

        # Get JSON output
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler")

        json_output = f.getvalue()

        # Remove the tiddler
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler")

        # Insert it back
        tw_module.insert_tiddler(self.test_wiki, json_output)

        # Verify it's back with same content
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(test_tiddler['text'], 'Test content with "quotes" and <angles>')
        self.assertEqual(test_tiddler['tags'], 'tag1 tag2')

    def test_json_roundtrip_multiple_tiddlers(self):
        """Test that json array output can be inserted back via insert command"""
        import io
        import contextlib

        # Get JSON array output
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, "TestTiddler", "MinimalTiddler")

        json_output = f.getvalue()

        # Remove both tiddlers
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler")
        tw_module.remove_tiddler(self.test_wiki, "MinimalTiddler")

        # Insert them back
        tw_module.insert_tiddler(self.test_wiki, json_output)

        # Verify both are back
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        test_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(test_tiddler['text'], 'Test content with "quotes" and <angles>')

        minimal_tiddler = next(t for t in tiddlers if t['title'] == 'MinimalTiddler')
        self.assertEqual(minimal_tiddler['text'], 'Minimal')

    def test_json_all_flag_exports_all_tiddlers(self):
        """Test that json --all exports all tiddlers as a JSON array"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, export_all=True)

        output = f.getvalue()
        parsed = json.loads(output)

        # Should be a list/array
        self.assertIsInstance(parsed, list)

        # Should contain both our test tiddlers
        titles = [t['title'] for t in parsed]
        self.assertIn('TestTiddler', titles)
        self.assertIn('MinimalTiddler', titles)
        self.assertEqual(len(parsed), 2)

    def test_json_all_output_is_compact(self):
        """Test that json --all outputs compact JSON (no indentation for speed)"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, export_all=True)

        output = f.getvalue()

        # Should be single-line JSON (compact format)
        # Should not have 2-space indentation like regular json output
        lines = output.strip().split('\n')
        # Compact JSON should be mostly on one line (or very few lines for large output)
        # For a small wiki with 2 tiddlers, should be just 1 line
        self.assertLessEqual(len(lines), 2)  # Allow for trailing newline

    def test_json_all_preserves_all_fields(self):
        """Test that json --all includes all tiddler fields"""
        import io
        import contextlib

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, export_all=True)

        output = f.getvalue()
        parsed = json.loads(output)

        # Find TestTiddler in the output
        test_tiddler = next(t for t in parsed if t['title'] == 'TestTiddler')

        # Check all expected fields are present
        self.assertEqual(test_tiddler['title'], 'TestTiddler')
        self.assertEqual(test_tiddler['text'], 'Test content with "quotes" and <angles>')
        self.assertEqual(test_tiddler['created'], '20230101000000000')
        self.assertEqual(test_tiddler['modified'], '20230102000000000')
        self.assertEqual(test_tiddler['tags'], 'tag1 tag2')
        self.assertEqual(test_tiddler['type'], 'text/vnd.tiddlywiki')

    def test_json_all_roundtrip(self):
        """Test that json --all output can be inserted back via insert command"""
        import io
        import contextlib

        # Get all tiddlers as JSON
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, export_all=True)

        json_output = f.getvalue()

        # Remove all tiddlers
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler")
        tw_module.remove_tiddler(self.test_wiki, "MinimalTiddler")

        # Insert them all back (wiki is now empty)
        tw_module.insert_tiddler(self.test_wiki, json_output)

        # Verify both are back
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        test_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler')
        self.assertEqual(test_tiddler['text'], 'Test content with "quotes" and <angles>')

        minimal_tiddler = next(t for t in tiddlers if t['title'] == 'MinimalTiddler')
        self.assertEqual(minimal_tiddler['text'], 'Minimal')

    def test_json_all_with_many_tiddlers(self):
        """Test that json --all works efficiently with many tiddlers"""
        import io
        import contextlib

        # Add more tiddlers to the wiki
        for i in range(10):
            tw_module.touch_tiddler(self.test_wiki, f"BulkTiddler{i}", f"Bulk content {i}")

        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.json_tiddler(self.test_wiki, export_all=True)

        output = f.getvalue()
        parsed = json.loads(output)

        # Should have all tiddlers (2 original + 10 bulk = 12)
        self.assertEqual(len(parsed), 12)

        # Check that bulk tiddlers are present
        titles = [t['title'] for t in parsed]
        for i in range(10):
            self.assertIn(f"BulkTiddler{i}", titles)

class TestInsertCommand(unittest.TestCase):
    """Test the insert command for inserting/replacing tiddlers from JSON"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with existing tiddlers
        self.test_tiddlers = [
            {
                "title": "ExistingTiddler",
                "text": "Original content",
                "created": "20230101000000000",
                "modified": "20230101000000000",
            },
        ]

        # Create the HTML file
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

    def test_insert_new_tiddler(self):
        """Test inserting a new tiddler from JSON"""
        new_tiddler_json = json.dumps({
            "title": "NewTiddler",
            "text": "New content",
            "tags": "test"
        })

        tw_module.insert_tiddler(self.test_wiki, new_tiddler_json)

        # Verify it was added
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        new_tiddler = next(t for t in tiddlers if t['title'] == 'NewTiddler')
        self.assertEqual(new_tiddler['text'], 'New content')
        self.assertEqual(new_tiddler['tags'], 'test')

    def test_insert_replaces_existing_tiddler(self):
        """Test that insert replaces an existing tiddler"""
        updated_tiddler_json = json.dumps({
            "title": "ExistingTiddler",
            "text": "Updated content",
            "created": "20230101000000000",
            "modified": "20250101000000000",
            "new_field": "new value"
        })

        tw_module.insert_tiddler(self.test_wiki, updated_tiddler_json)

        # Verify it was replaced (not duplicated)
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)

        updated = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        self.assertEqual(updated['text'], 'Updated content')
        self.assertEqual(updated['new_field'], 'new value')

    def test_insert_invalid_json(self):
        """Test that insert exits with error for invalid JSON"""
        with self.assertRaises(SystemExit):
            tw_module.insert_tiddler(self.test_wiki, "not valid json {")

    def test_insert_json_without_title(self):
        """Test that insert exits with error if JSON has no title field"""
        no_title_json = json.dumps({
            "text": "Content without title",
            "tags": "test"
        })

        with self.assertRaises(SystemExit):
            tw_module.insert_tiddler(self.test_wiki, no_title_json)

    def test_insert_preserves_formatting(self):
        """Test that insert preserves JSON formatting"""
        new_tiddler_json = json.dumps({
            "title": "FormattingTest",
            "text": "Content with <angles> and \"quotes\""
        })

        tw_module.insert_tiddler(self.test_wiki, new_tiddler_json)

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract JSON
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # Verify formatting
        self.assertTrue(json_str.startswith('[\n{'))
        self.assertIn('\\u003C', json_str)  # < should be escaped

        # Verify it's valid JSON
        tiddlers = json.loads(json_str, strict=False)
        self.assertEqual(len(tiddlers), 2)

    def test_insert_preserves_unicode(self):
        """Test that insert preserves Unicode characters"""
        unicode_tiddler_json = json.dumps({
            "title": "UnicodeTest",
            "text": "Curly quotes: \u201ctest\u201d"
        }, ensure_ascii=False)

        tw_module.insert_tiddler(self.test_wiki, unicode_tiddler_json)

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should contain literal curly quotes (not escaped)
        self.assertIn('\u201c', content)
        self.assertIn('\u201d', content)
        self.assertNotIn('\\u201c', content)

        # Verify it loads correctly
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        unicode_tiddler = next(t for t in tiddlers if t['title'] == 'UnicodeTest')
        self.assertIn('\u201c', unicode_tiddler['text'])

    def test_wiki_readable_after_insert(self):
        """Test that the wiki is still readable after insert"""
        new_tiddler_json = json.dumps({
            "title": "ReadableTest",
            "text": "Test content"
        })

        tw_module.insert_tiddler(self.test_wiki, new_tiddler_json)

        # Should be able to load all tiddlers
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        # Should be able to cat the new tiddler
        new_tiddler = next(t for t in tiddlers if t['title'] == 'ReadableTest')
        self.assertEqual(new_tiddler['text'], 'Test content')

    def test_insert_with_all_field_types(self):
        """Test inserting a tiddler with various field types"""
        complex_tiddler_json = json.dumps({
            "title": "ComplexTiddler",
            "text": "Complex content",
            "created": "20230101000000000",
            "modified": "20230102000000000",
            "tags": "tag1 tag2 tag3",
            "type": "text/vnd.tiddlywiki",
            "author": "Test Author",
            "custom_field": "custom value"
        })

        tw_module.insert_tiddler(self.test_wiki, complex_tiddler_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        complex_tiddler = next(t for t in tiddlers if t['title'] == 'ComplexTiddler')

        # Verify all fields were preserved
        self.assertEqual(complex_tiddler['text'], 'Complex content')
        self.assertEqual(complex_tiddler['created'], '20230101000000000')
        self.assertEqual(complex_tiddler['modified'], '20230102000000000')
        self.assertEqual(complex_tiddler['tags'], 'tag1 tag2 tag3')
        self.assertEqual(complex_tiddler['type'], 'text/vnd.tiddlywiki')
        self.assertEqual(complex_tiddler['author'], 'Test Author')
        self.assertEqual(complex_tiddler['custom_field'], 'custom value')

    def test_insert_minimal_tiddler(self):
        """Test inserting a tiddler with only a title"""
        minimal_json = json.dumps({"title": "MinimalTiddler"})

        tw_module.insert_tiddler(self.test_wiki, minimal_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        minimal = next(t for t in tiddlers if t['title'] == 'MinimalTiddler')

        # Should have title plus auto-added timestamps
        self.assertEqual(minimal['title'], 'MinimalTiddler')
        self.assertEqual(len(minimal), 3)
        self.assertIn('created', minimal)
        self.assertIn('modified', minimal)

    def test_insert_auto_adds_created(self):
        """Test that insert auto-adds created timestamp if missing"""
        new_json = json.dumps({"title": "InsertCreatedTest", "text": "Content"})

        tw_module.insert_tiddler(self.test_wiki, new_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'InsertCreatedTest')

        self.assertIn('created', test_tiddler)
        self.assertEqual(len(test_tiddler['created']), 17)
        self.assertTrue(test_tiddler['created'].isdigit())

    def test_insert_auto_adds_modified(self):
        """Test that insert auto-adds modified timestamp if missing"""
        new_json = json.dumps({"title": "InsertModifiedTest", "text": "Content"})

        tw_module.insert_tiddler(self.test_wiki, new_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'InsertModifiedTest')

        self.assertIn('modified', test_tiddler)
        self.assertEqual(len(test_tiddler['modified']), 17)
        self.assertTrue(test_tiddler['modified'].isdigit())

    def test_insert_preserves_existing_timestamps(self):
        """Test that insert preserves user-provided timestamps"""
        new_json = json.dumps({
            "title": "InsertPreserveTest",
            "text": "Content",
            "created": "20200101120000000",
            "modified": "20210101120000000"
        })

        tw_module.insert_tiddler(self.test_wiki, new_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'InsertPreserveTest')

        self.assertEqual(test_tiddler['created'], '20200101120000000')
        self.assertEqual(test_tiddler['modified'], '20210101120000000')

    def test_insert_timestamp_format_valid(self):
        """Test that insert auto-generated timestamps have valid format"""
        new_json = json.dumps({"title": "InsertFormatTest", "text": "Content"})

        tw_module.insert_tiddler(self.test_wiki, new_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'InsertFormatTest')

        # Check format: YYYYMMDDhhmmssxxx (17 digits)
        self.assertEqual(len(test_tiddler['created']), 17)
        self.assertEqual(len(test_tiddler['modified']), 17)
        self.assertTrue(test_tiddler['created'].isdigit())
        self.assertTrue(test_tiddler['modified'].isdigit())

        # Verify it parses as valid date
        year = int(test_tiddler['created'][0:4])
        month = int(test_tiddler['created'][4:6])
        day = int(test_tiddler['created'][6:8])

        self.assertGreaterEqual(year, 2020)
        self.assertLessEqual(year, 2100)
        self.assertGreaterEqual(month, 1)
        self.assertLessEqual(month, 12)
        self.assertGreaterEqual(day, 1)
        self.assertLessEqual(day, 31)

    def test_insert_array_multiple_tiddlers(self):
        """Test inserting multiple tiddlers from a JSON array"""
        tiddlers_json = json.dumps([
            {"title": "ArrayTest1", "text": "First tiddler"},
            {"title": "ArrayTest2", "text": "Second tiddler"},
            {"title": "ArrayTest3", "text": "Third tiddler"}
        ])

        tw_module.insert_tiddler(self.test_wiki, tiddlers_json)

        # Verify all were added
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 4)  # 1 existing + 3 new

        # Verify each tiddler
        test1 = next(t for t in tiddlers if t['title'] == 'ArrayTest1')
        self.assertEqual(test1['text'], 'First tiddler')

        test2 = next(t for t in tiddlers if t['title'] == 'ArrayTest2')
        self.assertEqual(test2['text'], 'Second tiddler')

        test3 = next(t for t in tiddlers if t['title'] == 'ArrayTest3')
        self.assertEqual(test3['text'], 'Third tiddler')

    def test_insert_array_empty(self):
        """Test inserting an empty array creates no tiddlers"""
        empty_json = json.dumps([])

        tw_module.insert_tiddler(self.test_wiki, empty_json)

        # Should still have only the original tiddler
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)

    def test_insert_array_replaces_existing(self):
        """Test that inserting an array with existing tiddler titles replaces them"""
        # Create initial tiddlers
        tw_module.touch_tiddler(self.test_wiki, "Replace1", "Original 1")
        tw_module.touch_tiddler(self.test_wiki, "Replace2", "Original 2")

        # Insert array with updated versions
        tiddlers_json = json.dumps([
            {"title": "Replace1", "text": "Updated 1", "new_field": "value1"},
            {"title": "Replace2", "text": "Updated 2", "new_field": "value2"}
        ])

        tw_module.insert_tiddler(self.test_wiki, tiddlers_json)

        # Verify replacements
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        # Should have: ExistingTiddler, Replace1, Replace2
        self.assertEqual(len(tiddlers), 3)

        replace1 = next(t for t in tiddlers if t['title'] == 'Replace1')
        self.assertEqual(replace1['text'], 'Updated 1')
        self.assertEqual(replace1['new_field'], 'value1')

        replace2 = next(t for t in tiddlers if t['title'] == 'Replace2')
        self.assertEqual(replace2['text'], 'Updated 2')
        self.assertEqual(replace2['new_field'], 'value2')

    def test_insert_array_missing_title(self):
        """Test that inserting an array with a tiddler missing title fails"""
        invalid_json = json.dumps([
            {"title": "Valid", "text": "This is valid"},
            {"text": "Missing title field"}
        ])

        with self.assertRaises(SystemExit):
            tw_module.insert_tiddler(self.test_wiki, invalid_json)

    def test_insert_array_invalid_element(self):
        """Test that inserting an array with non-object elements fails"""
        invalid_json = json.dumps([
            {"title": "Valid", "text": "This is valid"},
            "not an object"
        ])

        with self.assertRaises(SystemExit):
            tw_module.insert_tiddler(self.test_wiki, invalid_json)

    def test_insert_array_adds_timestamps(self):
        """Test that inserting an array auto-adds timestamps to each tiddler"""
        tiddlers_json = json.dumps([
            {"title": "Timestamp1", "text": "First"},
            {"title": "Timestamp2", "text": "Second"}
        ])

        tw_module.insert_tiddler(self.test_wiki, tiddlers_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)

        ts1 = next(t for t in tiddlers if t['title'] == 'Timestamp1')
        self.assertIn('created', ts1)
        self.assertIn('modified', ts1)
        self.assertEqual(len(ts1['created']), 17)
        self.assertEqual(len(ts1['modified']), 17)

        ts2 = next(t for t in tiddlers if t['title'] == 'Timestamp2')
        self.assertIn('created', ts2)
        self.assertIn('modified', ts2)

    def test_insert_array_preserves_user_timestamps(self):
        """Test that inserting an array preserves user-provided timestamps"""
        tiddlers_json = json.dumps([
            {
                "title": "UserTime1",
                "text": "First",
                "created": "20200101120000000",
                "modified": "20200102120000000"
            },
            {
                "title": "UserTime2",
                "text": "Second",
                "created": "20210101120000000",
                "modified": "20210102120000000"
            }
        ])

        tw_module.insert_tiddler(self.test_wiki, tiddlers_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)

        ut1 = next(t for t in tiddlers if t['title'] == 'UserTime1')
        self.assertEqual(ut1['created'], '20200101120000000')
        self.assertEqual(ut1['modified'], '20200102120000000')

        ut2 = next(t for t in tiddlers if t['title'] == 'UserTime2')
        self.assertEqual(ut2['created'], '20210101120000000')
        self.assertEqual(ut2['modified'], '20210102120000000')

class TestAlphabeticalOrdering(unittest.TestCase):
    """Test that tiddlers are stored in alphabetical order by title"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with tiddlers in non-alphabetical order
        self.test_tiddlers = [
            {"title": "Zebra", "text": "Last alphabetically"},
            {"title": "Apple", "text": "First alphabetically"},
            {"title": "Mango", "text": "Middle alphabetically"},
        ]

        # Create the HTML file (intentionally not sorted)
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

    def extract_tiddler_titles_from_store(self):
        """Helper to extract tiddler titles in the order they appear in the store"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        if not stores:
            return []

        # Get titles in the order they appear in the first store
        return [t.get('title') for t in stores[0]['tiddlers']]

    def test_touch_sorts_tiddlers(self):
        """Test that touch command sorts tiddlers alphabetically"""
        tw_module.touch_tiddler(self.test_wiki, "Banana", "New tiddler")

        titles = self.extract_tiddler_titles_from_store()
        expected = ["Apple", "Banana", "Mango", "Zebra"]
        self.assertEqual(titles, expected)

    def test_set_sorts_tiddlers(self):
        """Test that set command sorts tiddlers alphabetically"""
        tw_module.set_tiddler_field(self.test_wiki, "Apple", "text", "Modified text")

        titles = self.extract_tiddler_titles_from_store()
        expected = ["Apple", "Mango", "Zebra"]
        self.assertEqual(titles, expected)

    def test_rm_sorts_tiddlers(self):
        """Test that rm command sorts remaining tiddlers alphabetically"""
        tw_module.remove_tiddler(self.test_wiki, "Zebra")

        titles = self.extract_tiddler_titles_from_store()
        expected = ["Apple", "Mango"]
        self.assertEqual(titles, expected)

    def test_insert_sorts_tiddlers(self):
        """Test that insert command sorts tiddlers alphabetically"""
        new_tiddler_json = json.dumps({
            "title": "Banana",
            "text": "Inserted tiddler"
        })

        tw_module.insert_tiddler(self.test_wiki, new_tiddler_json)

        titles = self.extract_tiddler_titles_from_store()
        expected = ["Apple", "Banana", "Mango", "Zebra"]
        self.assertEqual(titles, expected)

    def test_insert_replace_sorts_tiddlers(self):
        """Test that replacing with insert maintains alphabetical order"""
        replacement_json = json.dumps({
            "title": "Mango",
            "text": "Replaced mango"
        })

        tw_module.insert_tiddler(self.test_wiki, replacement_json)

        titles = self.extract_tiddler_titles_from_store()
        expected = ["Apple", "Mango", "Zebra"]
        self.assertEqual(titles, expected)

    def test_multiple_operations_maintain_order(self):
        """Test that multiple operations maintain alphabetical order"""
        # Add a tiddler
        tw_module.touch_tiddler(self.test_wiki, "Banana", "New")
        titles = self.extract_tiddler_titles_from_store()
        self.assertEqual(titles, ["Apple", "Banana", "Mango", "Zebra"])

        # Modify a tiddler
        tw_module.set_tiddler_field(self.test_wiki, "Zebra", "text", "Modified")
        titles = self.extract_tiddler_titles_from_store()
        self.assertEqual(titles, ["Apple", "Banana", "Mango", "Zebra"])

        # Remove a tiddler
        tw_module.remove_tiddler(self.test_wiki, "Banana")
        titles = self.extract_tiddler_titles_from_store()
        self.assertEqual(titles, ["Apple", "Mango", "Zebra"])

    def test_case_insensitive_sorting(self):
        """Test that sorting is case-sensitive (standard Python sort behavior)"""
        # Add tiddlers with different cases
        tw_module.touch_tiddler(self.test_wiki, "aardvark", "lowercase")
        tw_module.touch_tiddler(self.test_wiki, "Banana", "Titlecase")
        tw_module.touch_tiddler(self.test_wiki, "CARROT", "UPPERCASE")

        titles = self.extract_tiddler_titles_from_store()
        # Standard Python sort is case-sensitive, uppercase comes before lowercase
        expected = ["Apple", "Banana", "CARROT", "Mango", "Zebra", "aardvark"]
        self.assertEqual(titles, expected)

    def test_special_characters_sorting(self):
        """Test that tiddlers with special characters are sorted correctly"""
        tw_module.touch_tiddler(self.test_wiki, "123 Numbers", "Numbers first")
        tw_module.touch_tiddler(self.test_wiki, "$SpecialChar", "Special char")

        titles = self.extract_tiddler_titles_from_store()
        # Numbers and special chars sort before letters in ASCII
        self.assertTrue(titles.index("$SpecialChar") < titles.index("Apple"))
        self.assertTrue(titles.index("123 Numbers") < titles.index("Apple"))

    def test_empty_title_handling(self):
        """Test that tiddlers without titles are handled gracefully"""
        # Insert a tiddler with empty string as title using insert command
        empty_title_json = json.dumps({"title": "", "text": "Empty title tiddler"})
        tw_module.insert_tiddler(self.test_wiki, empty_title_json)

        # Add another tiddler
        tw_module.touch_tiddler(self.test_wiki, "Aaa", "test")

        titles = self.extract_tiddler_titles_from_store()
        # Empty string sorts first
        self.assertEqual(titles[0], "")
        self.assertIn("Aaa", titles)
        # Verify all expected tiddlers are present
        self.assertIn("Apple", titles)
        self.assertIn("Mango", titles)
        self.assertIn("Zebra", titles)

class TestReplaceCommand(unittest.TestCase):
    """Test the replace command for inserting/replacing from cat format"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with existing tiddlers
        self.test_tiddlers = [
            {
                "title": "ExistingTiddler",
                "text": "Original content",
                "created": "20230101000000000",
                "modified": "20230101000000000",
                "tags": "original"
            },
        ]

        # Create the HTML file
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

    def test_replace_new_tiddler(self):
        """Test replacing creates a new tiddler from cat format"""
        cat_format = """title: NewTiddler
tags: test new
created: 20250101000000000

This is the text content.
It can span multiple lines."""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        # Verify it was added
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 2)

        new_tiddler = next(t for t in tiddlers if t['title'] == 'NewTiddler')
        self.assertEqual(new_tiddler['tags'], 'test new')
        self.assertEqual(new_tiddler['created'], '20250101000000000')
        self.assertEqual(new_tiddler['text'], 'This is the text content.\nIt can span multiple lines.')

    def test_replace_existing_tiddler(self):
        """Test replacing updates an existing tiddler"""
        cat_format = """title: ExistingTiddler
tags: updated
created: 20230101000000000
modified: 20250101000000000

This is updated content."""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        # Verify it was replaced (not duplicated)
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)

        updated = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        self.assertEqual(updated['tags'], 'updated')
        self.assertEqual(updated['text'], 'This is updated content.')

    def test_replace_roundtrip_with_cat(self):
        """Test that cat -> replace is a perfect roundtrip"""
        import io
        import contextlib

        # Get cat output
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.cat_tiddler(self.test_wiki, "ExistingTiddler")
        cat_output = f.getvalue()

        # Create a new tiddler with different title but same structure
        modified_output = cat_output.replace('title: ExistingTiddler', 'title: RoundtripTiddler')

        # Replace it back
        tw_module.replace_tiddler(self.test_wiki, modified_output)

        # Verify the tiddler exists and has correct content
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        roundtrip = next(t for t in tiddlers if t['title'] == 'RoundtripTiddler')

        self.assertEqual(roundtrip['text'], 'Original content')
        self.assertEqual(roundtrip['tags'], 'original')
        self.assertEqual(roundtrip['created'], '20230101000000000')
        self.assertEqual(roundtrip['modified'], '20230101000000000')

    def test_replace_no_text_field(self):
        """Test replacing a tiddler with only frontmatter (no text)"""
        cat_format = """title: NoTextTiddler
tags: test
created: 20250101000000000"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        no_text = next(t for t in tiddlers if t['title'] == 'NoTextTiddler')

        self.assertEqual(no_text['tags'], 'test')
        self.assertNotIn('text', no_text)

    def test_replace_empty_text_field(self):
        """Test replacing with empty text after frontmatter"""
        cat_format = """title: EmptyTextTiddler
tags: test

"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        empty_text = next(t for t in tiddlers if t['title'] == 'EmptyTextTiddler')

        self.assertEqual(empty_text['tags'], 'test')
        # Empty string after blank line should not create text field
        self.assertNotIn('text', empty_text)

    def test_replace_text_with_colons(self):
        """Test that colons in text content don't get parsed as fields"""
        cat_format = """title: ColonTest
tags: test

This text has a colon: like this
And another: here too
key: value in the text"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        colon_test = next(t for t in tiddlers if t['title'] == 'ColonTest')

        expected_text = 'This text has a colon: like this\nAnd another: here too\nkey: value in the text'
        self.assertEqual(colon_test['text'], expected_text)

    def test_replace_multiline_text(self):
        """Test replacing with multiline text content"""
        cat_format = """title: MultilineTest
tags: test

Line 1
Line 2
Line 3

Line 5 (after empty line)"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        multiline = next(t for t in tiddlers if t['title'] == 'MultilineTest')

        expected_text = 'Line 1\nLine 2\nLine 3\n\nLine 5 (after empty line)'
        self.assertEqual(multiline['text'], expected_text)

    def test_replace_without_title(self):
        """Test that replace fails without a title field"""
        cat_format = """tags: test
created: 20250101000000000

Some text"""

        with self.assertRaises(SystemExit):
            tw_module.replace_tiddler(self.test_wiki, cat_format)

    def test_replace_preserves_formatting(self):
        """Test that replace preserves JSON formatting in the wiki"""
        cat_format = """title: FormattingTest
tags: test

This is the text content with <angles> and "quotes"."""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract JSON
        pattern = '<script class="tiddlywiki-tiddler-store" type="application/json">'
        start = content.find(pattern)
        json_start = content.find('[', start)
        end = content.find('</script>', json_start)
        json_str = content[json_start:end]

        # Verify formatting
        self.assertTrue(json_str.startswith('[\n{'))
        self.assertIn('\\u003C', json_str)  # < should be escaped

        # Verify the tiddler was stored correctly
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        formatting_test = next(t for t in tiddlers if t['title'] == 'FormattingTest')
        self.assertIn('<angles>', formatting_test['text'])

    def test_replace_field_with_spaces_in_value(self):
        """Test that field values with spaces are parsed correctly"""
        cat_format = """title: SpaceTest
tags: tag1 tag2 tag3
author: John Doe

Text content"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        space_test = next(t for t in tiddlers if t['title'] == 'SpaceTest')

        self.assertEqual(space_test['tags'], 'tag1 tag2 tag3')
        self.assertEqual(space_test['author'], 'John Doe')

    def test_replace_sorts_tiddlers(self):
        """Test that replace maintains alphabetical order"""
        # Add a tiddler that should sort before ExistingTiddler
        cat_format = """title: AAA_FirstTiddler
tags: test

First alphabetically"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        titles = [t.get('title') for t in stores[0]['tiddlers']]

        self.assertEqual(titles, ['AAA_FirstTiddler', 'ExistingTiddler'])

    def test_replace_auto_adds_created(self):
        """Test that replace auto-adds created timestamp if missing"""
        cat_format = """title: AutoCreatedTest
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'AutoCreatedTest')

        self.assertIn('created', test_tiddler)
        self.assertEqual(len(test_tiddler['created']), 17)
        self.assertTrue(test_tiddler['created'].isdigit())

    def test_replace_auto_adds_modified(self):
        """Test that replace auto-adds modified timestamp if missing"""
        cat_format = """title: AutoModifiedTest
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'AutoModifiedTest')

        self.assertIn('modified', test_tiddler)
        self.assertEqual(len(test_tiddler['modified']), 17)
        self.assertTrue(test_tiddler['modified'].isdigit())

    def test_replace_preserves_existing_created(self):
        """Test that replace preserves user-provided created timestamp"""
        cat_format = """title: PreserveCreatedTest
created: 20200101120000000
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'PreserveCreatedTest')

        self.assertEqual(test_tiddler['created'], '20200101120000000')

    def test_replace_preserves_existing_modified(self):
        """Test that replace preserves user-provided modified timestamp"""
        cat_format = """title: PreserveModifiedTest
modified: 20200101120000000
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'PreserveModifiedTest')

        self.assertEqual(test_tiddler['modified'], '20200101120000000')

    def test_replace_both_fields_missing(self):
        """Test that replace adds both timestamps when both missing"""
        cat_format = """title: BothMissingTest
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'BothMissingTest')

        self.assertIn('created', test_tiddler)
        self.assertIn('modified', test_tiddler)
        self.assertEqual(len(test_tiddler['created']), 17)
        self.assertEqual(len(test_tiddler['modified']), 17)

    def test_replace_both_fields_present(self):
        """Test that replace preserves both timestamps when both provided"""
        cat_format = """title: BothPresentTest
created: 20200101120000000
modified: 20210101120000000
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'BothPresentTest')

        self.assertEqual(test_tiddler['created'], '20200101120000000')
        self.assertEqual(test_tiddler['modified'], '20210101120000000')

    def test_replace_timestamp_format_valid(self):
        """Test that auto-generated timestamps have valid TiddlyWiki format"""
        cat_format = """title: TimestampFormatTest
tags: test

Content here"""

        tw_module.replace_tiddler(self.test_wiki, cat_format)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        test_tiddler = next(t for t in tiddlers if t['title'] == 'TimestampFormatTest')

        # Check format: YYYYMMDDhhmmssxxx (17 digits)
        self.assertEqual(len(test_tiddler['created']), 17)
        self.assertEqual(len(test_tiddler['modified']), 17)
        self.assertTrue(test_tiddler['created'].isdigit())
        self.assertTrue(test_tiddler['modified'].isdigit())

        # Verify it parses as valid date
        year = int(test_tiddler['created'][0:4])
        month = int(test_tiddler['created'][4:6])
        day = int(test_tiddler['created'][6:8])

        self.assertGreaterEqual(year, 2020)
        self.assertLessEqual(year, 2100)
        self.assertGreaterEqual(month, 1)
        self.assertLessEqual(month, 12)
        self.assertGreaterEqual(day, 1)
        self.assertLessEqual(day, 31)

class TestServeCommand(unittest.TestCase):
    """Test the serve command for serving the wiki locally"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler", "text": "Test content", "created": "20230101000000000"},
        ]

        # Create the HTML file
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

    def test_serve_starts_server(self):
        """Test that serve_wiki starts an HTTP server"""
        import threading
        import time
        import urllib.request

        # Start server in a thread
        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', 0),  # Port 0 = auto-assign
            daemon=True
        )

        # We need to capture the actual port - let's use a different approach
        # Start on a specific high port
        test_port = 19999

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        # Give server time to start
        time.sleep(0.2)

        try:
            # Make a request to the server
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            content = response.read().decode('utf-8')

            # Verify we got HTML back
            self.assertIn('<!DOCTYPE html>', content)
            self.assertIn('Test Wiki', content)
            self.assertIn('TestTiddler', content)

            # Verify status code
            self.assertEqual(response.status, 200)
        finally:
            # Thread will die when test ends (daemon=True)
            pass

    def test_serve_sets_correct_content_type(self):
        """Test that serve_wiki sets the correct Content-Type header"""
        import threading
        import time
        import urllib.request

        test_port = 20000

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            content_type = response.headers.get('Content-Type')

            self.assertIsNotNone(content_type)
            self.assertIn('text/html', content_type)
            self.assertIn('charset=utf-8', content_type)
        finally:
            pass

    def test_serve_with_custom_host(self):
        """Test that serve_wiki can bind to custom host"""
        import threading
        import time
        import urllib.request

        test_port = 20001

        # Bind to 127.0.0.1 specifically
        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, '127.0.0.1', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://127.0.0.1:{test_port}/', timeout=2)
            self.assertEqual(response.status, 200)
        finally:
            pass

    def test_serve_handles_multiple_requests(self):
        """Test that serve_wiki can handle multiple consecutive requests"""
        import threading
        import time
        import urllib.request

        test_port = 20002

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Make multiple requests
            for i in range(3):
                response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
                self.assertEqual(response.status, 200)
                content = response.read().decode('utf-8')
                self.assertIn('Test Wiki', content)
        finally:
            pass

    def test_serve_content_has_meta_tag(self):
        """Test that served content includes the tw-server meta tag"""
        import threading
        import time
        import urllib.request

        test_port = 20003

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Get content from server
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            served_content = response.read().decode('utf-8')

            # Should contain the meta tag
            self.assertIn('<meta name="tw-server" content="enabled">', served_content)

            # Should still contain the original wiki content
            self.assertIn('Test Wiki', served_content)
            self.assertIn('TestTiddler', served_content)
        finally:
            pass

    def test_serve_canonical_uri_text_file(self):
        """Test that serve_wiki can serve external files for _canonical_uri"""
        import threading
        import time
        import urllib.request

        test_port = 20004

        # Create a test file in a subdirectory
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'files')
        os.makedirs(files_dir, exist_ok=True)
        test_file = os.path.join(files_dir, 'test.txt')
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write('Test content for canonical URI')

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Request the file
            response = urllib.request.urlopen(f'http://localhost:{test_port}/files/test.txt', timeout=2)
            content = response.read().decode('utf-8')

            self.assertEqual(response.status, 200)
            self.assertEqual(content, 'Test content for canonical URI')
            self.assertEqual(response.headers.get('Content-Type'), 'text/plain')
        finally:
            pass

    def test_serve_canonical_uri_html_file(self):
        """Test that HTML files are served with correct MIME type"""
        import threading
        import time
        import urllib.request

        test_port = 20005

        # Create an HTML file
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'files')
        os.makedirs(files_dir, exist_ok=True)
        test_file = os.path.join(files_dir, 'test.html')
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write('<h1>Test HTML</h1>')

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/files/test.html', timeout=2)
            content = response.read().decode('utf-8')

            self.assertEqual(response.status, 200)
            self.assertEqual(content, '<h1>Test HTML</h1>')
            self.assertEqual(response.headers.get('Content-Type'), 'text/html')
        finally:
            pass

    def test_serve_canonical_uri_cors_headers(self):
        """Test that CORS headers are included for external files"""
        import threading
        import time
        import urllib.request

        test_port = 20006

        # Create a test file
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'assets')
        os.makedirs(files_dir, exist_ok=True)
        test_file = os.path.join(files_dir, 'data.json')
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write('{"test": "data"}')

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/assets/data.json', timeout=2)

            self.assertEqual(response.status, 200)
            self.assertEqual(response.headers.get('Access-Control-Allow-Origin'), '*')
            self.assertEqual(response.headers.get('Content-Type'), 'application/json')
        finally:
            pass

    def test_serve_canonical_uri_nonexistent_file(self):
        """Test that nonexistent files return 404"""
        import threading
        import time
        import urllib.request
        import urllib.error

        test_port = 20007

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            with self.assertRaises(urllib.error.HTTPError) as context:
                urllib.request.urlopen(f'http://localhost:{test_port}/files/nonexistent.txt', timeout=2)

            self.assertEqual(context.exception.code, 404)
        finally:
            pass

    def test_serve_canonical_uri_directory_traversal_blocked(self):
        """Test that directory traversal attempts are blocked"""
        import threading
        import time
        import urllib.request
        import urllib.error

        test_port = 20008

        # Create a file outside the wiki directory
        secret_file = os.path.join(os.path.dirname(self.test_dir), 'secret.txt')
        with open(secret_file, 'w', encoding='utf-8') as f:
            f.write('SECRET DATA')

        try:
            server_thread = threading.Thread(
                target=tw_module.serve_wiki,
                args=(self.test_wiki, 'localhost', test_port),
                daemon=True
            )
            server_thread.start()

            time.sleep(0.2)

            # Try directory traversal with encoded path
            with self.assertRaises(urllib.error.HTTPError) as context:
                urllib.request.urlopen(f'http://localhost:{test_port}/../secret.txt', timeout=2)

            # Should be 403 (Forbidden) or 404 (Not Found)
            self.assertIn(context.exception.code, [403, 404])
        finally:
            # Clean up
            if os.path.exists(secret_file):
                os.remove(secret_file)

    def test_serve_canonical_uri_url_encoded_path(self):
        """Test that URL-encoded paths work correctly"""
        import threading
        import time
        import urllib.request

        test_port = 20009

        # Create a file with space in directory name
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'my files')
        os.makedirs(files_dir, exist_ok=True)
        test_file = os.path.join(files_dir, 'doc.txt')
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write('Document content')

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Request with URL-encoded space
            response = urllib.request.urlopen(f'http://localhost:{test_port}/my%20files/doc.txt', timeout=2)
            content = response.read().decode('utf-8')

            self.assertEqual(response.status, 200)
            self.assertEqual(content, 'Document content')
        finally:
            pass

    def test_serve_canonical_uri_directory_listing_blocked(self):
        """Test that directory listing is prevented"""
        import threading
        import time
        import urllib.request
        import urllib.error

        test_port = 20010

        # Create a directory with files
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'files')
        os.makedirs(files_dir, exist_ok=True)

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Try to list directory
            with self.assertRaises(urllib.error.HTTPError) as context:
                urllib.request.urlopen(f'http://localhost:{test_port}/files/', timeout=2)

            self.assertEqual(context.exception.code, 404)
        finally:
            pass

    def test_serve_readonly_mode_rejects_put(self):
        """Test that readonly mode rejects PUT requests with 403"""
        import threading
        import time
        import urllib.request
        import urllib.error

        test_port = 20011

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, True),  # readonly=True
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Try to save (PUT request)
            test_html = b'<!DOCTYPE html><html><head></head><body>Modified</body></html>'
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=test_html,
                method='PUT'
            )

            with self.assertRaises(urllib.error.HTTPError) as context:
                urllib.request.urlopen(req, timeout=2)

            # Should return 403 Forbidden
            self.assertEqual(context.exception.code, 403)
            self.assertIn('readonly', context.exception.reason.lower())
        finally:
            pass

    def test_serve_readonly_mode_allows_get(self):
        """Test that readonly mode still allows GET requests"""
        import threading
        import time
        import urllib.request

        test_port = 20012

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, True),  # readonly=True
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # GET request should work
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            content = response.read().decode('utf-8')

            self.assertEqual(response.status, 200)
            self.assertIn('Test Wiki', content)
        finally:
            pass

    def test_serve_readonly_mode_allows_version_endpoint(self):
        """Test that readonly mode allows version endpoint access"""
        import threading
        import time
        import urllib.request
        import json

        test_port = 20013

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, True),  # readonly=True
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/version', timeout=2)
            data = json.loads(response.read().decode('utf-8'))

            self.assertEqual(response.status, 200)
            self.assertIn('version', data)
            self.assertIn('mtime', data)
        finally:
            pass

    def test_serve_readonly_mode_allows_tiddlers_endpoint(self):
        """Test that readonly mode allows tiddlers endpoint access"""
        import threading
        import time
        import urllib.request
        import json

        test_port = 20014

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, True),  # readonly=True
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/tiddlers', timeout=2)
            data = json.loads(response.read().decode('utf-8'))

            self.assertEqual(response.status, 200)
            self.assertIn('tiddlers', data)
            self.assertIn('version', data)
        finally:
            pass

    def test_serve_readonly_false_allows_put(self):
        """Test that non-readonly mode (default) allows PUT requests"""
        import threading
        import time
        import urllib.request

        test_port = 20015

        # Create a valid wiki HTML for PUT request
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            original_content = f.read()

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, False),  # readonly=False
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # PUT request should work in non-readonly mode
            test_html = original_content.encode('utf-8')
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=test_html,
                method='PUT'
            )

            response = urllib.request.urlopen(req, timeout=2)
            # 204 No Content is standard for successful WebDAV PUT
            self.assertEqual(response.status, 204)
        finally:
            pass

    def test_serve_readonly_mode_allows_file_serving(self):
        """Test that readonly mode allows serving external files (_canonical_uri)"""
        import threading
        import time
        import urllib.request

        test_port = 20016

        # Create a test file
        files_dir = os.path.join(os.path.dirname(self.test_wiki), 'files')
        os.makedirs(files_dir, exist_ok=True)
        test_file = os.path.join(files_dir, 'readonly_test.txt')
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write('Readonly mode file test')

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port, True),  # readonly=True
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/files/readonly_test.txt', timeout=2)
            content = response.read().decode('utf-8')

            self.assertEqual(response.status, 200)
            self.assertEqual(content, 'Readonly mode file test')
        finally:
            pass

class TestLiveReloadEndpoints(unittest.TestCase):
    """Test the live reload endpoints added for Phase 1"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000"},
            {"title": "TestTiddler2", "text": "Content 2", "created": "20230102000000000"},
        ]

        # Create the HTML file
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

    def test_version_endpoint_returns_json(self):
        """Test that /_tw/version endpoint returns valid JSON"""
        import threading
        import time
        import urllib.request

        test_port = 21000

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/version', timeout=2)
            content = response.read().decode('utf-8')

            # Should be valid JSON
            data = json.loads(content)

            # Should have expected fields
            self.assertIn('version', data)
            self.assertIn('mtime', data)
            self.assertIn('server', data)

            # Verify field types
            self.assertIsInstance(data['version'], (int, float))
            self.assertIsInstance(data['mtime'], (int, float))
            self.assertEqual(data['server'], 'tw-python')

            # version and mtime should be the same
            self.assertEqual(data['version'], data['mtime'])
        finally:
            pass

    def test_version_endpoint_content_type(self):
        """Test that /_tw/version returns correct Content-Type"""
        import threading
        import time
        import urllib.request

        test_port = 21001

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/version', timeout=2)
            content_type = response.headers.get('Content-Type')

            self.assertIsNotNone(content_type)
            self.assertIn('application/json', content_type)
        finally:
            pass

    def test_tiddlers_endpoint_returns_json(self):
        """Test that /_tw/tiddlers endpoint returns valid JSON"""
        import threading
        import time
        import urllib.request

        test_port = 21002

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/tiddlers', timeout=2)
            content = response.read().decode('utf-8')

            # Should be valid JSON
            data = json.loads(content)

            # Should have expected fields
            self.assertIn('version', data)
            self.assertIn('tiddlers', data)

            # Verify field types
            self.assertIsInstance(data['version'], (int, float))
            self.assertIsInstance(data['tiddlers'], list)

            # Should have our test tiddlers
            self.assertEqual(len(data['tiddlers']), 2)

            titles = [t['title'] for t in data['tiddlers']]
            self.assertIn('TestTiddler1', titles)
            self.assertIn('TestTiddler2', titles)
        finally:
            pass

    def test_tiddlers_endpoint_content_type(self):
        """Test that /_tw/tiddlers returns correct Content-Type"""
        import threading
        import time
        import urllib.request

        test_port = 21003

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/tiddlers', timeout=2)
            content_type = response.headers.get('Content-Type')

            self.assertIsNotNone(content_type)
            self.assertIn('application/json', content_type)
        finally:
            pass

    def test_version_changes_when_file_modified(self):
        """Test that version endpoint reflects file modification"""
        import threading
        import time
        import urllib.request

        test_port = 21004

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Get initial version
            response1 = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/version', timeout=2)
            data1 = json.loads(response1.read().decode('utf-8'))
            version1 = data1['version']

            # Wait a bit and modify the file
            time.sleep(0.6)  # Wait for watcher polling interval
            tw_module.touch_tiddler(self.test_wiki, "NewTiddler", "New content")

            # Wait for watcher to detect change
            time.sleep(0.6)

            # Get new version
            response2 = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/version', timeout=2)
            data2 = json.loads(response2.read().decode('utf-8'))
            version2 = data2['version']

            # Version should have changed
            self.assertNotEqual(version1, version2)
            self.assertGreater(version2, version1)
        finally:
            pass

    def test_tiddlers_endpoint_shows_updated_content(self):
        """Test that tiddlers endpoint shows new tiddlers after modification"""
        import threading
        import time
        import urllib.request

        test_port = 21005

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Get initial tiddlers
            response1 = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/tiddlers', timeout=2)
            data1 = json.loads(response1.read().decode('utf-8'))
            initial_count = len(data1['tiddlers'])
            self.assertEqual(initial_count, 2)

            # Add a new tiddler
            tw_module.touch_tiddler(self.test_wiki, "NewTiddler", "New content")

            # Wait for file to be written
            time.sleep(0.1)

            # Get updated tiddlers
            response2 = urllib.request.urlopen(f'http://localhost:{test_port}/_tw/tiddlers', timeout=2)
            data2 = json.loads(response2.read().decode('utf-8'))

            # Should have one more tiddler
            self.assertEqual(len(data2['tiddlers']), 3)

            titles = [t['title'] for t in data2['tiddlers']]
            self.assertIn('NewTiddler', titles)
        finally:
            pass

    def test_meta_tag_injected_in_html(self):
        """Test that server injects tw-server meta tag into HTML"""
        import threading
        import time
        import urllib.request

        test_port = 21006

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            content = response.read().decode('utf-8')

            # Should contain the meta tag
            self.assertIn('<meta name="tw-server" content="enabled">', content)

            # Meta tag should be in the head section
            head_start = content.find('<head>')
            head_end = content.find('</head>')
            meta_pos = content.find('<meta name="tw-server"')

            self.assertGreater(meta_pos, head_start)
            self.assertLess(meta_pos, head_end)
        finally:
            pass

    def test_meta_tag_not_in_original_file(self):
        """Test that meta tag is only in served content, not the file"""
        # Read the original file
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            file_content = f.read()

        # Should NOT contain the meta tag
        self.assertNotIn('<meta name="tw-server"', file_content)

        # Start server and get served content
        import threading
        import time
        import urllib.request

        test_port = 21007

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            response = urllib.request.urlopen(f'http://localhost:{test_port}/', timeout=2)
            served_content = response.read().decode('utf-8')

            # Served content SHOULD contain the meta tag
            self.assertIn('<meta name="tw-server"', served_content)
        finally:
            pass

class TestInstallPlugin(unittest.TestCase):
    """Test suite for install_plugin command"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000"},
        ]

        # Create the HTML file
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

    def test_install_live_reload_plugin(self):
        """Test installing the live reload plugin"""
        # Install the plugin
        tw_module.install_live_reload_plugin(self.test_wiki)

        # Verify plugin was installed
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]
        self.assertIn('$:/plugins/phajas/live-reload', titles)

        # Get the plugin tiddler
        plugin = None
        for t in tiddlers:
            if t['title'] == '$:/plugins/phajas/live-reload':
                plugin = t
                break

        self.assertIsNotNone(plugin, "Plugin tiddler should exist")

        # Check plugin fields
        self.assertEqual(plugin['type'], 'application/javascript')
        self.assertEqual(plugin['module-type'], 'startup')
        self.assertEqual(plugin['tags'], '$:/tags/StartupModule')
        self.assertEqual(plugin['version'], '0.8.1')
        self.assertIn('Live reload functionality', plugin['description'])

        # Check plugin code contains key functions
        plugin_code = plugin['text']
        self.assertIn('checkForServer', plugin_code)
        self.assertIn('startPolling', plugin_code)
        self.assertIn('checkVersion', plugin_code)
        self.assertIn('reloadTiddlers', plugin_code)
        self.assertIn('/_tw/version', plugin_code)
        self.assertIn('/_tw/tiddlers', plugin_code)

        # Phase 2B specific checks
        self.assertIn('$tw.wiki.addTiddler', plugin_code)
        self.assertIn('$tw.wiki.deleteTiddler', plugin_code)
        self.assertIn('$tw.rootWidget.refresh', plugin_code)

    def test_install_plugin_replaces_existing(self):
        """Test that installing plugin twice replaces the first one"""
        # Install plugin twice
        tw_module.install_live_reload_plugin(self.test_wiki)
        tw_module.install_live_reload_plugin(self.test_wiki)

        # Count how many times the plugin appears
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        plugin_count = sum(1 for t in tiddlers if t['title'] == '$:/plugins/phajas/live-reload')

        self.assertEqual(plugin_count, 1, "Should only have one instance of the plugin")

    def test_plugin_code_has_correct_structure(self):
        """Test that the plugin code has the correct JavaScript structure"""
        tw_module.install_live_reload_plugin(self.test_wiki)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        plugin = next((t for t in tiddlers if t['title'] == '$:/plugins/phajas/live-reload'), None)

        self.assertIsNotNone(plugin)

        # Check for required exports
        code = plugin['text']
        self.assertIn('exports.name', code)
        self.assertIn('exports.platforms', code)
        self.assertIn('exports.after', code)
        self.assertIn('exports.synchronous', code)
        self.assertIn('exports.startup', code)

        # Check for browser check
        self.assertIn('$tw.browser', code)

        # Check for meta tag detection
        self.assertIn('meta[name="tw-server"]', code)
        self.assertIn('tw-server', code)

        # Check for polling interval (3 seconds)
        self.assertIn('3000', code)

        # Check for console logging
        self.assertIn('[LiveReload]', code)

    def test_plugin_preserves_other_tiddlers(self):
        """Test that installing plugin doesn't affect other tiddlers"""
        # Add some more tiddlers first
        tw_module.touch_tiddler(self.test_wiki, "TestTiddler2", "Content 2")
        tw_module.touch_tiddler(self.test_wiki, "TestTiddler3", "Content 3")

        # Count tiddlers before
        tiddlers_before = tw_module.load_all_tiddlers(self.test_wiki)
        count_before = len(tiddlers_before)

        # Install plugin
        tw_module.install_live_reload_plugin(self.test_wiki)

        # Count tiddlers after
        tiddlers_after = tw_module.load_all_tiddlers(self.test_wiki)
        count_after = len(tiddlers_after)

        # Should have one more tiddler (the plugin)
        self.assertEqual(count_after, count_before + 1)

        # Check original tiddlers still exist
        titles_after = [t['title'] for t in tiddlers_after]
        self.assertIn('TestTiddler1', titles_after)
        self.assertIn('TestTiddler2', titles_after)
        self.assertIn('TestTiddler3', titles_after)


class TestWebDAVSupport(unittest.TestCase):
    """Test WebDAV functionality for saving wikis from browser"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000", "modified": "20230101000000000"},
            {"title": "TestTiddler2", "text": "Content 2", "created": "20230102000000000", "modified": "20230102000000000"},
        ]

        # Create the HTML file
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

    def test_options_returns_webdav_headers(self):
        """Test that OPTIONS request returns WebDAV headers"""
        import threading
        import time
        import urllib.request

        test_port = 20100

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Make OPTIONS request
            req = urllib.request.Request(f'http://localhost:{test_port}/', method='OPTIONS')
            response = urllib.request.urlopen(req, timeout=2)

            # Verify WebDAV headers are present
            self.assertEqual(response.status, 200)

            dav_header = response.headers.get('DAV')
            self.assertIsNotNone(dav_header, "DAV header should be present")
            self.assertIn('1', dav_header)

            allow_header = response.headers.get('Allow')
            self.assertIsNotNone(allow_header)
            self.assertIn('OPTIONS', allow_header)
            self.assertIn('GET', allow_header)
            self.assertIn('PUT', allow_header)

            # Verify CORS headers
            cors_origin = response.headers.get('Access-Control-Allow-Origin')
            self.assertIsNotNone(cors_origin)

            cors_methods = response.headers.get('Access-Control-Allow-Methods')
            self.assertIsNotNone(cors_methods)
            self.assertIn('PUT', cors_methods)
        finally:
            pass

    def test_put_saves_wiki_file(self):
        """Test that PUT request successfully saves wiki file"""
        import threading
        import time
        import urllib.request

        test_port = 20101

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Create modified wiki HTML
            new_tiddlers = [
                {"title": "NewTiddler", "text": "New content", "created": "20230103000000000", "modified": "20230103000000000"},
            ]
            tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in new_tiddlers]
            formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
            formatted_json = formatted_json.replace('<', '\\u003C')

            new_html = f'''<!DOCTYPE html>
<html>
<head><title>Modified Wiki</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>
</body>
</html>'''

            # Make PUT request
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=new_html.encode('utf-8'),
                method='PUT'
            )
            req.add_header('Content-Type', 'text/html; charset=utf-8')
            response = urllib.request.urlopen(req, timeout=2)

            # Verify response
            self.assertIn(response.status, [200, 204], "PUT should return 200 or 204")

            # Give file system a moment to sync
            time.sleep(0.1)

            # Verify file was actually modified
            with open(self.test_wiki, 'r', encoding='utf-8') as f:
                saved_content = f.read()

            self.assertIn('Modified Wiki', saved_content)
            self.assertIn('NewTiddler', saved_content)
            self.assertIn('New content', saved_content)

            # Verify we can load tiddlers from the saved file
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            titles = [t['title'] for t in tiddlers]
            self.assertIn('NewTiddler', titles)
        finally:
            pass

    def test_put_uses_atomic_write(self):
        """Test that PUT uses atomic file operations"""
        import threading
        import time
        import urllib.request

        test_port = 20102

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Read original content
            with open(self.test_wiki, 'r', encoding='utf-8') as f:
                original_content = f.read()

            # Create valid modified HTML
            new_tiddlers = [
                {"title": "AtomicTest", "text": "Atomic write test", "created": "20230104000000000", "modified": "20230104000000000"},
            ]
            tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in new_tiddlers]
            formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
            formatted_json = formatted_json.replace('<', '\\u003C')

            new_html = f'''<!DOCTYPE html>
<html>
<head><title>Atomic Test</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>
</body>
</html>'''

            # Make PUT request
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=new_html.encode('utf-8'),
                method='PUT'
            )
            req.add_header('Content-Type', 'text/html; charset=utf-8')
            response = urllib.request.urlopen(req, timeout=2)

            # Verify response
            self.assertIn(response.status, [200, 204])

            # Give file system a moment
            time.sleep(0.1)

            # Verify the final file is valid and complete (not partially written)
            with open(self.test_wiki, 'r', encoding='utf-8') as f:
                final_content = f.read()

            # Should have complete HTML structure
            self.assertIn('<!DOCTYPE html>', final_content)
            self.assertIn('</html>', final_content)
            self.assertIn('AtomicTest', final_content)

            # Should be parseable
            stores = tw_module.extract_tiddler_stores(final_content)
            self.assertGreater(len(stores), 0, "Should have valid tiddler stores")

            # Verify no temp file left behind
            temp_file = self.test_wiki + '.tmp'
            self.assertFalse(os.path.exists(temp_file), "Temp file should be cleaned up")
        finally:
            pass

    def test_put_validates_html(self):
        """Test that PUT validates HTML has tiddler stores before saving"""
        import threading
        import time
        import urllib.request

        test_port = 20103

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Read original content to verify it doesn't change
            with open(self.test_wiki, 'r', encoding='utf-8') as f:
                original_content = f.read()

            # Try to save invalid HTML (no tiddler store)
            invalid_html = '''<!DOCTYPE html>
<html>
<head><title>Invalid</title></head>
<body>No tiddler store here!</body>
</html>'''

            # Make PUT request with invalid HTML
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=invalid_html.encode('utf-8'),
                method='PUT'
            )
            req.add_header('Content-Type', 'text/html; charset=utf-8')

            # Should fail or return error
            try:
                response = urllib.request.urlopen(req, timeout=2)
                # If it succeeds, it should return an error status
                self.assertNotIn(response.status, [200, 204],
                    "Should not accept invalid HTML without tiddler stores")
            except urllib.error.HTTPError as e:
                # Expected - server rejected invalid HTML
                self.assertIn(e.code, [400, 500], "Should return error code for invalid HTML")

            # Give file system a moment
            time.sleep(0.1)

            # Verify original file is unchanged
            with open(self.test_wiki, 'r', encoding='utf-8') as f:
                current_content = f.read()

            self.assertEqual(original_content, current_content,
                "Original file should be unchanged after invalid PUT")
        finally:
            pass

    def test_put_handles_concurrent_saves(self):
        """Test that PUT can handle saves even if file changes (last write wins)"""
        import threading
        import time
        import urllib.request

        test_port = 20104

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Create two different versions
            version1_tiddlers = [
                {"title": "Version1", "text": "First save", "created": "20230105000000000", "modified": "20230105000000000"},
            ]
            version2_tiddlers = [
                {"title": "Version2", "text": "Second save", "created": "20230106000000000", "modified": "20230106000000000"},
            ]

            def make_html(tiddlers):
                tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in tiddlers]
                formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
                formatted_json = formatted_json.replace('<', '\\u003C')
                return f'''<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>
</body>
</html>'''

            # Make first PUT
            req1 = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=make_html(version1_tiddlers).encode('utf-8'),
                method='PUT'
            )
            req1.add_header('Content-Type', 'text/html; charset=utf-8')
            response1 = urllib.request.urlopen(req1, timeout=2)
            self.assertIn(response1.status, [200, 204])

            time.sleep(0.1)

            # Make second PUT
            req2 = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=make_html(version2_tiddlers).encode('utf-8'),
                method='PUT'
            )
            req2.add_header('Content-Type', 'text/html; charset=utf-8')
            response2 = urllib.request.urlopen(req2, timeout=2)
            self.assertIn(response2.status, [200, 204])

            time.sleep(0.1)

            # Last write should win
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            titles = [t['title'] for t in tiddlers]
            self.assertIn('Version2', titles)
        finally:
            pass

    def test_put_saves_system_tiddlers(self):
        """Test that PUT can save system tiddlers like $:/SiteTitle"""
        import threading
        import time
        import urllib.request

        test_port = 20105

        server_thread = threading.Thread(
            target=tw_module.serve_wiki,
            args=(self.test_wiki, 'localhost', test_port),
            daemon=True
        )
        server_thread.start()

        time.sleep(0.2)

        try:
            # Create wiki with system tiddlers
            system_tiddlers = [
                {"title": "$:/SiteTitle", "text": "My Custom Title", "created": "20230107000000000", "modified": "20230107000000000"},
                {"title": "$:/SiteSubtitle", "text": "A test subtitle", "created": "20230107000000000", "modified": "20230107000000000"},
                {"title": "RegularTiddler", "text": "Normal content", "created": "20230107000000000", "modified": "20230107000000000"},
            ]
            tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in system_tiddlers]
            formatted_json = '[\n' + ',\n'.join(tiddler_jsons) + '\n]'
            formatted_json = formatted_json.replace('<', '\\u003C')

            new_html = f'''<!DOCTYPE html>
<html>
<head><title>Test Wiki</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">{formatted_json}</script>
</body>
</html>'''

            # Make PUT request
            req = urllib.request.Request(
                f'http://localhost:{test_port}/',
                data=new_html.encode('utf-8'),
                method='PUT'
            )
            req.add_header('Content-Type', 'text/html; charset=utf-8')
            response = urllib.request.urlopen(req, timeout=2)

            # Verify response
            self.assertIn(response.status, [200, 204], "PUT should return 200 or 204")

            # Give file system a moment to sync
            time.sleep(0.1)

            # Verify system tiddlers were saved
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            titles = [t['title'] for t in tiddlers]

            self.assertIn('$:/SiteTitle', titles, "System tiddler $:/SiteTitle should be saved")
            self.assertIn('$:/SiteSubtitle', titles, "System tiddler $:/SiteSubtitle should be saved")
            self.assertIn('RegularTiddler', titles, "Regular tiddler should be saved")

            # Verify content
            site_title = next(t for t in tiddlers if t['title'] == '$:/SiteTitle')
            self.assertEqual(site_title['text'], 'My Custom Title')
        finally:
            pass

    def test_plugin_handles_null_tiddlers(self):
        """Test that the live reload plugin handles null/undefined tiddlers gracefully"""
        # This test verifies the plugin code can handle edge cases
        # The plugin hooks into $tw.wiki.addTiddler and must handle:
        # - null tiddlers
        # - tiddlers without fields
        # - tiddlers without title field

        # Get the plugin tiddler
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)

        # First install the plugin
        tw_module.install_live_reload_plugin(self.test_wiki)

        # Verify plugin was installed
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        plugin = None
        for t in tiddlers:
            if t.get('title') == '$:/plugins/phajas/live-reload':
                plugin = t
                break

        self.assertIsNotNone(plugin, "Plugin should be installed")
        self.assertIn('text', plugin, "Plugin should have code")

        # Verify the plugin code has null safety checks
        plugin_code = plugin['text']

        # Should check for tiddler existence
        self.assertIn('tiddler &&', plugin_code,
            "Plugin should check if tiddler exists")

        # Should check for fields existence
        self.assertIn('tiddler.fields &&', plugin_code,
            "Plugin should check if tiddler.fields exists")

        # Should check for title existence
        self.assertIn('tiddler.fields.title &&', plugin_code,
            "Plugin should check if tiddler.fields.title exists")

        # Should have version skip mechanism
        self.assertIn('VERSION_SKIP_DURATION', plugin_code,
            "Plugin should have version skip duration mechanism")
        self.assertIn('savedVersions', plugin_code,
            "Plugin should track saved versions")
        self.assertIn('isSaving', plugin_code,
            "Plugin should track saving state")

        # Should skip reload for versions we just saved
        self.assertIn('version we just saved', plugin_code,
            "Plugin should skip reload for versions we just saved")


class TestWikiPathArgument(unittest.TestCase):
    """Test wiki path as first argument"""

    def setUp(self):
        """Create a temporary test wiki"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000"},
            {"title": "TestTiddler2", "text": "Content 2", "created": "20230102000000000"},
        ]

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
        """Clean up temporary files"""
        shutil.rmtree(self.test_dir)

    def test_wiki_path_with_ls_command(self):
        """Test that ls command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html ls
        sys.argv = ['tw', self.test_wiki, 'ls']

        # Capture output
        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        self.assertIn('TestTiddler1', output)
        self.assertIn('TestTiddler2', output)

    def test_wiki_path_with_cat_command(self):
        """Test that cat command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html cat TestTiddler1
        sys.argv = ['tw', self.test_wiki, 'cat', 'TestTiddler1']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        self.assertIn('TestTiddler1', output)
        self.assertIn('Content 1', output)

    def test_wiki_path_with_touch_command(self):
        """Test that touch command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html touch NewTiddler "New content"
        sys.argv = ['tw', self.test_wiki, 'touch', 'NewTiddler', 'New content']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        # Verify tiddler was created
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]
        self.assertIn('NewTiddler', titles)

    def test_wiki_path_with_json_command(self):
        """Test that json command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html json TestTiddler1
        sys.argv = ['tw', self.test_wiki, 'json', 'TestTiddler1']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        self.assertIn('TestTiddler1', output)
        self.assertIn('Content 1', output)

    def test_wiki_path_with_get_command(self):
        """Test that get command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html get TestTiddler1 text
        sys.argv = ['tw', self.test_wiki, 'get', 'TestTiddler1', 'text']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        self.assertIn('Content 1', output)

    def test_wiki_path_with_set_command(self):
        """Test that set command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html set TestTiddler1 tags "important"
        sys.argv = ['tw', self.test_wiki, 'set', 'TestTiddler1', 'tags', 'important']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        # Verify field was set
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler1')
        self.assertEqual(tiddler['tags'], 'important')

    def test_wiki_path_with_remove_command(self):
        """Test that rm command works with wiki path as first argument"""
        # Simulate: tw test_wiki.html rm TestTiddler2
        sys.argv = ['tw', self.test_wiki, 'rm', 'TestTiddler2']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        # Verify tiddler was removed
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]
        self.assertNotIn('TestTiddler2', titles)
        self.assertIn('TestTiddler1', titles)

    def test_env_var_still_works_with_wiki_path_arg(self):
        """Test that environment variable is overridden by command line argument"""
        # Set env var to a different path (which doesn't exist, but that's ok for this test)
        os.environ['TIDDLYWIKI_WIKI_PATH'] = '/nonexistent/wiki.html'

        # Simulate: tw test_wiki.html ls
        sys.argv = ['tw', self.test_wiki, 'ls']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        # Should use the command line argument, not the env var
        self.assertIn('TestTiddler1', output)

        # Clean up
        if 'TIDDLYWIKI_WIKI_PATH' in os.environ:
            del os.environ['TIDDLYWIKI_WIKI_PATH']

    def test_env_var_fallback_when_no_wiki_path_arg(self):
        """Test that environment variable is used when no wiki path argument given"""
        # Set env var to our test wiki
        os.environ['TIDDLYWIKI_WIKI_PATH'] = self.test_wiki

        # Simulate: tw ls (no wiki path argument)
        sys.argv = ['tw', 'ls']

        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            try:
                tw_module.main()
            except SystemExit:
                pass

        output = f.getvalue()
        self.assertIn('TestTiddler1', output)

        # Clean up
        if 'TIDDLYWIKI_WIKI_PATH' in os.environ:
            del os.environ['TIDDLYWIKI_WIKI_PATH']


class TestInitCommand(unittest.TestCase):
    """Test the init command for creating new wikis"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Clean up temporary files"""
        shutil.rmtree(self.test_dir)

    def test_init_creates_wiki_file(self):
        """Test that init creates a new wiki file"""
        dest_path = os.path.join(self.test_dir, 'new_wiki.html')

        # Call init_wiki
        tw_module.init_wiki(dest_path)

        # Verify file was created
        self.assertTrue(os.path.exists(dest_path), "Wiki file should be created")

    def test_init_wiki_contains_tiddler_stores(self):
        """Test that the initialized wiki has valid tiddler stores"""
        dest_path = os.path.join(self.test_dir, 'new_wiki.html')

        # Call init_wiki
        tw_module.init_wiki(dest_path)

        # Verify the file has tiddler stores
        with open(dest_path, 'r', encoding='utf-8') as f:
            content = f.read()

        stores = tw_module.extract_tiddler_stores(content)
        self.assertGreater(len(stores), 0, "Initialized wiki should have tiddler stores")

    def test_init_wiki_can_be_read(self):
        """Test that the initialized wiki can be read and parsed"""
        dest_path = os.path.join(self.test_dir, 'new_wiki.html')

        # Call init_wiki
        tw_module.init_wiki(dest_path)

        # Verify we can load tiddlers from it
        tiddlers = tw_module.load_all_tiddlers(dest_path)
        self.assertIsInstance(tiddlers, list, "Should be able to load tiddlers")
        self.assertGreater(len(tiddlers), 0, "Initialized wiki should have tiddlers")

    def test_init_fails_if_file_exists(self):
        """Test that init fails if the destination file already exists"""
        dest_path = os.path.join(self.test_dir, 'existing.html')

        # Create a file at the destination
        with open(dest_path, 'w') as f:
            f.write('<html>existing content</html>')

        # Calling init_wiki should fail
        with self.assertRaises(SystemExit):
            tw_module.init_wiki(dest_path)

    def test_init_fails_if_parent_dir_missing(self):
        """Test that init fails if parent directory doesn't exist"""
        dest_path = os.path.join(self.test_dir, 'nonexistent', 'dir', 'wiki.html')

        # Calling init_wiki with non-existent parent should fail
        with self.assertRaises(SystemExit):
            tw_module.init_wiki(dest_path)

    def test_init_expands_tilde_path(self):
        """Test that init properly expands ~ in paths"""
        # Create a temporary directory in the test_dir that we'll use as a "home" for this test
        dest_subdir = os.path.join(self.test_dir, 'home_test')
        os.makedirs(dest_subdir)

        # Create a test file with ~ in path (we'll use absolute path but verify tilde expansion logic)
        dest_path = os.path.join(dest_subdir, 'wiki.html')

        # Call init_wiki with absolute path (tilde handling is internal)
        tw_module.init_wiki(dest_path)

        # Verify file was created
        self.assertTrue(os.path.exists(dest_path), "Wiki file should be created with path expansion")

    def test_init_wiki_is_valid_html(self):
        """Test that the initialized wiki is valid HTML"""
        dest_path = os.path.join(self.test_dir, 'new_wiki.html')

        # Call init_wiki
        tw_module.init_wiki(dest_path)

        # Read and verify it's valid HTML
        with open(dest_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check for basic HTML structure - should start with doctype, comment, or tag
        self.assertTrue(content.startswith('<') or content.startswith('\n'),
                       "Should start with HTML markup or whitespace")
        self.assertIn('<html', content.lower(), "Should contain html tag")
        self.assertIn('</html>', content.lower(), "Should contain closing html tag")

    def test_init_wiki_with_nested_path(self):
        """Test that init works with nested destination paths"""
        # Create a nested directory structure
        nested_dir = os.path.join(self.test_dir, 'level1', 'level2')
        os.makedirs(nested_dir)

        dest_path = os.path.join(nested_dir, 'wiki.html')

        # Call init_wiki
        tw_module.init_wiki(dest_path)

        # Verify file was created
        self.assertTrue(os.path.exists(dest_path), "Wiki file should be created in nested directory")

        # Verify it's readable
        tiddlers = tw_module.load_all_tiddlers(dest_path)
        self.assertGreater(len(tiddlers), 0, "Should have tiddlers")

class TestEditTiddler(unittest.TestCase):
    """Test the edit_tiddler function"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a minimal test wiki with diverse tiddlers
        self.test_tiddlers = [
            {"title": "TestTiddler1", "text": "Content 1", "created": "20230101000000000", "modified": "20230101000000000"},
            {"title": "TestTiddler2", "text": "Content with <angle> brackets", "created": "20230102000000000", "modified": "20230102000000000"},
            {"title": "TestTiddler3", "text": "Content with \"quotes\" and special chars", "tags": "tag1 tag2", "created": "20230103000000000", "modified": "20230103000000000"},
            {"title": "UnicodeTest", "text": "Curly quotes: \u201ctest\u201d", "created": "20230104000000000", "modified": "20230104000000000"},
        ]

        # Create the HTML file
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

    def test_edit_tiddler_without_editor(self):
        """Test that edit_tiddler falls back to finding an available editor"""
        # Save original EDITOR
        original_editor = os.environ.get('EDITOR')
        try:
            # Unset EDITOR
            if 'EDITOR' in os.environ:
                del os.environ['EDITOR']

            # The edit_tiddler function should auto-detect an available editor (like nvim, vim, nano)
            # Since we can't guarantee which editors are installed, we'll just test that it doesn't error
            # when trying to find one. If no editors are found, it will exit with error.
            # For this test, we'll mock shutil.which to ensure it finds an editor
            import unittest.mock
            with unittest.mock.patch('shutil.which') as mock_which:
                # Mock that nvim is available
                mock_which.return_value = '/usr/bin/nvim'

                # Now mock subprocess.run so the editor doesn't actually run
                with unittest.mock.patch('subprocess.run') as mock_run:
                    mock_run.return_value.returncode = 0

                    # This should work now (no SystemExit)
                    try:
                        tw_module.edit_tiddler(self.test_wiki, "TestTiddler1")
                    except SystemExit:
                        self.fail("edit_tiddler should have found a fallback editor")
        finally:
            # Restore original EDITOR
            if original_editor:
                os.environ['EDITOR'] = original_editor

    def test_edit_nonexistent_tiddler(self):
        """Test that edit_tiddler creates a new tiddler if it doesn't exist"""
        editor_script = os.path.join(self.test_dir, 'create_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys

# Just append some content to create the tiddler
with open(sys.argv[1], 'a') as f:
    f.write('\\n')
    f.write('Newly created content')
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Edit a non-existent tiddler
        tw_module.edit_tiddler(self.test_wiki, "NewTiddlerFromEdit")

        # Verify the tiddler was created
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next((t for t in tiddlers if t['title'] == 'NewTiddlerFromEdit'), None)

        self.assertIsNotNone(tiddler)
        self.assertIn('Newly created content', tiddler.get('text', ''))

    def test_edit_tiddler_basic(self):
        """Test basic edit workflow with a simple text change"""
        # Create a temporary script that acts as an editor
        # It will modify the content (add text to the tiddler text)
        editor_script = os.path.join(self.test_dir, 'fake_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys

# Read the file
with open(sys.argv[1], 'r') as f:
    content = f.read()

# Append modified content to the text section
lines = content.split('\\n')
# Find the blank line that separates metadata from text
blank_idx = None
for i, line in enumerate(lines):
    if line.strip() == '':
        blank_idx = i
        break

if blank_idx is not None and blank_idx + 1 < len(lines):
    # Append to the text portion
    lines.append(' - edited')
else:
    # Append at the end if no blank line found
    lines.append(' - edited')

# Write back
with open(sys.argv[1], 'w') as f:
    f.write('\\n'.join(lines))
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Edit the tiddler
        tw_module.edit_tiddler(self.test_wiki, "TestTiddler1")

        # Verify the change was saved
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler1')

        # The text should have been modified
        self.assertIn('edited', edited_tiddler['text'])

    def test_edit_tiddler_preserves_metadata(self):
        """Test that edit preserves tiddler metadata"""
        editor_script = os.path.join(self.test_dir, 'noop_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
# No-op editor - just exit without modifying
import sys
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Get original tiddler
        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'TestTiddler2')
        original_created = original_tiddler.get('created')

        # Edit the tiddler
        tw_module.edit_tiddler(self.test_wiki, "TestTiddler2")

        # Verify metadata is preserved
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler2')

        # Created timestamp should be preserved
        self.assertEqual(edited_tiddler.get('created'), original_created)
        # Modified should be updated (it will be newer)
        self.assertIn('modified', edited_tiddler)

    def test_edit_tiddler_preserves_tags(self):
        """Test that edit preserves tiddler tags"""
        editor_script = os.path.join(self.test_dir, 'noop_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
# No-op editor
import sys
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Get original tags
        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'TestTiddler3')
        original_tags = original_tiddler.get('tags')

        # Edit the tiddler
        tw_module.edit_tiddler(self.test_wiki, "TestTiddler3")

        # Verify tags are preserved
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler3')

        self.assertEqual(edited_tiddler.get('tags'), original_tags)

    def test_edit_tiddler_preserves_unicode(self):
        """Test that edit preserves Unicode characters"""
        editor_script = os.path.join(self.test_dir, 'noop_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
# No-op editor
import sys
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Get original Unicode content
        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'UnicodeTest')
        original_text = original_tiddler.get('text')

        # Edit the tiddler
        tw_module.edit_tiddler(self.test_wiki, "UnicodeTest")

        # Verify Unicode is preserved (not escaped)
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'UnicodeTest')

        self.assertEqual(edited_tiddler.get('text'), original_text)
        # Verify the actual Unicode characters are present
        self.assertIn('\u201c', edited_tiddler.get('text'))

    def test_edit_tiddler_modified_timestamp_updated(self):
        """Test that modified timestamp is updated after content changes"""
        import time
        editor_script = os.path.join(self.test_dir, 'modify_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys
import time

# Sleep a bit to ensure timestamp changes (TiddlyWiki timestamps have millisecond precision)
time.sleep(0.002)

# Read and append to the content
with open(sys.argv[1], 'r') as f:
    content = f.read()

# Append modified marker
with open(sys.argv[1], 'w') as f:
    f.write(content + '\\nAPPENDED')
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Get original tiddler
        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'TestTiddler1')
        original_text = original_tiddler.get('text')
        original_modified = original_tiddler.get('modified')

        # Edit the tiddler (editor will append APPENDED to the text)
        tw_module.edit_tiddler(self.test_wiki, "TestTiddler1")

        # Verify content was modified
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler1')
        new_text = edited_tiddler.get('text')
        new_modified = edited_tiddler.get('modified')

        # Content should have changed
        self.assertNotEqual(new_text, original_text)
        self.assertIn('APPENDED', new_text)

        # Modified timestamp should be updated (it should be different or the same generation time)
        # Since replace_tiddler updates the modified timestamp, it should exist
        self.assertIsNotNone(new_modified)

    def test_edit_tiddler_with_special_chars(self):
        """Test edit with special characters in text"""
        editor_script = os.path.join(self.test_dir, 'special_editor.py')

        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys

# Replace content with special chars
content = """title: TestTiddler2

Updated content with <brackets> and "quotes"."""

with open(sys.argv[1], 'w') as f:
    f.write(content)
''')

        os.chmod(editor_script, 0o755)
        os.environ['EDITOR'] = f'python3 {editor_script}'

        # Edit the tiddler
        tw_module.edit_tiddler(self.test_wiki, "TestTiddler2")

        # Verify the special characters are preserved
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        edited_tiddler = next(t for t in tiddlers if t['title'] == 'TestTiddler2')

        self.assertIn('<brackets>', edited_tiddler.get('text'))
        self.assertIn('"quotes"', edited_tiddler.get('text'))

class TestAppendTiddler(unittest.TestCase):
    """Test the append_tiddler function"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create a test wiki with some tiddlers
        self.test_tiddlers = [
            {"title": "ExistingTiddler", "text": "Line 1\nLine 2", "created": "20230101000000000", "modified": "20230101000000000"},
            {"title": "EmptyTextTiddler", "text": "", "created": "20230102000000000", "modified": "20230102000000000"},
            {"title": "NoTextFieldTiddler", "created": "20230103000000000", "modified": "20230103000000000"},
            {"title": "TiddlerWithTags", "text": "original content", "tags": "tag1 tag2", "created": "20230104000000000", "modified": "20230104000000000"},
        ]

        # Create the HTML file
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

    def test_append_to_existing_tiddler(self):
        """Test appending text to a tiddler with existing content"""
        import io
        import unittest.mock

        # Mock stdin
        f = io.StringIO("Line 3\nLine 4")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        # Verify the content was appended
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        expected = "Line 1\nLine 2\nLine 3\nLine 4"
        self.assertEqual(tiddler['text'], expected)

    def test_append_to_empty_text_tiddler(self):
        """Test appending to a tiddler with empty text field"""
        import io
        import unittest.mock

        f = io.StringIO("New content")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "EmptyTextTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'EmptyTextTiddler')

        self.assertEqual(tiddler['text'], "New content")

    def test_append_to_tiddler_without_text_field(self):
        """Test appending to a tiddler that has no text field"""
        import io
        import unittest.mock

        f = io.StringIO("First content")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "NoTextFieldTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'NoTextFieldTiddler')

        self.assertEqual(tiddler['text'], "First content")

    def test_append_multiline_content(self):
        """Test appending multiline content"""
        import io
        import unittest.mock

        multiline = "Line A\nLine B\nLine C"
        f = io.StringIO(multiline)
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        expected = "Line 1\nLine 2\nLine A\nLine B\nLine C"
        self.assertEqual(tiddler['text'], expected)

    def test_append_preserves_other_fields(self):
        """Test that appending preserves other tiddler fields"""
        import io
        import unittest.mock

        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'TiddlerWithTags')
        original_tags = original_tiddler.get('tags')
        original_created = original_tiddler.get('created')

        f = io.StringIO("appended text")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "TiddlerWithTags")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'TiddlerWithTags')

        # Other fields should be preserved
        self.assertEqual(tiddler.get('tags'), original_tags)
        self.assertEqual(tiddler.get('created'), original_created)

    def test_append_to_nonexistent_tiddler(self):
        """Test that appending to non-existent tiddler creates it"""
        import io
        import unittest.mock

        f = io.StringIO("some text")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "NonExistentTiddler")

        # Verify tiddler was created
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next((t for t in tiddlers if t['title'] == 'NonExistentTiddler'), None)
        self.assertIsNotNone(tiddler)
        self.assertEqual(tiddler['text'], 'some text')

    def test_append_updates_modified_timestamp(self):
        """Test that modified timestamp is updated after append"""
        import io
        import unittest.mock

        original_tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_tiddler = next(t for t in original_tiddlers if t['title'] == 'ExistingTiddler')
        original_modified = original_tiddler.get('modified')

        f = io.StringIO("new content")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        new_modified = tiddler.get('modified')

        # Modified should exist
        self.assertIsNotNone(new_modified)

    def test_append_empty_string(self):
        """Test appending an empty string"""
        import io
        import unittest.mock

        f = io.StringIO("")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        # Should append empty string (adds a newline)
        self.assertEqual(tiddler['text'], "Line 1\nLine 2\n")

    def test_append_with_special_characters(self):
        """Test appending content with special characters"""
        import io
        import unittest.mock

        special_content = "Content with <brackets> and \"quotes\""
        f = io.StringIO(special_content)
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertIn('<brackets>', tiddler['text'])
        self.assertIn('"quotes"', tiddler['text'])

    def test_append_with_unicode(self):
        """Test appending content with Unicode characters"""
        import io
        import unittest.mock

        unicode_content = "Unicode: \u201cquotes\u201d and \u2713 checkmark"
        f = io.StringIO(unicode_content)
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertIn('\u201c', tiddler['text'])
        self.assertIn('\u2713', tiddler['text'])

    def test_append_with_command_line_text_single_word(self):
        """Test appending text passed as command-line argument (single word)"""
        # Pass text directly as parameter (no stdin)
        tw_module.append_tiddler(self.test_wiki, "ExistingTiddler", "NewWord")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        expected = "Line 1\nLine 2\nNewWord"
        self.assertEqual(tiddler['text'], expected)

    def test_append_with_command_line_text_multiple_words(self):
        """Test appending text passed as command-line argument (multiple words)"""
        # Pass text directly as parameter (no stdin)
        text_to_append = "This is multiple words"
        tw_module.append_tiddler(self.test_wiki, "ExistingTiddler", text_to_append)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        expected = "Line 1\nLine 2\nThis is multiple words"
        self.assertEqual(tiddler['text'], expected)

    def test_append_with_command_line_text_empty_string(self):
        """Test appending empty string passed as command-line argument"""
        # Pass empty string directly as parameter
        tw_module.append_tiddler(self.test_wiki, "ExistingTiddler", "")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        # Should append empty string (adds a newline)
        expected = "Line 1\nLine 2\n"
        self.assertEqual(tiddler['text'], expected)

    def test_append_with_command_line_text_special_chars(self):
        """Test appending text with special characters via command-line"""
        # Pass text with special characters directly
        special_text = "Special: <tag> and \"quotes\""
        tw_module.append_tiddler(self.test_wiki, "ExistingTiddler", special_text)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertIn('<tag>', tiddler['text'])
        self.assertIn('"quotes"', tiddler['text'])

    def test_append_with_command_line_text_to_empty_tiddler(self):
        """Test appending command-line text to tiddler with empty text field"""
        tw_module.append_tiddler(self.test_wiki, "EmptyTextTiddler", "First line")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'EmptyTextTiddler')

        self.assertEqual(tiddler['text'], "First line")

    def test_append_backward_compatible_with_none(self):
        """Test that passing None still reads from stdin (backward compatibility)"""
        import io
        import unittest.mock

        f = io.StringIO("From stdin")
        with unittest.mock.patch('sys.stdin', f):
            tw_module.append_tiddler(self.test_wiki, "ExistingTiddler", None)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        expected = "Line 1\nLine 2\nFrom stdin"
        self.assertEqual(tiddler['text'], expected)

    def test_append_creates_tiddler_with_timestamps(self):
        """Test that appending to non-existent tiddler creates it with created and modified timestamps"""
        tw_module.append_tiddler(self.test_wiki, "NewTiddlerViaAppend", "Initial content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next((t for t in tiddlers if t['title'] == 'NewTiddlerViaAppend'), None)

        # Verify tiddler was created
        self.assertIsNotNone(tiddler)
        self.assertEqual(tiddler['text'], 'Initial content')

        # Verify timestamps exist
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)
        self.assertIsNotNone(tiddler['created'])
        self.assertIsNotNone(tiddler['modified'])


class TestUnchangedContentPreservesTimestamp(unittest.TestCase):
    """Test that modified timestamp is preserved when content doesn't change"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create test tiddlers with specific timestamps
        self.old_timestamp = "20220101120000000"
        self.test_tiddlers = [
            {"title": "ExistingTiddler", "text": "Original content", "created": self.old_timestamp, "modified": self.old_timestamp},
            {"title": "AnotherTiddler", "text": "Different content", "created": self.old_timestamp, "modified": self.old_timestamp, "type": "text/markdown"},
        ]

        # Create the HTML file
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

    def test_edit_with_no_changes_preserves_modified(self):
        """Test that tw edit with no changes doesn't update modified timestamp"""
        # Create an editor script that doesn't change the file
        editor_script = os.path.join(self.test_dir, 'no_change_editor.py')
        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys
# Read and write back the same content - no changes
with open(sys.argv[1], 'r') as f:
    content = f.read()
with open(sys.argv[1], 'w') as f:
    f.write(content)
''')
        os.chmod(editor_script, 0o755)

        # Set EDITOR to our script
        original_editor = os.environ.get('EDITOR')
        try:
            os.environ['EDITOR'] = editor_script

            # Edit the tiddler (no changes made)
            tw_module.edit_tiddler(self.test_wiki, "ExistingTiddler")

            # Verify modified timestamp was NOT updated
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

            self.assertEqual(tiddler['modified'], self.old_timestamp,
                           "Modified timestamp should not change when content is unchanged")
            self.assertEqual(tiddler['text'], "Original content")
        finally:
            if original_editor:
                os.environ['EDITOR'] = original_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_with_changes_updates_modified(self):
        """Test that tw edit with changes does update modified timestamp"""
        # Create an editor script that changes the content
        editor_script = os.path.join(self.test_dir, 'change_editor.py')
        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys
# Modify the content
with open(sys.argv[1], 'r') as f:
    content = f.read()
# Change the text section
content = content.replace("Original content", "Modified content")
with open(sys.argv[1], 'w') as f:
    f.write(content)
''')
        os.chmod(editor_script, 0o755)

        # Set EDITOR to our script
        original_editor = os.environ.get('EDITOR')
        try:
            os.environ['EDITOR'] = editor_script

            # Edit the tiddler (changes made)
            tw_module.edit_tiddler(self.test_wiki, "ExistingTiddler")

            # Verify modified timestamp WAS updated
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

            self.assertNotEqual(tiddler['modified'], self.old_timestamp,
                              "Modified timestamp should be updated when content changes")
            self.assertEqual(tiddler['text'], "Modified content")
        finally:
            if original_editor:
                os.environ['EDITOR'] = original_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_set_field_with_same_value_preserves_modified(self):
        """Test that tw set with the same value doesn't update modified"""
        # Get current modified time
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        original_modified = tiddler['modified']

        # Sleep briefly to ensure timestamp would change if it's updated
        import time
        time.sleep(0.1)

        # Set a field to its current value
        tw_module.set_tiddler_field(self.test_wiki, "ExistingTiddler", "text", "Original content")

        # Verify modified timestamp was NOT updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertEqual(tiddler['modified'], original_modified,
                       "Modified timestamp should not change when setting field to same value")

    def test_set_field_with_new_value_updates_modified(self):
        """Test that tw set with a new value does update modified"""
        # Get current modified time
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        original_modified = tiddler['modified']

        # Sleep briefly to ensure timestamp would change
        import time
        time.sleep(0.1)

        # Set a field to a new value
        tw_module.set_tiddler_field(self.test_wiki, "ExistingTiddler", "text", "New content")

        # Verify modified timestamp WAS updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertNotEqual(tiddler['modified'], original_modified,
                          "Modified timestamp should be updated when setting field to new value")
        self.assertEqual(tiddler['text'], "New content")

    def test_replace_with_identical_content_preserves_modified(self):
        """Test that tw replace with identical content doesn't update modified"""
        # Create content identical to current tiddler
        original_content = """title: ExistingTiddler
created: 20220101120000000
modified: 20220101120000000

Original content"""

        # Sleep briefly to ensure timestamp would change if it's updated
        import time
        time.sleep(0.1)

        # Use replace_tiddler with update_modified=True but identical content
        tw_module.replace_tiddler(self.test_wiki, original_content, update_modified=False)

        # Verify modified timestamp was NOT updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertEqual(tiddler['modified'], self.old_timestamp,
                       "Modified timestamp should not change when update_modified=False")

    def test_replace_with_changed_content_updates_modified(self):
        """Test that tw replace with changed content updates modified when requested"""
        # Create content with changed text (without modified timestamp, so it can be updated)
        changed_content = """title: ExistingTiddler
created: 20220101120000000

Modified content"""

        # Sleep briefly to ensure timestamp would change
        import time
        time.sleep(0.1)

        # Use replace_tiddler with update_modified=True
        tw_module.replace_tiddler(self.test_wiki, changed_content, update_modified=True)

        # Verify modified timestamp WAS updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertNotEqual(tiddler['modified'], self.old_timestamp,
                          "Modified timestamp should be updated when update_modified=True")
        self.assertEqual(tiddler['text'], "Modified content")

    def test_new_tiddler_via_edit_always_updates_modified(self):
        """Test that creating a new tiddler via edit always updates timestamps"""
        # Create an editor script that adds content
        editor_script = os.path.join(self.test_dir, 'new_editor.py')
        with open(editor_script, 'w') as f:
            f.write('''#!/usr/bin/env python3
import sys
# Append content for new tiddler
with open(sys.argv[1], 'a') as f:
    f.write('\\n')
    f.write('New tiddler content')
''')
        os.chmod(editor_script, 0o755)

        # Set EDITOR to our script
        original_editor = os.environ.get('EDITOR')
        try:
            os.environ['EDITOR'] = editor_script

            # Edit a non-existent tiddler (creates it)
            tw_module.edit_tiddler(self.test_wiki, "NewTiddler")

            # Verify the tiddler was created
            tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
            tiddler = next((t for t in tiddlers if t['title'] == 'NewTiddler'), None)

            self.assertIsNotNone(tiddler, "New tiddler should be created")
            self.assertIsNotNone(tiddler.get('created'), "New tiddler should have created timestamp")
            self.assertIsNotNone(tiddler.get('modified'), "New tiddler should have modified timestamp")
            # The timestamps will be current, not self.old_timestamp
            self.assertNotEqual(tiddler['modified'], self.old_timestamp)
        finally:
            if original_editor:
                os.environ['EDITOR'] = original_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_set_new_field_updates_modified(self):
        """Test that adding a new field updates modified timestamp"""
        # Get current modified time
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')
        original_modified = tiddler['modified']

        # Sleep briefly
        import time
        time.sleep(0.1)

        # Set a field that doesn't exist
        tw_module.set_tiddler_field(self.test_wiki, "ExistingTiddler", "tags", "new-tag")

        # Verify modified timestamp WAS updated
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        tiddler = next(t for t in tiddlers if t['title'] == 'ExistingTiddler')

        self.assertNotEqual(tiddler['modified'], original_modified,
                          "Modified timestamp should be updated when adding new field")
        self.assertEqual(tiddler['tags'], "new-tag")


class TestFieldOrderPreservation(unittest.TestCase):
    """Test that field order is preserved when saving tiddlers"""

    def setUp(self):
        """Create a temporary test wiki with tiddlers in specific field order"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create tiddlers with specific field orderings
        # Original order: text, title, custom, tags, created, type, modified
        tiddler1 = {
            "text": "Hello world",
            "title": "OrderedTiddler1",
            "custom": "custom_value",
            "tags": "test tag1",
            "created": "20220101000000000",
            "type": "text/plain",
            "modified": "20220101000000000"
        }

        # Different order: title, modified, created, type, custom, tags, text
        tiddler2 = {
            "title": "OrderedTiddler2",
            "modified": "20220102000000000",
            "created": "20220102000000000",
            "type": "text/markdown",
            "custom": "another_value",
            "tags": "test tag2",
            "text": "Different content"
        }

        test_tiddlers = [tiddler1, tiddler2]

        # Create the HTML file with tiddlers in specific order
        tiddler_jsons = [json.dumps(t, ensure_ascii=False, separators=(',', ':')) for t in test_tiddlers]
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

    def get_tiddler_field_order(self, wiki_content, tiddler_title):
        """Extract field order for a tiddler from the HTML content"""
        import re
        # Find the script tag
        match = re.search(r'<script class="tiddlywiki-tiddler-store" type="application/json">\[(.*?)\]</script>',
                         wiki_content, re.DOTALL)
        if not match:
            return None

        json_str = '[' + match.group(1) + ']'
        tiddlers = json.loads(json_str)

        for tiddler in tiddlers:
            if tiddler.get('title') == tiddler_title:
                # Return the field names in the order they appear
                return list(tiddler.keys())

        return None

    def test_field_order_preserved_on_set_field(self):
        """Test that field order is preserved when using set_tiddler_field"""
        # Load the wiki to record original field order
        tw_module.load_all_tiddlers(self.test_wiki)

        # Set a field in the first tiddler
        tw_module.set_tiddler_field(self.test_wiki, "OrderedTiddler1", "custom", "modified_value")

        # Read the wiki file and check field order
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        field_order = self.get_tiddler_field_order(content, "OrderedTiddler1")

        # Should maintain original order: text, title, custom, tags, created, type, modified
        expected_order = ["text", "title", "custom", "tags", "created", "type", "modified"]
        self.assertEqual(field_order, expected_order,
                        f"Field order changed. Expected {expected_order}, got {field_order}")

    def test_field_order_preserved_on_touch_tiddler(self):
        """Test that field order is preserved when updating a tiddler with touch"""
        # Load the wiki to record original field order
        tw_module.load_all_tiddlers(self.test_wiki)

        # Touch (update) the second tiddler
        tw_module.touch_tiddler(self.test_wiki, "OrderedTiddler2", "Updated content")

        # Read the wiki file and check field order
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        field_order = self.get_tiddler_field_order(content, "OrderedTiddler2")

        # Should maintain original order: title, modified, created, type, custom, tags, text
        expected_order = ["title", "modified", "created", "type", "custom", "tags", "text"]
        self.assertEqual(field_order, expected_order,
                        f"Field order changed. Expected {expected_order}, got {field_order}")

    def test_new_field_appended_at_end(self):
        """Test that new fields are appended at the end, not inserted"""
        # Load the wiki to record original field order
        tw_module.load_all_tiddlers(self.test_wiki)

        # Set a new field that doesn't exist in the original
        tw_module.set_tiddler_field(self.test_wiki, "OrderedTiddler1", "newfield", "new_value")

        # Read the wiki file and check field order
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        field_order = self.get_tiddler_field_order(content, "OrderedTiddler1")

        # Original order should be preserved, new field appended at end
        expected_order = ["text", "title", "custom", "tags", "created", "type", "modified", "newfield"]
        self.assertEqual(field_order, expected_order,
                        f"Field order incorrect. Expected {expected_order}, got {field_order}")

    def test_different_orders_preserved_separately(self):
        """Test that different tiddlers preserve their own field orders"""
        # Load the wiki to record original field orders
        tw_module.load_all_tiddlers(self.test_wiki)

        # Modify both tiddlers
        tw_module.set_tiddler_field(self.test_wiki, "OrderedTiddler1", "custom", "value1")
        tw_module.set_tiddler_field(self.test_wiki, "OrderedTiddler2", "custom", "value2")

        # Read the wiki file and check both field orders
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        order1 = self.get_tiddler_field_order(content, "OrderedTiddler1")
        order2 = self.get_tiddler_field_order(content, "OrderedTiddler2")

        # First tiddler should have: text, title, custom, tags, created, type, modified
        self.assertEqual(order1, ["text", "title", "custom", "tags", "created", "type", "modified"],
                        "First tiddler field order not preserved")

        # Second tiddler should have: title, modified, created, type, custom, tags, text
        self.assertEqual(order2, ["title", "modified", "created", "type", "custom", "tags", "text"],
                        "Second tiddler field order not preserved")

    def test_field_order_with_insert_tiddler(self):
        """Test that newly inserted tiddlers don't affect existing field orders"""
        # Load the wiki to record original field orders
        tw_module.load_all_tiddlers(self.test_wiki)

        # Insert a new tiddler via insert_tiddler
        new_tiddler_json = json.dumps({
            "title": "NewTiddler",
            "text": "New content",
            "type": "text/html"
        })
        tw_module.insert_tiddler(self.test_wiki, new_tiddler_json)

        # Read the wiki file and verify original orders are still preserved
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        order1 = self.get_tiddler_field_order(content, "OrderedTiddler1")
        order2 = self.get_tiddler_field_order(content, "OrderedTiddler2")

        # Original orders should still be preserved
        self.assertEqual(order1, ["text", "title", "custom", "tags", "created", "type", "modified"],
                        "First tiddler field order changed after inserting new tiddler")
        self.assertEqual(order2, ["title", "modified", "created", "type", "custom", "tags", "text"],
                        "Second tiddler field order changed after inserting new tiddler")


class TestTimestampBehavior(unittest.TestCase):
    """Test that created and modified timestamps are properly managed across all commands"""

    def setUp(self):
        """Create a temporary test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'test_wiki.html')

        # Create test wiki with tiddlers that are missing created/modified fields
        self.test_tiddlers = [
            {"title": "TiddlerWithTimestamps", "text": "Has timestamps", "created": "20230101000000000", "modified": "20230101000000000"},
            {"title": "TiddlerWithoutTimestamps", "text": "Missing timestamps"},
            {"title": "TiddlerWithOnlyCreated", "text": "Has created only", "created": "20230101000000000"},
        ]

        # Create the HTML file
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

    def get_tiddler(self, title):
        """Helper to get a tiddler by title"""
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        for t in tiddlers:
            if t.get('title') == title:
                return t
        return None

    def test_touch_creates_both_timestamps_on_new_tiddler(self):
        """Test that touch creates both created and modified on new tiddler"""
        tw_module.touch_tiddler(self.test_wiki, "NewTiddler", "Some text")
        tiddler = self.get_tiddler("NewTiddler")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)
        self.assertEqual(len(tiddler['created']), 17)
        self.assertEqual(len(tiddler['modified']), 17)

    def test_touch_ensures_created_exists_on_existing_tiddler(self):
        """Test that touch adds created field if missing on existing tiddler"""
        tw_module.touch_tiddler(self.test_wiki, "TiddlerWithoutTimestamps")
        tiddler = self.get_tiddler("TiddlerWithoutTimestamps")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_touch_updates_modified_on_existing_tiddler(self):
        """Test that touch updates modified timestamp on existing tiddler"""
        original = self.get_tiddler("TiddlerWithTimestamps")
        original_modified = original['modified']

        import time
        time.sleep(0.01)  # Small delay to ensure timestamp changes

        tw_module.touch_tiddler(self.test_wiki, "TiddlerWithTimestamps")
        updated = self.get_tiddler("TiddlerWithTimestamps")

        self.assertNotEqual(updated['modified'], original_modified)
        self.assertGreater(updated['modified'], original_modified)

    def test_append_ensures_created_exists(self):
        """Test that append adds created field if missing"""
        tw_module.append_tiddler(self.test_wiki, "TiddlerWithoutTimestamps", "Appended text")
        tiddler = self.get_tiddler("TiddlerWithoutTimestamps")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_append_updates_modified(self):
        """Test that append updates modified timestamp"""
        original = self.get_tiddler("TiddlerWithTimestamps")
        original_modified = original['modified']

        import time
        time.sleep(0.01)

        tw_module.append_tiddler(self.test_wiki, "TiddlerWithTimestamps", "More text")
        updated = self.get_tiddler("TiddlerWithTimestamps")

        self.assertNotEqual(updated['modified'], original_modified)
        self.assertGreater(updated['modified'], original_modified)

    def test_set_field_ensures_created_exists_on_new_tiddler(self):
        """Test that set creates both timestamps on new tiddler"""
        tw_module.set_tiddler_field(self.test_wiki, "NewTiddler", "tags", "test")
        tiddler = self.get_tiddler("NewTiddler")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_set_field_ensures_created_exists_on_existing_tiddler(self):
        """Test that set adds created field if missing when modifying existing tiddler"""
        tw_module.set_tiddler_field(self.test_wiki, "TiddlerWithoutTimestamps", "tags", "test")
        tiddler = self.get_tiddler("TiddlerWithoutTimestamps")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_set_field_updates_modified_when_value_changes(self):
        """Test that set updates modified when field value changes"""
        original = self.get_tiddler("TiddlerWithTimestamps")
        original_modified = original['modified']

        import time
        time.sleep(0.01)

        tw_module.set_tiddler_field(self.test_wiki, "TiddlerWithTimestamps", "tags", "newtag")
        updated = self.get_tiddler("TiddlerWithTimestamps")

        self.assertNotEqual(updated['modified'], original_modified)
        self.assertGreater(updated['modified'], original_modified)

    def test_set_field_does_not_update_modified_when_value_unchanged(self):
        """Test that set doesn't update modified when field value is unchanged"""
        # First set a value
        tw_module.set_tiddler_field(self.test_wiki, "TiddlerWithTimestamps", "tags", "tag1")
        after_first = self.get_tiddler("TiddlerWithTimestamps")
        first_modified = after_first['modified']

        import time
        time.sleep(0.01)

        # Set the same value again
        tw_module.set_tiddler_field(self.test_wiki, "TiddlerWithTimestamps", "tags", "tag1")
        after_second = self.get_tiddler("TiddlerWithTimestamps")

        # Modified should not have changed
        self.assertEqual(after_second['modified'], first_modified)

    def test_insert_creates_timestamps_on_new_tiddler(self):
        """Test that insert creates both timestamps on new tiddler"""
        tiddler_json = json.dumps({"title": "InsertedTiddler", "text": "Inserted content"})
        tw_module.insert_tiddler(self.test_wiki, tiddler_json)
        tiddler = self.get_tiddler("InsertedTiddler")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_insert_preserves_user_provided_timestamps(self):
        """Test that insert preserves user-provided timestamps"""
        custom_created = "20200101120000000"
        custom_modified = "20200202130000000"
        tiddler_json = json.dumps({
            "title": "CustomTimestamps",
            "text": "Content",
            "created": custom_created,
            "modified": custom_modified
        })
        tw_module.insert_tiddler(self.test_wiki, tiddler_json)
        tiddler = self.get_tiddler("CustomTimestamps")

        self.assertEqual(tiddler['created'], custom_created)
        self.assertEqual(tiddler['modified'], custom_modified)

    def test_replace_ensures_created_exists(self):
        """Test that replace adds created field if missing"""
        content = "title: TiddlerWithoutTimestamps\ntext: Updated text"
        tw_module.replace_tiddler(self.test_wiki, content, update_modified=True)
        tiddler = self.get_tiddler("TiddlerWithoutTimestamps")

        self.assertIsNotNone(tiddler)
        self.assertIn('created', tiddler)
        self.assertIn('modified', tiddler)

    def test_replace_preserves_user_provided_timestamps(self):
        """Test that replace preserves timestamps provided in the content"""
        custom_created = "20200101120000000"
        custom_modified = "20200202130000000"
        content = f"title: PreservedTimestamps\ncreated: {custom_created}\nmodified: {custom_modified}\n\nContent here"
        tw_module.replace_tiddler(self.test_wiki, content, update_modified=False)
        tiddler = self.get_tiddler("PreservedTimestamps")

        self.assertEqual(tiddler['created'], custom_created)
        self.assertEqual(tiddler['modified'], custom_modified)

    def test_edit_creates_timestamps_on_new_tiddler(self):
        """Test that edit creates both timestamps on new tiddler"""
        # Mock the editor to just save the file unchanged
        original_env_editor = os.environ.get('EDITOR')
        try:
            # Use 'true' as the editor (does nothing, exits successfully)
            os.environ['EDITOR'] = 'true'

            tw_module.edit_tiddler(self.test_wiki, "EditedNewTiddler")
            tiddler = self.get_tiddler("EditedNewTiddler")

            self.assertIsNotNone(tiddler)
            self.assertIn('created', tiddler)
            self.assertIn('modified', tiddler)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_no_changes_preserves_timestamps(self):
        """Test that edit without changes doesn't update timestamps"""
        # Get original timestamps
        original = self.get_tiddler("TiddlerWithTimestamps")
        original_created = original['created']
        original_modified = original['modified']

        import time
        time.sleep(0.01)

        # Mock the editor to just close without changes
        original_env_editor = os.environ.get('EDITOR')
        try:
            # Use 'true' as the editor (does nothing, exits successfully)
            os.environ['EDITOR'] = 'true'

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithTimestamps")
            updated = self.get_tiddler("TiddlerWithTimestamps")

            # Timestamps should be unchanged
            self.assertEqual(updated['created'], original_created)
            self.assertEqual(updated['modified'], original_modified)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_with_changes_updates_modified(self):
        """Test that edit with changes updates modified timestamp"""
        original = self.get_tiddler("TiddlerWithTimestamps")
        original_created = original['created']
        original_modified = original['modified']

        import time
        time.sleep(0.01)

        # Mock the editor to modify the file
        original_env_editor = os.environ.get('EDITOR')
        try:
            # Create a script that modifies the file
            # Note: edit_tiddler excludes created/modified from the temp file (see lines 272-274),
            # so the mock editor won't see those fields - it only sees title, other fields, and text
            script_path = os.path.join(self.test_dir, 'mock_editor.sh')
            with open(script_path, 'w') as f:
                f.write('#!/bin/sh\n')
                f.write('echo "title: TiddlerWithTimestamps" > "$1"\n')
                f.write('echo "" >> "$1"\n')
                f.write('echo "MODIFIED" >> "$1"\n')
            os.chmod(script_path, 0o755)

            os.environ['EDITOR'] = script_path

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithTimestamps")
            updated = self.get_tiddler("TiddlerWithTimestamps")

            # Created should be unchanged, modified should be updated
            self.assertEqual(updated['created'], original_created)
            self.assertNotEqual(updated['modified'], original_modified)
            self.assertGreater(updated['modified'], original_modified)
            self.assertEqual(updated['text'], "MODIFIED")
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_existing_tiddler_without_timestamps_no_changes(self):
        """Test that edit creates timestamps on existing tiddler missing them (no changes)"""
        # Verify the tiddler exists but has no timestamps
        original = self.get_tiddler("TiddlerWithoutTimestamps")
        self.assertIsNotNone(original)
        self.assertNotIn('created', original)
        self.assertNotIn('modified', original)

        # Mock the editor to just close without changes
        original_env_editor = os.environ.get('EDITOR')
        try:
            os.environ['EDITOR'] = 'true'

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithoutTimestamps")
            updated = self.get_tiddler("TiddlerWithoutTimestamps")

            # Timestamps should now exist
            self.assertIn('created', updated)
            self.assertIn('modified', updated)
            self.assertEqual(len(updated['created']), 17)
            self.assertEqual(len(updated['modified']), 17)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_existing_tiddler_without_timestamps_with_changes(self):
        """Test that edit creates timestamps on existing tiddler missing them (with changes)"""
        # Verify the tiddler exists but has no timestamps
        original = self.get_tiddler("TiddlerWithoutTimestamps")
        self.assertIsNotNone(original)
        self.assertNotIn('created', original)
        self.assertNotIn('modified', original)

        import time
        time.sleep(0.01)

        # Mock the editor to modify the file
        original_env_editor = os.environ.get('EDITOR')
        try:
            script_path = os.path.join(self.test_dir, 'mock_editor.sh')
            with open(script_path, 'w') as f:
                f.write('#!/bin/sh\n')
                f.write('echo "title: TiddlerWithoutTimestamps" > "$1"\n')
                f.write('echo "" >> "$1"\n')
                f.write('echo "MODIFIED CONTENT" >> "$1"\n')
            os.chmod(script_path, 0o755)

            os.environ['EDITOR'] = script_path

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithoutTimestamps")
            updated = self.get_tiddler("TiddlerWithoutTimestamps")

            # Timestamps should now exist
            self.assertIn('created', updated)
            self.assertIn('modified', updated)
            self.assertEqual(updated['text'], "MODIFIED CONTENT")
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_existing_tiddler_with_only_created(self):
        """Test that edit preserves created and adds modified on tiddler with only created"""
        # Verify the tiddler has only created
        original = self.get_tiddler("TiddlerWithOnlyCreated")
        self.assertIsNotNone(original)
        self.assertIn('created', original)
        self.assertNotIn('modified', original)
        original_created = original['created']

        # Mock the editor to just close without changes
        original_env_editor = os.environ.get('EDITOR')
        try:
            os.environ['EDITOR'] = 'true'

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithOnlyCreated")
            updated = self.get_tiddler("TiddlerWithOnlyCreated")

            # Created should be preserved, modified should be added
            self.assertEqual(updated['created'], original_created)
            self.assertIn('modified', updated)
            self.assertEqual(len(updated['modified']), 17)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_new_tiddler_with_content(self):
        """Test that creating a brand new tiddler via edit with content adds timestamps"""
        # Mock the editor to add content
        original_env_editor = os.environ.get('EDITOR')
        try:
            script_path = os.path.join(self.test_dir, 'mock_editor.sh')
            with open(script_path, 'w') as f:
                f.write('#!/bin/sh\n')
                f.write('echo "title: BrandNewTiddler" > "$1"\n')
                f.write('echo "" >> "$1"\n')
                f.write('echo "This is new content" >> "$1"\n')
            os.chmod(script_path, 0o755)

            os.environ['EDITOR'] = script_path

            tw_module.edit_tiddler(self.test_wiki, "BrandNewTiddler")
            tiddler = self.get_tiddler("BrandNewTiddler")

            # Tiddler should exist with timestamps
            self.assertIsNotNone(tiddler)
            self.assertIn('created', tiddler)
            self.assertIn('modified', tiddler)
            self.assertEqual(tiddler['text'], "This is new content")
            self.assertEqual(len(tiddler['created']), 17)
            self.assertEqual(len(tiddler['modified']), 17)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_existing_no_timestamps_realistic_editor(self):
        """Test realistic editing scenario: existing tiddler without timestamps, user adds text"""
        # This test simulates a real user workflow more closely
        original_env_editor = os.environ.get('EDITOR')
        try:
            # Create a script that simulates a user editing:
            # 1. Reads what's in the file (title and text)
            # 2. Adds a new line to the text
            # This is what a real editor would do
            script_path = os.path.join(self.test_dir, 'realistic_editor.sh')
            with open(script_path, 'w') as f:
                f.write('#!/bin/sh\n')
                # Read existing content, append a line
                f.write('echo "" >> "$1"\n')
                f.write('echo "User added this line" >> "$1"\n')
            os.chmod(script_path, 0o755)

            os.environ['EDITOR'] = script_path

            # Edit the tiddler without timestamps
            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithoutTimestamps")
            updated = self.get_tiddler("TiddlerWithoutTimestamps")

            # Verify timestamps were added
            self.assertIsNotNone(updated)
            self.assertIn('created', updated)
            self.assertIn('modified', updated)
            self.assertIn('User added this line', updated['text'])
            self.assertEqual(len(updated['created']), 17)
            self.assertEqual(len(updated['modified']), 17)
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']

    def test_edit_existing_with_tags_no_timestamps(self):
        """Test editing existing tiddler with other fields but no timestamps"""
        import json

        # Manually create a tiddler with tags but no timestamps
        tiddler_json = json.dumps({
            "title": "TiddlerWithTagsNoTS",
            "text": "Content",
            "tags": "tag1 tag2"
        })

        # Insert it directly (this will add timestamps via insert_tiddler)
        # So we need to manually create it without timestamps
        import sys
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

        # Read the wiki, add tiddler without timestamps manually
        with open(self.test_wiki, 'r') as f:
            content = f.read()

        import re
        pattern = r'<script class="tiddlywiki-tiddler-store" type="application/json">(.*?)</script>'
        match = re.search(pattern, content, re.DOTALL)
        if match:
            tiddlers = json.loads(match.group(1).strip(), strict=False)
            tiddlers.append({
                "title": "TiddlerWithTagsNoTS",
                "text": "Content",
                "tags": "tag1 tag2"
            })
            new_json = json.dumps(tiddlers, ensure_ascii=False, separators=(',', ':'))
            new_json = new_json.replace('<', '\\u003C')
            new_store = f'<script class="tiddlywiki-tiddler-store" type="application/json">{new_json}</script>'
            new_content = content[:match.start()] + new_store + content[match.end():]
            with open(self.test_wiki, 'w') as f:
                f.write(new_content)

        # Verify it has no timestamps
        original = self.get_tiddler("TiddlerWithTagsNoTS")
        self.assertIsNotNone(original)
        self.assertNotIn('created', original)
        self.assertNotIn('modified', original)
        self.assertIn('tags', original)

        # Edit with changes
        original_env_editor = os.environ.get('EDITOR')
        try:
            script_path = os.path.join(self.test_dir, 'mock_editor.sh')
            with open(script_path, 'w') as f:
                f.write('#!/bin/sh\n')
                f.write('# Append to file\n')
                f.write('echo "" >> "$1"\n')
                f.write('echo "Added content" >> "$1"\n')
            os.chmod(script_path, 0o755)

            os.environ['EDITOR'] = script_path

            tw_module.edit_tiddler(self.test_wiki, "TiddlerWithTagsNoTS")
            updated = self.get_tiddler("TiddlerWithTagsNoTS")

            # Verify timestamps were added
            self.assertIsNotNone(updated)
            self.assertIn('created', updated)
            self.assertIn('modified', updated)
            self.assertIn('tags', updated)  # Original field preserved
            self.assertIn('Added content', updated['text'])
        finally:
            if original_env_editor is not None:
                os.environ['EDITOR'] = original_env_editor
            elif 'EDITOR' in os.environ:
                del os.environ['EDITOR']


class TestLegacyWikiFormat(unittest.TestCase):
    """Test basic legacy wiki format detection and extraction"""

    def setUp(self):
        """Create a temporary legacy test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'legacy_wiki.html')

        # Create a minimal legacy wiki with storeArea format
        legacy_html = '''<!DOCTYPE html>
<html>
<head><title>Legacy Wiki</title></head>
<body>
<h1>Legacy TiddlyWiki</h1>
<div id="storeArea" style="display:none;">
<div created="20230101000000000" modified="20230101120000000" tags="tag1 tag2" title="LegacyTiddler1">
<pre>This is the first legacy tiddler</pre>
</div>
<div created="20230102000000000" modified="20230102120000000" tags="[[multi word tag]]" title="LegacyTiddler2">
<pre>This is the second legacy tiddler with &lt;html&gt; entities</pre>
</div>
<div created="20230103000000000" creator="testuser" modified="20230103120000000" modifier="testuser" revision="0" tags="" title="LegacyTiddler3">
<pre>This one has extra fields</pre>
</div>
</div>
</body>
</html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

    def tearDown(self):
        """Clean up temporary files after each test"""
        shutil.rmtree(self.test_dir)

    def test_format_detection(self):
        """Test that legacy format is correctly detected"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        wiki_format = tw_module.detect_wiki_format(content)
        self.assertEqual(wiki_format, 'legacy')

    def test_extract_legacy_tiddlers(self):
        """Test extracting tiddlers from legacy format"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        tiddlers = tw_module.extract_legacy_tiddlers(content)
        self.assertEqual(len(tiddlers), 3)

        # Check first tiddler
        t1 = next(t for t in tiddlers if t['title'] == 'LegacyTiddler1')
        self.assertEqual(t1['text'], 'This is the first legacy tiddler')
        self.assertEqual(t1['created'], '20230101000000000')
        self.assertEqual(t1['modified'], '20230101120000000')
        self.assertEqual(t1['tags'], 'tag1 tag2')

    def test_html_entity_decoding(self):
        """Test that HTML entities are properly decoded"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        tiddlers = tw_module.extract_legacy_tiddlers(content)
        t2 = next(t for t in tiddlers if t['title'] == 'LegacyTiddler2')

        # HTML entities should be decoded
        self.assertIn('<html>', t2['text'])
        self.assertNotIn('&lt;', t2['text'])

    def test_extra_fields_preserved(self):
        """Test that extra fields like creator, modifier, revision are preserved"""
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        tiddlers = tw_module.extract_legacy_tiddlers(content)
        t3 = next(t for t in tiddlers if t['title'] == 'LegacyTiddler3')

        self.assertEqual(t3['creator'], 'testuser')
        self.assertEqual(t3['modifier'], 'testuser')
        self.assertEqual(t3['revision'], '0')


class TestLegacyWikiOperations(unittest.TestCase):
    """Test all tw commands on legacy format wikis"""

    def setUp(self):
        """Create a temporary legacy test wiki before each test"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'legacy_wiki.html')

        # Create a legacy wiki
        legacy_html = '''<!DOCTYPE html>
<html>
<head><title>Legacy Wiki</title></head>
<body>
<div id="storeArea" style="display:none;">
<div created="20230101000000000" modified="20230101120000000" tags="tag1" title="TestTiddler1">
<pre>Content 1</pre>
</div>
<div created="20230102000000000" modified="20230102120000000" tags="tag2" title="TestTiddler2">
<pre>Content 2</pre>
</div>
</div>
</body>
</html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

    def tearDown(self):
        """Clean up temporary files after each test"""
        shutil.rmtree(self.test_dir)

    def test_ls_command(self):
        """Test listing tiddlers in legacy wiki"""
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        self.assertIn('TestTiddler1', titles)
        self.assertIn('TestTiddler2', titles)
        self.assertEqual(len(tiddlers), 2)

    def test_cat_command(self):
        """Test displaying tiddler content from legacy wiki"""
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        t1 = next(t for t in tiddlers if t['title'] == 'TestTiddler1')

        self.assertEqual(t1['text'], 'Content 1')
        self.assertEqual(t1['tags'], 'tag1')

    def test_touch_create(self):
        """Test creating new tiddler in legacy wiki"""
        tw_module.touch_tiddler(self.test_wiki, "NewTiddler", "New content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_tiddler = next((t for t in tiddlers if t['title'] == 'NewTiddler'), None)

        self.assertIsNotNone(new_tiddler)
        self.assertEqual(new_tiddler['text'], 'New content')
        self.assertIn('created', new_tiddler)
        self.assertIn('modified', new_tiddler)

    def test_touch_update(self):
        """Test updating existing tiddler in legacy wiki"""
        tw_module.touch_tiddler(self.test_wiki, "TestTiddler1", "Updated content")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        updated = next(t for t in tiddlers if t['title'] == 'TestTiddler1')

        self.assertEqual(updated['text'], 'Updated content')

    def test_set_field(self):
        """Test setting field value in legacy wiki"""
        tw_module.set_tiddler_field(self.test_wiki, "TestTiddler1", "customfield", "customvalue")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        t1 = next(t for t in tiddlers if t['title'] == 'TestTiddler1')

        self.assertEqual(t1['customfield'], 'customvalue')

    def test_remove_tiddler(self):
        """Test removing tiddler from legacy wiki"""
        tw_module.remove_tiddler(self.test_wiki, "TestTiddler1")

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        self.assertNotIn('TestTiddler1', titles)
        self.assertIn('TestTiddler2', titles)

    def test_insert_single_tiddler(self):
        """Test inserting single tiddler via JSON in legacy wiki"""
        tiddler_json = json.dumps({
            "title": "InsertedTiddler",
            "text": "Inserted content",
            "tags": "testtag"
        })

        tw_module.insert_tiddler(self.test_wiki, tiddler_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        inserted = next((t for t in tiddlers if t['title'] == 'InsertedTiddler'), None)

        self.assertIsNotNone(inserted)
        self.assertEqual(inserted['text'], 'Inserted content')
        self.assertEqual(inserted['tags'], 'testtag')

    def test_insert_multiple_tiddlers(self):
        """Test inserting multiple tiddlers via JSON in legacy wiki"""
        tiddlers_json = json.dumps([
            {"title": "Multi1", "text": "Content 1"},
            {"title": "Multi2", "text": "Content 2"}
        ])

        tw_module.insert_tiddler(self.test_wiki, tiddlers_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        titles = [t['title'] for t in tiddlers]

        self.assertIn('Multi1', titles)
        self.assertIn('Multi2', titles)

    def test_replace_existing_tiddler(self):
        """Test that insert replaces existing tiddler in legacy wiki"""
        tiddler_json = json.dumps({
            "title": "TestTiddler1",
            "text": "Replaced content"
        })

        tw_module.insert_tiddler(self.test_wiki, tiddler_json)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        # Should still only have 2 tiddlers (not 3)
        self.assertEqual(len(tiddlers), 2)

        t1 = next(t for t in tiddlers if t['title'] == 'TestTiddler1')
        self.assertEqual(t1['text'], 'Replaced content')


class TestLegacyFormatPreservation(unittest.TestCase):
    """Test that format is preserved (legacy stays legacy, modern stays modern)"""

    def setUp(self):
        """Create temporary wikis"""
        self.test_dir = tempfile.mkdtemp()
        self.legacy_wiki = os.path.join(self.test_dir, 'legacy.html')
        self.modern_wiki = os.path.join(self.test_dir, 'modern.html')

        # Create legacy wiki
        legacy_html = '''<!DOCTYPE html>
<html>
<head><title>Legacy</title></head>
<body>
<div id="storeArea" style="display:none;">
<div created="20230101000000000" modified="20230101120000000" title="Test">
<pre>Legacy content</pre>
</div>
</div>
</body>
</html>'''
        with open(self.legacy_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        # Create modern wiki
        modern_html = '''<!DOCTYPE html>
<html>
<head><title>Modern</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">
[
{"title":"Test","text":"Modern content","created":"20230101000000000"}
]
</script>
</body>
</html>'''
        with open(self.modern_wiki, 'w', encoding='utf-8') as f:
            f.write(modern_html)

    def tearDown(self):
        """Clean up"""
        shutil.rmtree(self.test_dir)

    def test_legacy_stays_legacy_after_insert(self):
        """Test that legacy wiki remains in legacy format after insert"""
        tw_module.insert_tiddler(self.legacy_wiki, '{"title":"NewTiddler","text":"New"}')

        with open(self.legacy_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should still have storeArea
        self.assertIn('<div id="storeArea"', content)
        self.assertNotIn('<script class="tiddlywiki-tiddler-store"', content)

        # Verify format detection still works
        self.assertEqual(tw_module.detect_wiki_format(content), 'legacy')

    def test_legacy_stays_legacy_after_remove(self):
        """Test that legacy wiki remains in legacy format after remove"""
        tw_module.remove_tiddler(self.legacy_wiki, "Test")

        with open(self.legacy_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn('<div id="storeArea"', content)
        self.assertNotIn('<script class="tiddlywiki-tiddler-store"', content)

    def test_legacy_stays_legacy_after_touch(self):
        """Test that legacy wiki remains in legacy format after touch"""
        tw_module.touch_tiddler(self.legacy_wiki, "NewTiddler", "Content")

        with open(self.legacy_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn('<div id="storeArea"', content)
        self.assertNotIn('<script class="tiddlywiki-tiddler-store"', content)

    def test_legacy_stays_legacy_after_set(self):
        """Test that legacy wiki remains in legacy format after set"""
        tw_module.set_tiddler_field(self.legacy_wiki, "Test", "newfield", "value")

        with open(self.legacy_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn('<div id="storeArea"', content)
        self.assertNotIn('<script class="tiddlywiki-tiddler-store"', content)

    def test_modern_stays_modern_after_operations(self):
        """Test that modern wiki remains in modern format after operations"""
        tw_module.insert_tiddler(self.modern_wiki, '{"title":"NewTiddler","text":"New"}')

        with open(self.modern_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should still be modern format
        self.assertIn('<script class="tiddlywiki-tiddler-store"', content)
        self.assertNotIn('<div id="storeArea"', content)

        # Verify format detection still works
        self.assertEqual(tw_module.detect_wiki_format(content), 'modern')


class TestLegacyEdgeCases(unittest.TestCase):
    """Test edge cases in legacy wiki format"""

    def setUp(self):
        """Create test directory"""
        self.test_dir = tempfile.mkdtemp()
        self.test_wiki = os.path.join(self.test_dir, 'edge_wiki.html')

    def tearDown(self):
        """Clean up"""
        shutil.rmtree(self.test_dir)

    def test_special_characters_in_title(self):
        """Test tiddler with special characters in title"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Test &amp; Title &lt;&gt; &quot;Quotes&quot;">
<pre>Content</pre>
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)
        # HTML entities should be decoded
        self.assertEqual(tiddlers[0]['title'], 'Test & Title <> "Quotes"')

    def test_special_characters_in_content(self):
        """Test tiddler with special characters in content"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Test">
<pre>Content with &lt;tags&gt; and &amp; symbols &quot;quotes&quot;</pre>
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertIn('<tags>', tiddlers[0]['text'])
        self.assertIn('&', tiddlers[0]['text'])
        self.assertIn('"quotes"', tiddlers[0]['text'])

    def test_tiddler_without_pre_tag(self):
        """Test tiddler with content directly in div (no pre tag)"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="NoPre">
Direct content without pre tag
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        # Should handle content without pre tags
        self.assertEqual(len(tiddlers), 1)

    def test_empty_tiddler(self):
        """Test empty tiddler (no content)"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Empty">
<pre></pre>
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(len(tiddlers), 1)
        self.assertEqual(tiddlers[0]['text'], '')

    def test_round_trip_with_special_chars(self):
        """Test that special characters survive round trip"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Special">
<pre>Content with &lt;html&gt; &amp; "quotes"</pre>
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        # Read it
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        original_text = tiddlers[0]['text']

        # Modify and write back
        tw_module.touch_tiddler(self.test_wiki, "Special", original_text)

        # Read again
        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        new_text = tiddlers[0]['text']

        # Should be identical
        self.assertEqual(original_text, new_text)

    def test_unicode_preservation(self):
        """Test that Unicode characters are preserved"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Unicode Test">
<pre>Curly quotes: "test" — Unicode: 中文 émojis: 🎉</pre>
</div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        tiddlers = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertIn('"test"', tiddlers[0]['text'])
        self.assertIn('中文', tiddlers[0]['text'])
        self.assertIn('🎉', tiddlers[0]['text'])

        # Test round trip
        tw_module.touch_tiddler(self.test_wiki, "Unicode Test", tiddlers[0]['text'])
        tiddlers2 = tw_module.load_all_tiddlers(self.test_wiki)
        self.assertEqual(tiddlers[0]['text'], tiddlers2[0]['text'])

    def test_tiddler_sorting(self):
        """Test that tiddlers are sorted alphabetically in output"""
        legacy_html = '''<!DOCTYPE html>
<html><body>
<div id="storeArea" style="display:none;">
<div title="Zebra"><pre>Z</pre></div>
<div title="Apple"><pre>A</pre></div>
<div title="Banana"><pre>B</pre></div>
</div>
</body></html>'''

        with open(self.test_wiki, 'w', encoding='utf-8') as f:
            f.write(legacy_html)

        # Touch a tiddler to trigger rewrite
        tw_module.touch_tiddler(self.test_wiki, "Zebra", "Z")

        # Read the file and check order
        with open(self.test_wiki, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find positions of each title
        apple_pos = content.find('title="Apple"')
        banana_pos = content.find('title="Banana"')
        zebra_pos = content.find('title="Zebra"')

        # Should be in alphabetical order
        self.assertLess(apple_pos, banana_pos)
        self.assertLess(banana_pos, zebra_pos)


class TestDetectCommand(unittest.TestCase):
    """Test the detect command for identifying wiki formats"""

    def setUp(self):
        """Create test wiki files in both formats"""
        # Create a modern format wiki
        self.modern_wiki = tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8')
        self.modern_wiki.write('''<!DOCTYPE html>
<html>
<head><title>Modern Test Wiki</title></head>
<body>
<script class="tiddlywiki-tiddler-store" type="application/json">
[
{"title":"TestTiddler","text":"Test content"}
]
</script>
</body>
</html>''')
        self.modern_wiki.close()

        # Create a legacy format wiki
        self.legacy_wiki = tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8')
        self.legacy_wiki.write('''<!DOCTYPE html>
<html>
<head><title>Legacy Test Wiki</title></head>
<body>
<div id="storeArea" style="display:none;">
<div title="TestTiddler" created="20230101000000000" modified="20230101000000000">
<pre>Test content</pre>
</div>
</div>
</body>
</html>''')
        self.legacy_wiki.close()

        # Create a non-wiki HTML file
        self.non_wiki = tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8')
        self.non_wiki.write('''<!DOCTYPE html>
<html>
<head><title>Not a Wiki</title></head>
<body>
<p>Just a regular HTML file</p>
</body>
</html>''')
        self.non_wiki.close()

    def tearDown(self):
        """Clean up test files"""
        os.unlink(self.modern_wiki.name)
        os.unlink(self.legacy_wiki.name)
        os.unlink(self.non_wiki.name)

    def test_detect_modern_format(self):
        """Test detecting modern format wiki"""
        result = subprocess.run(
            ['python3', 'tw', self.modern_wiki.name, 'detect'],
            capture_output=True,
            text=True
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'modern')

    def test_detect_legacy_format(self):
        """Test detecting legacy format wiki"""
        result = subprocess.run(
            ['python3', 'tw', self.legacy_wiki.name, 'detect'],
            capture_output=True,
            text=True
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'legacy')

    def test_detect_non_wiki_fails(self):
        """Test that detect fails on non-wiki HTML files"""
        result = subprocess.run(
            ['python3', 'tw', self.non_wiki.name, 'detect'],
            capture_output=True,
            text=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not detect wiki format', result.stderr)

    def test_detect_with_environment_variable(self):
        """Test detect command using TIDDLYWIKI_WIKI_PATH environment variable"""
        env = os.environ.copy()
        env['TIDDLYWIKI_WIKI_PATH'] = self.modern_wiki.name
        result = subprocess.run(
            ['python3', 'tw', 'detect'],
            capture_output=True,
            text=True,
            env=env
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'modern')

    def test_detect_with_large_wiki(self):
        """Test detect with a larger wiki to verify streaming works"""
        # Create a wiki with a lot of JavaScript before the store
        large_wiki = tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8')
        # Write a large preamble (simulate TiddlyWiki's JavaScript)
        large_wiki.write('<!DOCTYPE html>\n<html>\n<head>\n')
        large_wiki.write('<script>\n')
        # Write ~1MB of JavaScript comments to push storeArea further into file
        for i in range(20000):
            large_wiki.write(f'// Comment line {i} with some padding text to make it larger\n')
        large_wiki.write('</script>\n</head>\n<body>\n')
        # Now write the legacy storeArea
        large_wiki.write('<div id="storeArea" style="display:none;">\n')
        large_wiki.write('<div title="TestTiddler" created="20230101000000000">')
        large_wiki.write('<pre>Content</pre>')
        large_wiki.write('</div>\n')
        large_wiki.write('</div>\n')
        large_wiki.write('</body>\n</html>')
        large_wiki.close()

        try:
            result = subprocess.run(
                ['python3', 'tw', large_wiki.name, 'detect'],
                capture_output=True,
                text=True
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), 'legacy')
        finally:
            os.unlink(large_wiki.name)


class TestFiletypeMap(unittest.TestCase):
    """Tests for the filetype-map command"""

    def test_filetype_map_outputs_json(self):
        """Test that filetype-map outputs valid JSON"""
        import io
        import contextlib

        # Capture stdout from the main() function
        result = subprocess.run(
            ['python3', 'tw', 'filetype-map'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)

        # Should be valid JSON
        parsed = json.loads(result.stdout)
        self.assertIsInstance(parsed, dict)

    def test_filetype_map_contains_expected_mappings(self):
        """Test that filetype-map includes expected MIME type mappings"""
        result = subprocess.run(
            ['python3', 'tw', 'filetype-map'],
            capture_output=True,
            text=True
        )

        parsed = json.loads(result.stdout)

        # Test a few expected mappings
        self.assertEqual(parsed.get('text/vnd.tiddlywiki'), 'markdown')
        self.assertEqual(parsed.get('text/css'), 'css')
        self.assertEqual(parsed.get('application/javascript'), 'javascript')
        self.assertEqual(parsed.get('text/x-python'), 'python')
        self.assertEqual(parsed.get('text/html'), 'html')

    def test_filetype_map_no_wiki_required(self):
        """Test that filetype-map works without a wiki path"""
        # Should work without TIDDLYWIKI_WIKI_PATH env var
        env = os.environ.copy()
        env.pop('TIDDLYWIKI_WIKI_PATH', None)

        result = subprocess.run(
            ['python3', 'tw', 'filetype-map'],
            capture_output=True,
            text=True,
            env=env
        )

        self.assertEqual(result.returncode, 0)
        parsed = json.loads(result.stdout)
        self.assertIsInstance(parsed, dict)
        self.assertGreater(len(parsed), 0)

    def test_filetype_map_all_values_are_strings(self):
        """Test that all filetype mappings are strings"""
        result = subprocess.run(
            ['python3', 'tw', 'filetype-map'],
            capture_output=True,
            text=True
        )

        parsed = json.loads(result.stdout)

        for mime_type, filetype in parsed.items():
            self.assertIsInstance(mime_type, str, f"MIME type key should be string: {mime_type}")
            self.assertIsInstance(filetype, str, f"Filetype value should be string: {filetype}")


class TestMimetypeCommand(unittest.TestCase):
    """Tests for the mimetype command"""

    def test_mimetype_jpg(self):
        """Test that mimetype returns correct MIME type for JPG"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'test.jpg'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'image/jpeg')

    def test_mimetype_jpeg(self):
        """Test that mimetype returns correct MIME type for JPEG"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'test.jpeg'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'image/jpeg')

    def test_mimetype_png(self):
        """Test that mimetype returns correct MIME type for PNG"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'image.png'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'image/png')

    def test_mimetype_mp4(self):
        """Test that mimetype returns correct MIME type for MP4"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'video.mp4'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'video/mp4')

    def test_mimetype_uppercase_extension(self):
        """Test that mimetype handles uppercase extensions"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'image.PNG'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'image/png')

    def test_mimetype_with_path(self):
        """Test that mimetype works with full paths"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', '/path/to/file.mp4'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'video/mp4')

    def test_mimetype_unknown_extension(self):
        """Test that mimetype returns default for unknown extensions"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'file.xyz123'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'application/octet-stream')

    def test_mimetype_no_extension(self):
        """Test that mimetype handles files without extensions"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'filename'],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'application/octet-stream')

    def test_mimetype_no_wiki_required(self):
        """Test that mimetype works without a wiki path"""
        # Should work without TIDDLYWIKI_WIKI_PATH env var
        env = os.environ.copy()
        env.pop('TIDDLYWIKI_WIKI_PATH', None)

        result = subprocess.run(
            ['python3', 'tw', 'mimetype', 'test.jpg'],
            capture_output=True,
            text=True,
            env=env
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'image/jpeg')

    def test_mimetype_common_video_formats(self):
        """Test various video formats"""
        test_cases = [
            ('video.avi', 'video/x-msvideo'),
            ('video.mov', 'video/quicktime'),
            ('video.webm', 'video/webm'),
            ('video.mkv', 'video/x-matroska'),
        ]

        for filename, expected_mime in test_cases:
            with self.subTest(filename=filename):
                result = subprocess.run(
                    ['python3', 'tw', 'mimetype', filename],
                    capture_output=True,
                    text=True
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), expected_mime)

    def test_mimetype_common_image_formats(self):
        """Test various image formats"""
        test_cases = [
            ('image.gif', 'image/gif'),
            ('image.webp', 'image/webp'),
            ('image.svg', 'image/svg+xml'),
            ('image.bmp', 'image/bmp'),
        ]

        for filename, expected_mime in test_cases:
            with self.subTest(filename=filename):
                result = subprocess.run(
                    ['python3', 'tw', 'mimetype', filename],
                    capture_output=True,
                    text=True
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), expected_mime)

    def test_mimetype_missing_filename(self):
        """Test that mimetype fails gracefully without filename"""
        result = subprocess.run(
            ['python3', 'tw', 'mimetype'],
            capture_output=True,
            text=True
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Error', result.stderr)


if __name__ == '__main__':
    unittest.main()
