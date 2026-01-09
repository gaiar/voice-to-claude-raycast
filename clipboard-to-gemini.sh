#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clipboard to Gemini
# @raycast.mode silent
# @raycast.icon 🔮

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias ctg

# Documentation:
# @raycast.description Send clipboard content to Gemini (use after MacWhisper dictation)
# @raycast.author gaiar

# ============================================
# SCRIPT LOGIC
# ============================================

TRANSCRIPT=$(pbpaste 2>/dev/null)

if [ -z "$TRANSCRIPT" ]; then
    osascript -e 'display notification "Clipboard is empty" with title "Clipboard to Gemini" sound name "Basso"'
    exit 1
fi

# URL encode the transcript
encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$TRANSCRIPT")

# Open Gemini with prompt
open "https://gemini.google.com/app?prompt=$encoded"

osascript -e 'display notification "Opened Gemini with clipboard" with title "Clipboard to Gemini"'
