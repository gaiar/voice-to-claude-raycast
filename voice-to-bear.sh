#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Voice to Bear
# @raycast.mode fullOutput
# @raycast.icon 🐻

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias vtb

# Documentation:
# @raycast.description Record with MacWhisper, clean with Ollama, create Bear note
# @raycast.author gaiar

# ============================================
# CONFIGURATION - Adjust these to your setup
# ============================================

# MacWhisper Global keyboard shortcut
MACWHISPER_SHORTCUT='keystroke "w" using {control down, option down}'

# Ollama configuration
OLLAMA_HOST="http://localhost:11434"
OLLAMA_MODEL="gpt-oss:120b-cloud"

# Timeout in seconds (how long to wait for transcription)
TIMEOUT=600

# Default tag for voice notes
VOICE_TAG="voice-note"

# ============================================
# HELPER FUNCTIONS
# ============================================

ollama_generate() {
    local prompt="$1"
    local response

    response=$(curl -s "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg model "$OLLAMA_MODEL" --arg prompt "$prompt" '{
            model: $model,
            prompt: $prompt,
            stream: false
        }')" | jq -r '.response // empty')

    echo "$response"
}

url_encode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('''$1''', safe=''))"
}

# ============================================
# SCRIPT LOGIC
# ============================================

# Check if Ollama is running
if ! curl -s "$OLLAMA_HOST" > /dev/null 2>&1; then
    echo "Ollama is not running at $OLLAMA_HOST"
    osascript -e 'display notification "Ollama is not running. Please start it first." with title "Voice to Bear" sound name "Basso"'
    exit 1
fi

# Store current clipboard content
old_clipboard=$(pbpaste 2>/dev/null)
old_clipboard_hash=$(echo "$old_clipboard" | md5 2>/dev/null)

echo "Recording voice with MacWhisper..."
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
        echo "Transcription received:"
        echo "---"
        echo "$new_clipboard"
        echo "---"
        echo ""

        TRANSCRIPT="$new_clipboard"

        # Step 1: Clean up the transcript with Ollama
        echo "Cleaning transcript with Ollama..."

        CLEAN_PROMPT="You are a text editor. Clean up this voice transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Remove false starts and repetitions
- Keep the original meaning and ideas intact
- Keep the original tone and style
- Do NOT summarize or shorten
- Do NOT add any commentary
- Output ONLY the cleaned text, nothing else

Transcription:
$TRANSCRIPT"

        CLEANED_TEXT=$(ollama_generate "$CLEAN_PROMPT")

        if [ -z "$CLEANED_TEXT" ]; then
            echo "Failed to clean transcript with Ollama. Using original."
            CLEANED_TEXT="$TRANSCRIPT"
        else
            echo "Cleaned text:"
            echo "---"
            echo "$CLEANED_TEXT"
            echo "---"
            echo ""
        fi

        # Step 2: Generate title with Ollama
        echo "Generating title..."

        TITLE_PROMPT="Generate a concise, descriptive title (5-8 words max) for this note.
Output ONLY the title, no quotes, no punctuation at the end, nothing else.

Note content:
$CLEANED_TEXT"

        TITLE=$(ollama_generate "$TITLE_PROMPT")

        if [ -z "$TITLE" ]; then
            TITLE="Voice Note $(date '+%Y-%m-%d %H:%M')"
            echo "Failed to generate title. Using default: $TITLE"
        else
            # Clean up title (remove quotes if present)
            TITLE=$(echo "$TITLE" | sed 's/^["'\''"]//;s/["'\''"]$//' | head -1)
            echo "Generated title: $TITLE"
        fi

        # Step 3: Generate relevant tag with Ollama
        echo "Generating tag..."

        TAG_PROMPT="Generate ONE relevant tag for categorizing this note.
Rules:
- Single word or hyphenated-compound (e.g., 'project-idea', 'meeting', 'reminder')
- Lowercase only
- No hashtag symbol
- Output ONLY the tag, nothing else

Note content:
$CLEANED_TEXT"

        GENERATED_TAG=$(ollama_generate "$TAG_PROMPT")

        if [ -z "$GENERATED_TAG" ]; then
            GENERATED_TAG="general"
            echo "Failed to generate tag. Using default: $GENERATED_TAG"
        else
            # Clean up tag (lowercase, remove spaces, take first word)
            GENERATED_TAG=$(echo "$GENERATED_TAG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | head -1)
            echo "Generated tag: $GENERATED_TAG"
        fi

        # Combine tags: generated tag + voice-note
        ALL_TAGS="$GENERATED_TAG,$VOICE_TAG"
        echo "Tags: $ALL_TAGS"
        echo ""

        # Step 4: Prepare note content with metadata
        CURRENT_DATE=$(date '+%Y-%m-%d %H:%M')
        NOTE_CONTENT="$CLEANED_TEXT

---
*Captured via voice on $CURRENT_DATE*"

        # Step 5: Create Bear note via URL scheme
        echo "Creating Bear note..."

        ENCODED_TITLE=$(url_encode "$TITLE")
        ENCODED_TEXT=$(url_encode "$NOTE_CONTENT")
        ENCODED_TAGS=$(url_encode "$ALL_TAGS")

        BEAR_URL="bear://x-callback-url/create?title=$ENCODED_TITLE&text=$ENCODED_TEXT&tags=$ENCODED_TAGS&open_note=yes&edit=no"

        open "$BEAR_URL"

        echo ""
        echo "Done! Bear note created:"
        echo "  Title: $TITLE"
        echo "  Tags: #$GENERATED_TAG #$VOICE_TAG"

        osascript -e "display notification \"Note created: $TITLE\" with title \"Voice to Bear\" sound name \"Glass\""

        exit 0
    fi

    # Show progress every 10 seconds
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "Waiting for transcription... (${elapsed}s)"
    fi
done

echo "Timeout: No transcription received after ${TIMEOUT} seconds."
echo "   Make sure MacWhisper Global is configured with:"
echo "   - Keyboard shortcut matching this script"
echo "   - Auto Copy enabled"
osascript -e 'display notification "Timeout waiting for transcription" with title "Voice to Bear" sound name "Basso"'
exit 1
