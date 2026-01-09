(function() {
    'use strict';

    // Read prompt from URL parameters
    const params = new URLSearchParams(window.location.search);
    const promptText = params.get('prompt') || params.get('q');

    // Exit early if no prompt
    if (!promptText || promptText.trim() === '') return;

    // URL length warning (browsers typically limit to ~2000 chars)
    if (promptText.length > 8000) {
        console.warn('Gemini URL Prompt: Text is very long, may be truncated');
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function textToHtml(text) {
        // Escape HTML entities first, then convert line breaks to <br>
        return escapeHtml(text).replace(/\n/g, '<br>');
    }

    function setCursorToEnd(element) {
        const range = document.createRange();
        const selection = window.getSelection();
        range.selectNodeContents(element);
        range.collapse(false); // false = collapse to end
        selection.removeAllRanges();
        selection.addRange(range);
    }

    function simulateInput(element, text) {
        // Focus the element
        element.focus();

        // Clear existing content
        element.innerHTML = '';

        // Insert text with proper line break handling
        element.innerHTML = textToHtml(text);

        // Move cursor to end
        setCursorToEnd(element);

        // Dispatch events that frameworks typically listen to
        // Order matters for some frameworks

        // beforeinput event
        element.dispatchEvent(new InputEvent('beforeinput', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: text
        }));

        // input event (most important)
        element.dispatchEvent(new InputEvent('input', {
            bubbles: true,
            cancelable: false,
            inputType: 'insertText',
            data: text
        }));

        // textInput event (legacy, but some frameworks use it)
        try {
            const textEvent = document.createEvent('TextEvent');
            textEvent.initTextEvent('textInput', true, true, window, text);
            element.dispatchEvent(textEvent);
        } catch (e) {
            // TextEvent not supported in all browsers
        }

        // change event
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function fillGeminiInput() {
        // Find Gemini's input element - try multiple selectors
        const selectors = [
            'div[contenteditable="true"][role="textbox"]',
            'div[contenteditable="true"].ql-editor',
            'div[contenteditable="true"]'
        ];

        let inputBox = null;
        for (const selector of selectors) {
            inputBox = document.querySelector(selector);
            if (inputBox) break;
        }

        if (inputBox) {
            simulateInput(inputBox, promptText);
            console.log('Gemini URL Prompt: Text injected successfully (' + promptText.length + ' chars)');
            return true;
        }
        return false;
    }

    // Poll for input element (Gemini is a SPA, may take time to load)
    let attempts = 0;
    const maxAttempts = 30; // 15 seconds max (increased for slow connections)

    const intervalId = setInterval(() => {
        attempts++;
        const success = fillGeminiInput();

        if (success || attempts >= maxAttempts) {
            clearInterval(intervalId);
            if (!success) {
                console.error('Gemini URL Prompt: Could not find input element after ' + (maxAttempts * 500 / 1000) + 's');
            }
        }
    }, 500);
})();
