#!/bin/bash

# Source shell profile for PATH (non-interactive shells don't load .zshrc)
[[ -f ~/.zshrc ]] && source ~/.zshrc 2>/dev/null

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Voice to Checklist
# @raycast.mode fullOutput
# @raycast.icon ✅

# Optional parameters:
# @raycast.packageName Voice Tools
# @raycast.alias vtcl

# Documentation:
# @raycast.description Record voice, extract tasks with Claude, create/update daily checklist in Bear
# @raycast.author gaiar

# ============================================
# CONFIGURATION
# ============================================

WHISPER_APP=superwhisper
DAILY_TAG="daily-tasks"
BEAR_DB="$HOME/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite"

# JSON Schema for structured Claude output
JSON_SCHEMA='{"type":"object","properties":{"date":{"type":"string","description":"Target date in YYYY-MM-DD format"},"tasks":{"type":"array","items":{"type":"object","properties":{"text":{"type":"string","description":"Task description in original language"},"done":{"type":"boolean","description":"true if task is marked as completed/done"},"category":{"type":"string","enum":["shopping","work","personal","general"],"description":"Task category: shopping=things to buy, work=job/career related, personal=errands/health/home, general=everything else"}},"required":["text","done","category"]},"description":"All tasks, both pending and completed, with categories"},"title":{"type":"string","description":"Brief comma-separated summary of tasks, max 60 chars, in original language"}},"required":["date","tasks","title"]}'

# ============================================
# HELPER FUNCTIONS
# ============================================

claude_extract_tasks() {
    local prompt="$1"
    claude -p "$prompt" \
        --output-format json \
        --model haiku \
        --tools "" \
        --no-session-persistence \
        --json-schema "$JSON_SCHEMA" \
        2>/dev/null
}

url_encode() {
    echo -n "$1" | python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
}

# Query Bear's SQLite DB for an existing checklist note by date prefix + daily-tasks tag
# Returns the note title if found, empty string otherwise
bear_find_note() {
    local date_prefix="$1"
    if [ ! -f "$BEAR_DB" ]; then
        echo ""
        return
    fi
    sqlite3 -readonly "$BEAR_DB" \
        "SELECT n.ZTITLE FROM ZSFNOTE n
         JOIN Z_5TAGS nt ON nt.Z_5NOTES = n.Z_PK
         JOIN ZSFNOTETAG t ON t.Z_PK = nt.Z_13TAGS
         WHERE n.ZTITLE LIKE '[$date_prefix]%'
           AND t.ZTITLE = '$DAILY_TAG'
           AND n.ZTRASHED = 0
           AND n.ZPERMANENTLYDELETED = 0
         ORDER BY n.ZMODIFICATIONDATE DESC LIMIT 1;" \
        2>/dev/null
}

# ============================================
# SCRIPT LOGIC
# ============================================

# Check prerequisites
if ! command -v claude &> /dev/null; then
    echo "Claude Code CLI is not installed or not in PATH"
    osascript -e 'display notification "Claude Code CLI not found" with title "Voice to Checklist" sound name "Basso"'
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/whisper-lib.sh"

# Record voice
if ! whisper_record; then
    osascript -e 'display notification "Timeout waiting for transcription" with title "Voice to Checklist" sound name "Basso"'
    exit 1
fi
TRANSCRIPT="$WHISPER_TRANSCRIPT"

if [ -z "$TRANSCRIPT" ]; then
    echo "Empty transcript"
    osascript -e 'display notification "Empty transcript" with title "Voice to Checklist" sound name "Basso"'
    exit 1
fi

echo "Transcript received:"
echo "---"
echo "$TRANSCRIPT"
echo "---"
echo ""

# Get current date context
TODAY=$(date +%Y-%m-%d)
TOMORROW=$(date -v+1d +%Y-%m-%d)
DAY_OF_WEEK=$(date +%A)

# Extract tasks with Claude
echo "Extracting tasks with Claude..."

EXTRACT_PROMPT="You are a task extraction assistant.

Current date: $TODAY ($DAY_OF_WEEK)
Tomorrow's date: $TOMORROW

Analyze this voice transcript and extract ALL tasks — both pending and completed.

