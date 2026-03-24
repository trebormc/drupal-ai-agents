# Lessons Learned — Self-Learning Protocol

## Purpose

This protocol ensures agents **document problems and solutions** as they work, creating a knowledge base that prevents repeating the same mistakes. Every error solved becomes a permanent improvement.

## When to Document a Lesson

Document a lesson when ANY of these occur:

1. **A command fails** and you discover the correct syntax/approach
2. **Generated code causes errors** (missing function, wrong namespace, deprecated API)
3. **A Docker/DDEV operation behaves unexpectedly** and you find the fix
4. **A Drupal API is used incorrectly** (wrong hook, missing dependency, cache issue)
5. **A tool or library has an undocumented quirk** that caused wasted time
6. **A workaround was needed** for an environment-specific issue
7. **An assumption proved wrong** (e.g., expected a service to exist but it didn't)

## How to Document

Append each lesson to the file `LESSONS_LEARNED.md` in the **project root** (`/var/www/html/LESSONS_LEARNED.md`).

Use this exact format:

```markdown
### [SHORT_TITLE] — [DATE]

- **Problem**: [What went wrong — include the exact error message if available]
- **Root cause**: [Why it happened]
- **Solution**: [How it was fixed — include the exact command or code]
- **Category**: [docker | drupal-api | php | drush | composer | phpcs | phpstan | phpunit | twig | playwright | beads | permissions | other]
- **Applies to**: [Which agent, skill, or rule should be updated: e.g., "agent:drupal-dev", "skill:drush-commands", "rule:drupal-essentials", "CLAUDE.md"]
- **Suggested improvement**: [Specific text or rule to add to the target agent/skill/rule so this never happens again]
```

### Example Entry

```markdown
### drush uli returns HTTPS but Playwright needs HTTP — 2025-07-15

- **Problem**: `browser_navigate` failed with SSL_ERROR when using the URL from `drush uli`
- **Root cause**: DDEV's `drush uli` returns HTTPS URLs, but Playwright in Docker cannot validate the local SSL certificate
- **Solution**: Replace `https://` with `http://` in the URL before passing it to Playwright
- **Category**: playwright
- **Applies to**: agent:visual-test, skill:playwright-browser-testing
- **Suggested improvement**: Add to visual-test agent: "ALWAYS convert drush uli URLs from HTTPS to HTTP before navigating"
```

## Procedure for Agents

### During Work

1. **When you encounter an error**, attempt to fix it normally
2. **Once fixed**, immediately evaluate: "Is this a lesson others (or I in a future session) should know?"
3. **If yes**, append the lesson to `LESSONS_LEARNED.md` using the format above
4. **Continue working** — documenting should take <30 seconds, not interrupt flow

### At Session End (Land the Plane)

Before running `bd sync`, review your session:

1. Check: "Did I fix any non-trivial problems during this session?"
2. If lessons were documented, mention them in the session summary
3. Include in summary: "X lessons documented in LESSONS_LEARNED.md for future agent/skill updates"

### During Ralph Loop

In autonomous mode, lesson documentation is **especially important** because:
- No human is watching to catch recurring issues
- The same mistake across 50 iterations wastes significant time and tokens
- Document lessons immediately so subsequent iterations within the SAME Ralph run can benefit

## What NOT to Document

- Typos or simple syntax errors you caught immediately
- Problems already covered by existing rules in `drupal-essentials.md`
- One-off issues specific to a single file that won't recur
- Problems where the cause is unknown (only document when you understand the root cause)

## Using Lessons Learned

At the **start of every session**, check if `LESSONS_LEARNED.md` exists in the project root:

```bash
test -f LESSONS_LEARNED.md && cat LESSONS_LEARNED.md | head -100
```

If it exists, scan for lessons relevant to the current task. Apply known solutions proactively instead of rediscovering them.

## Priority

- P0 (Critical): Lessons about data loss, security, or breaking changes
- P1 (High): Lessons about commands that fail silently or produce wrong results
- P2 (Medium): Lessons about performance or unexpected behavior
- P3 (Low): Lessons about conventions or best practices discovered
