"""Shared parser for voice-to-checklist and clipboard-to-checklist scripts.

Reads Claude's structured JSON response from stdin.
Optionally merges with existing Bear note content (passed as argument).
Outputs formatted checklist grouped by category.

Output format (stdout):
  Line 1: target date (YYYY-MM-DD)
  Line 2: title summary
  Line 3: total task count
  Line 4+: formatted note body (markdown with category headers)
"""

import json
import re
import sys

# Category definitions: key -> (emoji, display name, sort order)
CATEGORIES = {
    "shopping": ("🛒", "Shopping", 1),
    "work": ("💼", "Work", 2),
    "personal": ("🏠", "Personal", 3),
    "general": ("📋", "General", 4),
}

DEFAULT_CATEGORY = "general"


def parse_claude_response(raw: str) -> dict:
    """Extract structured_output from Claude's JSON response wrapper."""
    wrapper = json.loads(raw)

    if wrapper.get("is_error", False):
        print(f"ERROR: Claude returned an error: {wrapper.get('result', 'unknown')}", file=sys.stderr)
        sys.exit(1)

    data = wrapper.get("structured_output")
    if not data:
        print("ERROR: No structured_output in response", file=sys.stderr)
        sys.exit(1)

    return data


def parse_existing_body(body: str) -> dict[str, list[str]]:
    """Parse an existing categorized note body into category -> [task lines] mapping.

    Handles both categorized format (## headers) and flat format (no headers).
    """
    categories: dict[str, list[str]] = {}
    current_cat = None

    for line in body.splitlines():
        stripped = line.strip()

        # Match category header: ## 🛒 Shopping
        header_match = re.match(r"^##\s+.+?\s+(\w+)\s*$", stripped)
        if header_match:
            cat_name = header_match.group(1).lower()
            # Map display name back to key
            for key, (_, display, _) in CATEGORIES.items():
                if display.lower() == cat_name:
                    current_cat = key
                    break
            else:
                current_cat = DEFAULT_CATEGORY
            continue

        # Match task line: - [ ] or - [x]
        if re.match(r"^- \[[ x]\] ", stripped):
            cat = current_cat or DEFAULT_CATEGORY
            categories.setdefault(cat, [])
            categories[cat].append(stripped)

    return categories


def format_body(categories: dict[str, list[str]]) -> str:
    """Format categorized tasks into markdown with headers."""
    sections = []

    # Sort categories by defined order
    sorted_cats = sorted(
        categories.items(),
        key=lambda x: CATEGORIES.get(x[0], ("", "", 99))[2],
    )

    for cat_key, tasks in sorted_cats:
        if not tasks:
            continue
        emoji, display, _ = CATEGORIES.get(cat_key, ("📋", "General", 99))
        header = f"## {emoji} {display}"
        task_block = "\n".join(tasks)
        sections.append(f"{header}\n{task_block}")

    return "\n\n".join(sections)


def main():
    # Read Claude's JSON response from stdin
    raw = sys.stdin.read().strip()
    if not raw:
        print("ERROR: Empty input", file=sys.stderr)
        sys.exit(1)

    # Parse Claude's response
    data = parse_claude_response(raw)

    date = data.get("date", "")
    tasks = data.get("tasks", [])
    title = data.get("title", "Daily Tasks")

    if not date or not tasks:
        print("ERROR: Missing date or tasks", file=sys.stderr)
        sys.exit(1)

    # Build new tasks grouped by category
    new_categories: dict[str, list[str]] = {}
    for task in tasks:
        if isinstance(task, dict):
            text = task.get("text", "")
            done = task.get("done", False)
            cat = task.get("category", DEFAULT_CATEGORY)
            if cat not in CATEGORIES:
                cat = DEFAULT_CATEGORY
            checkbox = "- [x]" if done else "- [ ]"
            line = f"{checkbox} {text}"
        else:
            cat = DEFAULT_CATEGORY
            line = f"- [ ] {task}"

        new_categories.setdefault(cat, [])
        new_categories[cat].append(line)

    # If existing note body provided as argument, merge
    if len(sys.argv) > 1 and sys.argv[1]:
        existing_body = sys.argv[1]
        existing_categories = parse_existing_body(existing_body)

        # Merge: add new tasks to existing categories
        for cat, task_lines in new_categories.items():
            existing_categories.setdefault(cat, [])
            existing_categories[cat].extend(task_lines)

        merged = existing_categories
    else:
        merged = new_categories

    # Count total tasks
    total = sum(len(t) for t in merged.values())

    # Format output
    body = format_body(merged)

    # Output: date, title, count, body
    print(date)
    print(title)
    print(total)
    print(body)


if __name__ == "__main__":
    main()
