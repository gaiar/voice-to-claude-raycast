#!/bin/bash

# Source shell profile for API key and PATH (non-interactive shells don't load .zshrc)
[[ -f ~/.zshrc ]] && source ~/.zshrc 2>/dev/null

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clipboard to Bear
# @raycast.mode fullOutput
# @raycast.icon 🐻

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias ctb

# Documentation:
# @raycast.description Clean clipboard text with Claude Code, create Bear note
# @raycast.author gaiar

# ============================================
# CONFIGURATION - Adjust these to your setup
# ============================================

# Default tag for voice notes
VOICE_TAG="voice-note"

# ============================================
# HELPER FUNCTIONS
# ============================================

claude_generate() {
    local prompt="$1"
    local response

    response=$(claude -p "$prompt" --output-format text 2>/dev/null)

    echo "$response"
}

url_encode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('''$1''', safe=''))"
}

# ============================================
# SCRIPT LOGIC
# ============================================

# Check if Claude Code CLI is available
if ! command -v claude &> /dev/null; then
    echo "Claude Code CLI is not installed or not in PATH"
    osascript -e 'display notification "Claude Code CLI not found. Please install it first." with title "Clipboard to Bear" sound name "Basso"'
    exit 1
fi

# Get clipboard content
TRANSCRIPT=$(pbpaste 2>/dev/null)

if [ -z "$TRANSCRIPT" ]; then
    echo "Clipboard is empty."
    osascript -e 'display notification "Clipboard is empty" with title "Clipboard to Bear" sound name "Basso"'
    exit 1
fi

echo "Clipboard content:"
echo "---"
echo "$TRANSCRIPT"
echo "---"
echo ""

# Step 1: Clean up the transcript with Claude
echo "Cleaning transcript with Claude..."

CLEAN_PROMPT="You are a text editor. Clean up this voice transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Remove false starts and repetitions
- Structure as bullet list if the content contains multiple items, steps, or enumerated points
- Break into paragraphs if the content covers multiple distinct topics or ideas
- Use markdown formatting where appropriate (lists, bold for emphasis)
- Keep the original meaning and ideas intact
- Keep the original tone and style
- Do NOT summarize or shorten
- Do NOT add any commentary or headers
- Output ONLY the cleaned and formatted text, nothing else

Transcription:
$TRANSCRIPT"

CLEANED_TEXT=$(claude_generate "$CLEAN_PROMPT")

if [ -z "$CLEANED_TEXT" ]; then
    echo "Failed to clean transcript with Claude. Using original."
    CLEANED_TEXT="$TRANSCRIPT"
else
    echo "Cleaned text:"
    echo "---"
    echo "$CLEANED_TEXT"
    echo "---"
    echo ""
fi

# Step 2: Generate title with Claude
echo "Generating title..."

TITLE_PROMPT="Generate a concise, descriptive title (5-8 words max) for this note.
Output ONLY the title, no quotes, no punctuation at the end, nothing else.

Note content:
$CLEANED_TEXT"

TITLE=$(claude_generate "$TITLE_PROMPT")

if [ -z "$TITLE" ]; then
    TITLE="Voice Note $(date '+%Y-%m-%d %H:%M')"
    echo "Failed to generate title. Using default: $TITLE"
else
    # Clean up title (remove quotes if present)
    TITLE=$(echo "$TITLE" | sed 's/^["'\''"]//;s/["'\''"]$//' | head -1)
    echo "Generated title: $TITLE"
fi

# Step 3: Generate relevant tag with Claude
echo "Generating tag..."

TAG_PROMPT="Generate ONE relevant tag for categorizing this note.
Rules:
- Single word or hyphenated-compound (e.g., 'project-idea', 'meeting', 'reminder')
- Lowercase only
- No hashtag symbol
- Output ONLY the tag, nothing else

Note content:
$CLEANED_TEXT"

GENERATED_TAG=$(claude_generate "$TAG_PROMPT")

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

osascript -e "display notification \"Note created: $TITLE\" with title \"Clipboard to Bear\" sound name \"Glass\""

exit 0
