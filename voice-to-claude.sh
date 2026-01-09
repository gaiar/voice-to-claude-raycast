#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Voice to Claude
# @raycast.mode fullOutput
# @raycast.icon 🎤

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias vcc

# Documentation:
# @raycast.description Record with MacWhisper Global, then launch Claude in Warp with transcription
# @raycast.author gaiar

# ============================================
# CONFIGURATION - Adjust these to your setup
# ============================================

# MacWhisper Global keyboard shortcut (modify to match your settings)
# Format: keystroke "key" using {modifier down, modifier down}
MACWHISPER_SHORTCUT='keystroke "w" using {control down, option down}'

# Path to open in Warp
DEVELOPER_PATH="/Users/gaiar/Developer"
WARP_LAUNCH_DIR="$HOME/.warp/launch_configurations"

# Timeout in seconds (how long to wait for transcription)
TIMEOUT=120

# ============================================
# SCRIPT LOGIC
# ============================================

# Store current clipboard content
old_clipboard=$(pbpaste 2>/dev/null)
old_clipboard_hash=$(echo "$old_clipboard" | md5 2>/dev/null)

echo "🎤 Triggering MacWhisper Global..."
echo "   Speak now. When done, stop recording in MacWhisper."
echo ""

# Trigger MacWhisper Global shortcut
osascript -e "tell application \"System Events\" to $MACWHISPER_SHORTCUT" 2>/dev/null

# Poll clipboard for changes
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    sleep 1
    elapsed=$((elapsed + 1))

    new_clipboard=$(pbpaste 2>/dev/null)
    new_clipboard_hash=$(echo "$new_clipboard" | md5 2>/dev/null)

    # Check if clipboard changed and has content
    if [ "$new_clipboard_hash" != "$old_clipboard_hash" ] && [ -n "$new_clipboard" ]; then
        echo "📝 Transcription received:"
        echo "---"
        echo "$new_clipboard"
        echo "---"
        echo ""

        # Append transcription disclaimer
        DISCLAIMER=$'\n\n---\nNote: This is automated voice transcription and may contain errors. Please correct any grammar or transcription mistakes first, then proceed with the request.'
        prompt_text="${new_clipboard}${DISCLAIMER}"

        # Escape the transcript for YAML and shell
        escaped_transcript=$(echo "$prompt_text" | tr '\n' ' ' | sed "s/'/'\\\\''/g")

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

        echo "🚀 Opening Warp..."

        # Launch Warp with the configuration
        open "warp://launch/${CONFIG_NAME}"

        # Cleanup config file after delay
        (sleep 5 && rm -f "$CONFIG_FILE") &

        echo "✅ Launched Claude with your voice input!"
        exit 0
    fi

    # Show progress every 10 seconds
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "⏳ Waiting for transcription... (${elapsed}s)"
    fi
done

echo "❌ Timeout: No transcription received after ${TIMEOUT} seconds."
echo "   Make sure MacWhisper Global is configured with:"
echo "   - Keyboard shortcut matching this script"
echo "   - Auto Copy enabled"
exit 1
