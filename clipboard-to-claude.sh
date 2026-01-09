#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clipboard to Claude
# @raycast.mode silent
# @raycast.icon 📋

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias ctc

# Documentation:
# @raycast.description Send clipboard content to Claude in Warp (use after MacWhisper dictation)
# @raycast.author gaiar

# ============================================
# CONFIGURATION
# ============================================

DEVELOPER_PATH="/Users/gaiar/Developer"
WARP_LAUNCH_DIR="$HOME/.warp/launch_configurations"

# ============================================
# SCRIPT LOGIC
# ============================================

TRANSCRIPT=$(pbpaste 2>/dev/null)

if [ -z "$TRANSCRIPT" ]; then
    osascript -e 'display notification "Clipboard is empty" with title "Clipboard to Claude" sound name "Basso"'
    exit 1
fi

# Escape the transcript for YAML and shell
# Replace newlines with spaces, escape quotes
escaped_transcript=$(echo "$TRANSCRIPT" | tr '\n' ' ' | sed "s/'/'\\\\''/g")

# Ensure launch config directory exists
mkdir -p "$WARP_LAUNCH_DIR"

# Create a unique config name
CONFIG_NAME="claude-voice-$(date +%s)"
CONFIG_FILE="$WARP_LAUNCH_DIR/${CONFIG_NAME}.yaml"

# Create the launch configuration
cat > "$CONFIG_FILE" << YAML
---
name: $CONFIG_NAME
windows:
  - tabs:
      - title: Claude Voice
        layout:
          cwd: $DEVELOPER_PATH
          commands:
            - exec: claude '$escaped_transcript'
YAML

# Launch Warp with the configuration
open "warp://launch/${CONFIG_NAME}"

# Cleanup config file after delay
(sleep 5 && rm -f "$CONFIG_FILE") &

osascript -e 'display notification "Launched Claude with clipboard" with title "Clipboard to Claude"'
