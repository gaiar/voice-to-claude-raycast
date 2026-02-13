#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Voice to Gemini
# @raycast.mode fullOutput
# @raycast.icon 🔮

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias vtg

# Documentation:
# @raycast.description Record voice with whisper app, then open Gemini with transcription
# @raycast.author gaiar

# ============================================
# CONFIGURATION
# ============================================

# Whisper app: macwhisper or superwhisper
WHISPER_APP=superwhisper

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

# URL encode the transcript
encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$prompt_text")

# Open Gemini with prompt
open "https://gemini.google.com/app?prompt=$encoded"

echo "✅ Opened Gemini with your voice input!"
echo ""
echo "⚠️  Requires 'Gemini URL Prompt' Chrome extension"
exit 0
