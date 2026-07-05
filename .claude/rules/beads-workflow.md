---
description: Beads task tracking workflow — session start, during work, session end
---

# Beads Task Tracking

Beads (bd) runs in its own DDEV container (`ddev-{project}-beads`). A wrapper at `/usr/local/bin/bd` is installed in your container, so you can use `bd` commands directly -- they are transparently delegated to the Beads container via SSH.

## Session Start (MANDATORY)

```bash
# The beads container auto-initializes the database on start. NEVER run
# `bd init` yourself — it can touch the project's git state. If .beads/ is
# missing, report it and ask the user to run `ddev restart`.
ls .beads/ 2>/dev/null || echo "Beads not initialized — ask the user to run: ddev restart"
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

Follow the **git-workflow** rule for git access — by default agents do not
commit or push; the user reviews and commits manually. Do not assume you may
run git write commands.

```bash
bd create "Remaining work" -p 2 --json          # File follow-ups
bd close <id> --reason "Done" --json            # Close completed
bd update <id> --notes "Paused at: ..."         # Document state
```

**Lessons Learned check**: Before finishing, review your session — if you solved any non-trivial problems (failed commands, wrong APIs, environment quirks), ensure they are documented in `LESSONS_LEARNED.md`. Mention in your summary: "X lessons documented in LESSONS_LEARNED.md".

**IMPORTANT**: Git write access depends on the **git-workflow** rule. Unless it is enabled there, leave all git operations (add, commit, push) to the user after they review the changes.

## Quick Reference

| Action | Command |
|--------|---------|
| Ready tasks | `bd ready --json` |
| Create | `bd create "Title" -p 1 --json` |
| Show | `bd show <id> --json` |
| Update status | `bd update <id> --status in_progress` |
| Add notes | `bd update <id> --notes "..."` |
| Close | `bd close <id> --reason "Done" --json` |

## Priority Levels

| P0 | Critical - blockers, security |
| P1 | High - important features |
| P2 | Medium - normal tasks |
| P3 | Low - nice-to-haves |

## SSH Wrapper Limitations

The `bd` wrapper forwards commands to the Beads container via SSH. Arguments with spaces and special characters are escaped automatically via `printf %q`. Keep in mind:

- **Always use `--json` flag** on create, close, and show for parseable output
- **Never use `bd edit`** -- it opens an interactive editor that will hang
- If a command fails unexpectedly, verify the subcommand exists with `bd --help`

## Commit Convention

Use this format for commit messages (the user's, or your own if the
**git-workflow** rule enables commits):
```bash
git commit -m "Add feature X (bd-a1b2)"
```

**Note**: git write access is governed by the **git-workflow** rule.
