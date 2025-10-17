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

    def test_set_nonexistent_tiddler(self):
        """Test that setting a field on non-existent tiddler exits with error"""
        with self.assertRaises(SystemExit):
            tw_module.set_tiddler_field(self.test_wiki, "NonExistent", "text", "value")

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

        # Should be able to get the field
        import io
        import contextlib
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            tw_module.get_tiddler_field(self.test_wiki, "TestTiddler", "text")
        self.assertEqual(f.getvalue().strip(), "New text")

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

        # Should only have title
        self.assertEqual(minimal['title'], 'MinimalTiddler')
        self.assertEqual(len(minimal), 1)

if __name__ == '__main__':
    unittest.main()
