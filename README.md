# Voice to Claude - Raycast Scripts

Raycast script commands that integrate MacWhisper voice transcription with Claude Code in Warp terminal.

## Flow Diagram

```mermaid
flowchart TB
    subgraph "Option A: One-Shot (vcc)"
        A1[Press Raycast hotkey] --> A2[Type 'vcc']
        A2 --> A3[MacWhisper Global opens]
        A3 --> A4[🎤 Speak your prompt]
        A4 --> A5[Stop recording]
        A5 --> A6[Transcription → Clipboard]
        A6 --> A7[Script detects clipboard change]
        A7 --> A8[Creates Warp launch config]
        A8 --> A9[Warp opens in ~/Developer]
        A9 --> A10[claude 'your prompt' runs]
    end

    subgraph "Option B: Two-Step (ctc)"
        B1[Use MacWhisper dictation] --> B2[🎤 Speak]
        B2 --> B3[Transcription → Clipboard]
        B3 --> B4[Press Raycast hotkey]
        B4 --> B5[Type 'ctc']
        B5 --> B6[Creates Warp launch config]
        B6 --> B7[Warp opens in ~/Developer]
        B7 --> B8[claude 'your prompt' runs]
    end

    style A4 fill:#e1f5fe
    style B2 fill:#e1f5fe
    style A10 fill:#c8e6c9
    style B8 fill:#c8e6c9
```

## Scripts

### Voice to Claude (`vcc`)
One-shot voice-to-Claude workflow:
1. Triggers MacWhisper Global overlay
2. Records your voice and transcribes locally
3. Detects when transcription is copied to clipboard
4. Opens Warp terminal in `~/Developer`
5. Automatically runs `claude 'your transcription'`

### Clipboard to Claude (`ctc`)
Two-step workflow (more reliable):
1. Use MacWhisper dictation separately (fn key or custom shortcut)
2. Run this command to send clipboard content to Claude in Warp

## Requirements

- **MacWhisper Pro** - for Global feature with auto-copy
- **Warp** - terminal with launch configuration support
- **Raycast** - command launcher
- **Claude Code** - CLI tool (`claude`)

## Installation

1. Copy scripts to a folder (e.g., `~/Developer/raycast-scripts/`)
2. Make executable:
   ```bash
   chmod +x *.sh
   ```
3. Open Raycast → Settings → Extensions → Script Commands
4. Click "Add Directories" → select your scripts folder
5. In Raycast, run "Reload Script Directories"

## MacWhisper Configuration

1. Open MacWhisper → Settings → Global
2. Set keyboard shortcut: `⌃⌥W` (Control+Option+W)
3. Enable **Auto Start** - begins recording immediately
4. Enable **Auto Copy** - copies transcript to clipboard when done

## Usage

### Option A: One-Shot (Voice to Claude)
1. Open Raycast, type `vcc` → Enter
2. MacWhisper Global appears, starts recording
3. Speak your prompt
4. Press `⌃⌥W` to stop recording
5. Wait for transcription → Warp opens with Claude

### Option B: Two-Step (Clipboard to Claude)
1. Use MacWhisper dictation (fn key) → speak → release
2. Open Raycast, type `ctc` → Enter
3. Warp opens with Claude using your transcript

## Customization

Edit the scripts to change:

```bash
# MacWhisper shortcut (must match your MacWhisper settings)
MACWHISPER_SHORTCUT='keystroke "w" using {control down, option down}'

# Working directory for Claude
DEVELOPER_PATH="/Users/gaiar/Developer"

# How long to wait for transcription (seconds)
TIMEOUT=120
```

## How It Works

The scripts use Warp's launch configuration feature:
1. Create a temporary YAML config in `~/.warp/launch_configurations/`
2. Open Warp via `warp://launch/<config-name>` URL scheme
3. Warp executes the `claude` command with your transcript
4. Config file is cleaned up after 5 seconds

## Troubleshooting

**MacWhisper Global doesn't open:**
- Check keyboard shortcut matches in both MacWhisper and script
- Ensure Raycast has Accessibility permission

**Warp opens but no command runs:**
- Verify `~/.warp/launch_configurations/` directory exists
- Check Warp version supports launch configurations

**Timeout waiting for transcription:**
- Increase `TIMEOUT` value in the script
- Ensure MacWhisper "Auto Copy" is enabled

## License

MIT
