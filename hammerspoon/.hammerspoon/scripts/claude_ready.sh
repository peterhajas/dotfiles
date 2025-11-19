#!/bin/bash
# Hook script called when Claude finishes processing and is ready for input

# Log for debugging
echo "[$(date)] claude_ready.sh called, ZELLIJ_PANE_ID=$ZELLIJ_PANE_ID" >> /tmp/claude_notifier.log

# Notify Hammerspoon that Claude is ready, passing the pane ID
/usr/local/bin/hs -c "claudeNotifier.onClaudeReady('$ZELLIJ_PANE_ID')" 2>&1 >> /tmp/claude_notifier.log
