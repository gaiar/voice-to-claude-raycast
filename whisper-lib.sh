# whisper-lib.sh — Shared recording library for voice-to-* scripts
# Source this file; do not execute directly.

# ============================================
# DEFAULTS (override in calling script)
# ============================================

: "${WHISPER_TIMEOUT:=600}"
: "${MACWHISPER_SHORTCUT:=keystroke "w" using {control down, option down}}"

# ============================================
# whisper_record()
#
# Triggers the configured whisper app and polls
# the clipboard until new content appears.
#
# Requires: WHISPER_APP set to a supported value
# Sets:     WHISPER_TRANSCRIPT on success
# Returns:  0 on success, 1 on timeout/error
# ============================================

whisper_record() {
    # --- Validate WHISPER_APP ---
    if [ -z "${WHISPER_APP:-}" ]; then
        echo "ERROR: WHISPER_APP is not set."
        echo "Set WHISPER_APP in the configuration section of your script."
        echo "Supported values: macwhisper, superwhisper"
        return 1
    fi

    local app_display
    case "$WHISPER_APP" in
        macwhisper)
            app_display="MacWhisper"
            ;;
        superwhisper)
            app_display="Superwhisper"
            ;;
        *)
            echo "ERROR: Unknown WHISPER_APP='$WHISPER_APP'"
            echo "Supported values: macwhisper, superwhisper"
            return 1
            ;;
    esac

    # --- Snapshot current clipboard ---
    local old_clipboard old_hash
    old_clipboard=$(pbpaste 2>/dev/null)
    old_hash=$(echo "$old_clipboard" | md5 2>/dev/null)

    # --- Trigger the app ---
    echo "Triggering $app_display..."
    echo "   Speak now. When done, stop recording in $app_display."
    echo ""

    case "$WHISPER_APP" in
        macwhisper)
            osascript -e "tell application \"System Events\" to $MACWHISPER_SHORTCUT" 2>/dev/null
            ;;
        superwhisper)
            open "superwhisper://record"
            ;;
    esac

    # --- Poll clipboard for changes ---
    local elapsed=0
    while [ "$elapsed" -lt "$WHISPER_TIMEOUT" ]; do
        sleep 1
        elapsed=$((elapsed + 1))

        local new_clipboard new_hash
        new_clipboard=$(pbpaste 2>/dev/null)
        new_hash=$(echo "$new_clipboard" | md5 2>/dev/null)

        if [ "$new_hash" != "$old_hash" ] && [ -n "$new_clipboard" ]; then
            WHISPER_TRANSCRIPT="$new_clipboard"
            return 0
        fi

        if [ $((elapsed % 10)) -eq 0 ]; then
            echo "Waiting for transcription... (${elapsed}s)"
        fi
    done

    # --- Timeout ---
    echo "Timeout: No transcription received after ${WHISPER_TIMEOUT} seconds."
    case "$WHISPER_APP" in
        macwhisper)
            echo "   Make sure MacWhisper Global is configured with:"
            echo "   - Keyboard shortcut matching this script"
            echo "   - Auto Copy enabled"
            ;;
        superwhisper)
            echo "   Make sure Superwhisper is running and configured with:"
            echo "   - 'Restore Clipboard' disabled"
            echo "   - A transcription mode that copies output to clipboard"
            ;;
    esac
    return 1
}
