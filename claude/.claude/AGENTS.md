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
- Projects: `~/src` (primary workspace), `~/src/oss` (third-party / open-source)
- Dotfiles: `~/dotfiles` (comprehensive automation & config)
  - Full awareness: Claude should understand dotfiles organization
  - Can modify dotfiles directly when appropriate
- TiddlyWiki: `~/phajas-wiki/phajas-wiki.html` (personal wiki)

## Development Rules
- **File size**: Keep files under ~500 LOC where practical
- **Quality gates**: Run lint/typecheck/tests before handoff
- **Regression tests**: Add when fixing bugs
- Unless prompted, **do not** write a "Demo" or "fake" implementation if you can't figure something out
- **Finding files**: When looking for files, make sure to also search in hidden files. Avoid tools that default to not showing these, like `rg`

## Git Safety
- Status/diff/log: Freely available, read-only ops
- Push: Only when explicitly requested
- Destructive operations: Require explicit user consent
- No force-push without clear authorization
- Only commit the changes you made - other agents/users may be modifying files

## Custom Tools

### TiddlyWiki Tools (`~/dotfiles/tiddlywiki/bin/`)
- **tw**: Primary CLI for wiki management. Use this when asked to modify a TiddlyWiki.
  - run `tw help` for help.

