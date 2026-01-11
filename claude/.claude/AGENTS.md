# phajas claude.md

## User info
* Your user is Peter, a software engineer.

## Communication Style
- Telegraph format: concise, token-efficient, noun-phrases acceptable
- Exception: Verbose/complete when explaining complex topics or teaching
- Minimal grammar for routine tasks
- Markdown formatting where appropriate
- Clarifying questions encouraged when they may influence major direction

## Workspace Structure
- Projects: `~/src` (primary workspace)
- Dotfiles: `~/dotfiles` (comprehensive automation & config)
  - Full awareness: Claude should understand dotfiles organization
  - Can modify dotfiles directly when appropriate
- TiddlyWiki: `~/phajas-wiki/phajas-wiki.html` (personal wiki)
- Home directory: `/Users/phajas`

## Development Rules
- **Conventional Commits**: Required for all commits
- **File size**: Keep files under ~500 LOC where practical
- **Quality gates**: Run lint/typecheck/tests before handoff
- **No `rm`**: Use `trash` for safer deletions (when available)
- **Regression tests**: Add when fixing bugs
- Unless prompted, **do not** write a "Demo" or "fake" implementation if you can't figure something out.

## Git Safety
- Status/diff/log: Freely available, read-only ops
- Push: Only when explicitly requested
- Destructive operations: Require explicit user consent
- No force-push without clear authorization
- **Commits**: Only commit the changes you made - other agents/users may be modifying files

## Custom Tools

### TiddlyWiki Tools (`~/dotfiles/tiddlywiki/bin/`)
- **tw**: Primary CLI for wiki management
  - Commands: `ls`, `cat`, `edit`, `get`, `set`, `touch`, `rm`, `json`, `serve`, `filter`
  - Supports HTML and JSON wiki formats
  - Remote wiki support
- **tw_fzf**: Interactive fuzzy-finder editor
- **tiddlywiki_import_file**: Rich media import with crushing/compression
  - Image resizing, video transcoding, metadata stripping
  - Interactive prompts for import options
- **tiddlywiki_watch**: Monitor wiki changes
- **tiddlywiki_sync**, **tiddlywiki_pull**, **tiddlywiki_render**: Sync and rendering tools

### Session Management (`~/dotfiles/zellij/bin/`)
- **sessionize**: Smart Zellij session manager
  - Fuzzy find sessions/directories
  - Auto-creates sessions with custom layouts
  - Predefined: sysmon, kanata, claude, codex, phajas-wiki
  - Layout files: `~/.config/zellij/layouts/<session>.kdl`

### Window Management (`~/dotfiles/yabai/bin/`)
- **yabai_update_tiling**: Sophisticated 5-bucket layout system
  - Buckets: far_left, left, center, right, far_right
  - Special handling for AI windows (Ghostty+Claude)
  - Dry-run mode: `-n` flag
- **yabai_pin_window**: Pin/unpin windows
- **yabai_activate_app**: Activate specific apps

### Claude/AI Integration (`~/dotfiles/claude/bin/`)
- **claudex**: Claude CLI wrapper using Codex/OpenAI backend
  - HTTP proxy translating Anthropic API → Codex MCP
  - Model selection: gpt-5.2-codex, o3, gpt-5.1-codex-max
  - Reasoning levels: low/medium/high
  - Logs: `/tmp/anthropic-codex-proxy-*.log`
- **claude-status-hook**: Status monitoring
- **statusline**: Custom status line display

### Hammerspoon Automation (`~/dotfiles/hammerspoon/bin/`)
- **choose**: GUI chooser for scripts (used by many tools)
  - Reads pipe-delimited options from stdin
  - Returns selected option
- **hr**: Reload Hammerspoon
- **lowlight_on** / **lowlight_off**: Toggle night mode

### Color Scheme (`~/dotfiles/colors/bin/`)
- **colorscheme**: System-wide theme management
  - Auto-detects macOS light/dark mode
  - Families: modus, catppuccin, etc.
  - State: `~/.config/colorscheme/current`
  - Commands: `colorscheme`, `colorscheme list`, `colorscheme <family>`

### Media & YouTube (`~/dotfiles/youtube/bin/`)
- **ytp**: Download & play YouTube (low quality, SponsorBlock)
  - Auto-removes sponsors/self-promo
  - Subtitle embedding
  - Marks videos as watched
- **ytd**: YouTube download (normal quality MP4)
- **yta**: YouTube audio extraction (MP3 with metadata)

### Utilities (`~/dotfiles/utils/bin/`)
- **password_chooser**: Interactive password manager (pass + choose)
- **ai_summarize**: Summarize text/files/URLs (Ollama llama3.2:1b)
- **ai_files_to_prompt**: Concatenate files for AI

## Tool Usage Guidelines
- Prefer custom tools over standard commands when available
  - Use `tw` for TiddlyWiki ops, not manual HTML parsing
  - Use `sessionize` for Zellij session management
  - Use `yabai_update_tiling` for window layout changes
- Hammerspoon integration: Many tools use `choose` for GUI selection
- FZF integration: Interactive selection is common pattern
- Check `~/dotfiles/<domain>/bin/` for domain-specific tooling
- When in doubt about tool existence, check bin directories or ask
