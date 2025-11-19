#!/bin/bash
# Hook script called when user submits a prompt and Claude starts processing

# Log for debugging
echo "[$(date)] claude_processing.sh called, ZELLIJ_PANE_ID=$ZELLIJ_PANE_ID" >> /tmp/claude_notifier.log

# Notify Hammerspoon that Claude is processing, passing the pane ID
/usr/local/bin/hs -c "claudeNotifier.onClaudeProcessing('$ZELLIJ_PANE_ID')" 2>&1 >> /tmp/claude_notifier.log