Rules:
- If user mentions \"tomorrow\", target date is $TOMORROW
- If user mentions a specific day of week or date, calculate it relative to today ($TODAY)
- Otherwise target date is $TODAY
- Extract EVERY task mentioned, including ones marked as done/completed/finished
- Mark tasks as done:true if they are indicated as completed (e.g. \"done\", \"finished\", \"completed\", \"already did\", \"checked off\")
- Mark tasks as done:false if they are still pending
- CATEGORIZE each task into exactly one category:
  - \"shopping\" — buying items, groceries, purchases
  - \"work\" — job tasks, career, meetings, emails to colleagues, recruitment
  - \"personal\" — errands, health, home chores, appointments
  - \"general\" — anything that does not fit the above
- KEEP THE ORIGINAL LANGUAGE of the tasks — do not translate. If tasks are in Russian, keep them in Russian. If in English, keep in English. Mixed languages are fine.
- Clean each task: fix grammar, capitalize first letter, make concise and actionable
- Remove filler words and conversational markers
- Generate a brief title summarizing the tasks (comma-separated keywords, max 60 chars, in the original language)
- Each task should be a single clear action item

Transcript:
$TRANSCRIPT"

RESPONSE=$(claude_extract_tasks "$EXTRACT_PROMPT")

if [ -z "$RESPONSE" ]; then
    echo "Failed to get response from Claude"
    osascript -e 'display notification "Claude extraction failed" with title "Voice to Checklist" sound name "Basso"'
    exit 1
fi

echo "Claude response received"
echo ""

# Query Bear DB — does a non-trashed checklist note for this date exist?
# We need to extract the date first (quick parse)
QUICK_DATE=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('structured_output',{}).get('date',''))" 2>/dev/null)
TARGET_DATE="${QUICK_DATE:-$TODAY}"

EXISTING_TITLE=$(bear_find_note "$TARGET_DATE")
EXISTING_BODY=""

if [ -n "$EXISTING_TITLE" ]; then
    echo "Found existing note in Bear: $EXISTING_TITLE"
    # Read existing note body from Bear DB (strip title line and trailing tags)
    EXISTING_BODY=$(sqlite3 -readonly "$BEAR_DB" \
        "SELECT n.ZTEXT FROM ZSFNOTE n
         JOIN Z_5TAGS nt ON nt.Z_5NOTES = n.Z_PK
         JOIN ZSFNOTETAG t ON t.Z_PK = nt.Z_13TAGS
         WHERE n.ZTITLE = '$(echo "$EXISTING_TITLE" | sed "s/'/''/g")'
           AND t.ZTITLE = '$DAILY_TAG'
           AND n.ZTRASHED = 0
           AND n.ZPERMANENTLYDELETED = 0
         ORDER BY n.ZMODIFICATIONDATE DESC LIMIT 1;" 2>/dev/null \
        | sed '1d' | sed 's/#[a-zA-Z0-9_/-]*//g' | sed '/^[[:space:]]*$/d')
fi

# Parse, categorize, and merge using shared Python helper
PARSE_OUTPUT=$(echo "$RESPONSE" | python3 "$SCRIPT_DIR/checklist-parser.py" "$EXISTING_BODY" 2>&1)
PARSE_EXIT=$?

if [ $PARSE_EXIT -ne 0 ]; then
    echo "Failed to parse Claude response: $PARSE_OUTPUT"
    osascript -e 'display notification "Failed to parse tasks" with title "Voice to Checklist" sound name "Basso"'
    exit 1
fi

# Extract parsed values
TARGET_DATE=$(echo "$PARSE_OUTPUT" | sed -n '1p')
TITLE_SUMMARY=$(echo "$PARSE_OUTPUT" | sed -n '2p')
TASK_COUNT=$(echo "$PARSE_OUTPUT" | sed -n '3p')
CHECKLIST=$(echo "$PARSE_OUTPUT" | tail -n +4)

echo "Date: $TARGET_DATE"
echo "Title: $TITLE_SUMMARY"
echo "Tasks ($TASK_COUNT):"
echo "$CHECKLIST"
echo ""

NOTE_TITLE="[$TARGET_DATE] $TITLE_SUMMARY"

if [ -n "$EXISTING_TITLE" ]; then
    # REPLACE existing note body with merged categorized content
    echo "Updating note: $EXISTING_TITLE"

    ENCODED_TITLE=$(url_encode "$EXISTING_TITLE")
    ENCODED_TEXT=$(url_encode "$CHECKLIST")

    BEAR_URL="bear://x-callback-url/add-text?title=${ENCODED_TITLE}&text=${ENCODED_TEXT}&mode=replace&open_note=yes&edit=no"
    open "$BEAR_URL"

    echo ""
    echo "Done! Note updated: $EXISTING_TITLE"
    echo "  Total tasks: $TASK_COUNT"
    osascript -e "display notification \"Checklist updated ($TASK_COUNT tasks)\" with title \"Voice to Checklist\" sound name \"Glass\""
else
    # CREATE new note
    echo "No existing note for $TARGET_DATE — creating new one"

    ENCODED_TITLE=$(url_encode "$NOTE_TITLE")
    ENCODED_TEXT=$(url_encode "$CHECKLIST")
    ENCODED_TAG=$(url_encode "$DAILY_TAG")

    BEAR_URL="bear://x-callback-url/create?title=${ENCODED_TITLE}&text=${ENCODED_TEXT}&tags=${ENCODED_TAG}&open_note=yes&edit=no"
    open "$BEAR_URL"

    echo ""
    echo "Done! Bear note created:"
    echo "  Title: $NOTE_TITLE"
    echo "  Tag: #$DAILY_TAG"
    echo "  Tasks: $TASK_COUNT"
    osascript -e "display notification \"Checklist created: $NOTE_TITLE\" with title \"Voice to Checklist\" sound name \"Glass\""
fi

exit 0
