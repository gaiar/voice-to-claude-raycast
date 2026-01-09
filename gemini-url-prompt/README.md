# Gemini URL Prompt - Chrome Extension

Prefill Google Gemini's input box via URL parameters.

## Installation (Manual)

1. Open Chrome and go to `chrome://extensions/`
2. Enable **Developer mode** (toggle in top right)
3. Click **Load unpacked**
4. Select this folder (`gemini-url-prompt`)

## Usage

Append `?prompt=` or `?q=` to the Gemini URL:

```
https://gemini.google.com/app?prompt=Hello%20World
https://gemini.google.com/app?q=Write%20a%20poem
```

## How It Works

- Content script runs on `gemini.google.com`
- Reads `prompt` or `q` parameter from URL
- Finds input element: `div[contenteditable="true"][role="textbox"]`
- Injects text and dispatches input event
- Polls for up to 10 seconds (handles SPA loading)

## License

MIT
