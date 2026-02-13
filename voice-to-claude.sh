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
# @raycast.description Record voice with whisper app, then launch Claude in Warp with transcription
# @raycast.author gaiar

# ============================================
# CONFIGURATION - Adjust these to your setup
# ============================================

# Whisper app: macwhisper or superwhisper
WHISPER_APP=superwhisper

# Path to open in Warp
DEVELOPER_PATH="/Users/gaiar/Developer"
WARP_LAUNCH_DIR="$HOME/.warp/launch_configurations"

# ============================================
# SCRIPT LOGIC
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/whisper-lib.sh"

if ! whisper_record; then
    exit 1
fi
TRANSCRIPT="$WHISPER_TRANSCRIPT"

echo "📝 Transcription received:"
echo "---"
echo "$TRANSCRIPT"
echo "---"
echo ""

# Append transcription disclaimer
DISCLAIMER=$'\n\n---\nNote: This is automated voice transcription and may contain errors. Please correct any grammar or transcription mistakes first, then proceed with the request.'
prompt_text="${TRANSCRIPT}${DISCLAIMER}"

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
            - exec: claude --model haiku '$escaped_transcript'
YAML

echo "🚀 Opening Warp..."

# Launch Warp with the configuration
open "warp://launch/${CONFIG_NAME}"

# Cleanup config file after delay
(sleep 5 && rm -f "$CONFIG_FILE") &

echo "✅ Launched Claude with your voice input!"
exit 0
