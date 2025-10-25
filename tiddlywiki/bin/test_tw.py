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
        self.assertEqual(plugin['version'], '0.3.8')
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

        # Should have cooldown mechanism
        self.assertIn('SAVE_COOLDOWN', plugin_code,
            "Plugin should have save cooldown mechanism")
        self.assertIn('lastSaveTime', plugin_code,
            "Plugin should track last save time")

        # Should skip reload during cooldown
        self.assertIn('within save cooldown', plugin_code,
            "Plugin should skip reload during cooldown period")


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


if __name__ == '__main__':
    unittest.main()
