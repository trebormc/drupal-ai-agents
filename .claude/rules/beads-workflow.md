---
description: Beads task tracking workflow — session start, during work, session end
---

# Beads Task Tracking

Beads (bd) runs in its own DDEV container (`ddev-{project}-beads`). A wrapper at `/usr/local/bin/bd` is installed in your container, so you can use `bd` commands directly -- they are transparently delegated to the Beads container via `docker exec`.

## Session Start (MANDATORY)

```bash
ls -la .beads/ 2>/dev/null || bd init --quiet  # Initialize if needed
bd prime                                        # Get context
bd ready --json                                 # List ready tasks

# Check for known lessons from previous sessions
test -f LESSONS_LEARNED.md && echo "=== LESSONS LEARNED ===" && head -100 LESSONS_LEARNED.md
```

## During Work

```bash
bd update <id> --status in_progress             # Mark active
bd update <id> --notes "Progress notes..."      # Add notes
bd create "New task" -p 1 --json                # Create task (P0-P3)
```

**WARNING: NEVER use `bd edit`** - opens interactive editor. Use `bd update --flags` instead.

## Session End ("Land the Plane") - MANDATORY

**DO NOT commit or push automatically.** The user will review and commit manually.

```bash
bd create "Remaining work" -p 2 --json          # File follow-ups
bd close <id> --reason "Done" --json            # Close completed
bd update <id> --notes "Paused at: ..."         # Document state
bd sync                                          # Sync Beads state only
```

**Lessons Learned check**: Before finishing, review your session — if you solved any non-trivial problems (failed commands, wrong APIs, environment quirks), ensure they are documented in `LESSONS_LEARNED.md`. Mention in your summary: "X lessons documented in LESSONS_LEARNED.md".

**IMPORTANT**: Leave all git operations (add, commit, push) to the user after they review the changes.

## Quick Reference

| Action | Command |
|--------|---------|
| Ready tasks | `bd ready --json` |
| Create | `bd create "Title" -p 1 --json` |
| Show | `bd show <id> --json` |
| Update status | `bd update <id> --status in_progress` |
| Add notes | `bd update <id> --notes "..."` |
| Close | `bd close <id> --reason "Done" --json` |
| Sync | `bd sync` |

## Priority Levels

| P0 | Critical - blockers, security |
| P1 | High - important features |
| P2 | Medium - normal tasks |
| P3 | Low - nice-to-haves |

## Commit Convention (Reference Only)

When the user creates commits, suggest this format:
```bash
git commit -m "Add feature X (bd-a1b2)"
```

**Note**: Agents must NOT run git commit or git push commands.
