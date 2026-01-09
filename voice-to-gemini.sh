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
# @raycast.description Record with MacWhisper Global, then open Gemini with transcription
# @raycast.author gaiar

# ============================================
# CONFIGURATION
# ============================================

# MacWhisper Global keyboard shortcut
MACWHISPER_SHORTCUT='keystroke "w" using {control down, option down}'

# Timeout in seconds
TIMEOUT=600

# ============================================
# SCRIPT LOGIC
# ============================================

# Store current clipboard
old_clipboard=$(pbpaste 2>/dev/null)
old_hash=$(echo "$old_clipboard" | md5 2>/dev/null)

echo "🎤 Triggering MacWhisper Global..."
echo "   Speak now. When done, stop recording in MacWhisper."
echo ""

# Trigger MacWhisper Global
osascript -e "tell application \"System Events\" to $MACWHISPER_SHORTCUT" 2>/dev/null

# Poll for clipboard change
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    sleep 1
    elapsed=$((elapsed + 1))

    new_clipboard=$(pbpaste 2>/dev/null)
    new_hash=$(echo "$new_clipboard" | md5 2>/dev/null)

    if [ "$new_hash" != "$old_hash" ] && [ -n "$new_clipboard" ]; then
        echo "📝 Transcription received:"
        echo "---"
        echo "$new_clipboard"
        echo "---"
        echo ""

        # Append transcription disclaimer
        DISCLAIMER=$'\n\n---\nNote: This is automated voice transcription and may contain errors. Please correct any grammar or transcription mistakes first, then proceed with the request.'
        prompt_text="${new_clipboard}${DISCLAIMER}"

        # URL encode the transcript
        encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$prompt_text")

        # Open Gemini with prompt
        open "https://gemini.google.com/app?prompt=$encoded"

        echo "✅ Opened Gemini with your voice input!"
        echo ""
        echo "⚠️  Requires 'Gemini URL Prompt' Chrome extension"
        exit 0
    fi

    # Progress every 10 seconds
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "⏳ Waiting for transcription... (${elapsed}s)"
    fi
done

echo "❌ Timeout: No transcription received after ${TIMEOUT} seconds."
exit 1
