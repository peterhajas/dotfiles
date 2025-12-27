---
name: tw
description: Command-line tool for managing TiddlyWiki files. Use when working with TiddlyWiki (.html) files, tiddlers, or when the user mentions TiddlyWiki operations.
---

# TiddlyWiki CLI (tw)

## Quick Reference

`tw` is a Python-based CLI for managing single-file TiddlyWiki wikis.

**Location**: `~/dotfiles/tiddlywiki/bin/tw`

**Basic syntax**:
```bash
tw [<wiki_path>] <command> [args]
```

## Common Commands

### Reading/Listing
- `ls` - List all tiddlers
- `cat <tiddler>` - Display tiddler contents (cat format: title, tags, other fields, blank line, text)
- `json <tiddler> [...]` - Output tiddler(s) as JSON (use `--all` for all tiddlers)
- `get <tiddler> <field>` - Get a specific field value
- `filter <expression>` - Evaluate TiddlyWiki filter expression

### Writing/Editing
- `init <dest_path>` - Create a new empty wiki
- `touch <tiddler> [text]` - Create or update a tiddler
- `set <tiddler> <field> <val>` - Set a field value
- `edit <tiddler>` - Edit tiddler in $EDITOR (opens interactive editor)
- `append <tiddler> [text]` - Append text to tiddler
- `insert <json>` - Insert/replace tiddler(s) from JSON
- `replace <content>` - Insert/replace from cat format (reads from stdin)
- `rm <tiddler>` - Remove a tiddler

### Serving
- `serve [--host HOST] [--port PORT] [--readonly]` - Serve wiki with live reload
- `webdav [--host HOST] [--port PORT] [--readonly]` - Serve tiddlers via WebDAV

### Utilities
- `detect` - Detect wiki format (modern or legacy)
- `filetype-map` - Output MIME type to filetype mapping as JSON
- `mimetype <filename>` - Get MIME type for a file extension
- `install_plugin` - Install live reload plugin

## Important Notes

1. **Wiki path**: Always specify the wiki path as the first argument
2. **Cat format**: Output format is `title: X\ntags: Y\nfield: Z\n\ntext content`
3. **Interactive commands**: `edit` opens $EDITOR - don't use in automated scripts, use `replace` instead
4. **Filter expressions**: Supports TiddlyWiki filter syntax (see tw_filter_progress.md for coverage)
5. **Live reload**: Use `install_plugin` once, then `serve` to get auto-refresh in browser

## Examples

```bash
# List all tiddlers in a wiki
tw ~/wiki.html ls

# Create a new tiddler
tw ~/wiki.html touch "MyTiddler" "This is the content"

# Get a field value
tw ~/wiki.html get "MyTiddler" tags

# Set a field
tw ~/wiki.html set "MyTiddler" tags "foo bar"

# Pipe content to replace (non-interactive)
echo -e "title: Test\ntags: demo\n\nContent here" | tw ~/wiki.html replace

# Export all tiddlers as JSON
tw ~/wiki.html json --all > backup.json

# Filter tiddlers (find all tagged "journal")
tw ~/wiki.html filter "[tag[journal]]"

# Serve wiki with live reload on port 8080
tw ~/wiki.html serve --port 8080
```

## Integration with Other Tools

- Pipe JSON to/from `jq` for processing
- Use with `nvim` via $EDITOR for editing
- Combine with shell scripts for batch operations
- WebDAV server allows mounting as filesystem
