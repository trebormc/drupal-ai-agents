---
description: Beads task tracking workflow — session start, during work, session end
---

# Beads Task Tracking

Beads (bd) runs in its own DDEV container (`ddev-{project}-beads`). A wrapper at `/usr/local/bin/bd` is installed in your container, so you can use `bd` commands directly -- they are transparently delegated to the Beads container via SSH.

## Session Start (main conversation only)

Subagents skip this section and Session End: they touch Beads only when their brief names a task id, and they never close a task (the caller closes it after review).

```bash
# The beads container auto-initializes the database on start. NEVER run
# `bd init` yourself — it can touch the project's git state. If .beads/ is
# missing, report it and ask the user to run `ddev restart`.
ls .beads/ 2>/dev/null || echo "Beads not initialized — ask the user to run: ddev restart"
bd prime                                        # Get context
bd ready --json                                 # List ready tasks

# Known lessons from previous sessions (the log is append-only: newest entries are last)
test -f LESSONS_LEARNED.md && echo "=== LESSONS LEARNED ===" && tail -n 100 LESSONS_LEARNED.md
```

## During Work

```bash
bd update <id> --status in_progress             # Mark active
bd update <id> --notes "Progress notes..."      # Add notes
bd create "New task" -p 1 --json                # Create task (P0-P3)
```

Never use `bd edit`: it opens an interactive editor that hangs the session. Use `bd update <id> --flags`.

## Session End ("Land the Plane", main conversation only)

Follow the **git-workflow** rule for git access — by default agents do not
commit or push; the user reviews and commits manually. Do not assume you may
run git write commands.

```bash
bd create "Remaining work" -p 2 --json          # File follow-ups
bd close <id> --reason "Done" --json            # Close completed
bd update <id> --notes "Paused at: ..."         # Document state
```

**Lessons Learned check**: Before finishing, review your session — if you solved any non-trivial problems (failed commands, wrong APIs, environment quirks), ensure they are documented in `LESSONS_LEARNED.md`. Mention in your summary: "X lessons documented in LESSONS_LEARNED.md".

## SSH Wrapper Limitations

The `bd` wrapper forwards commands to the Beads container via SSH. Arguments with spaces and special characters are escaped automatically via `printf %q`. Keep in mind:

- **Always use `--json` flag** on create, close, and show for parseable output
- If a command fails unexpectedly, verify the subcommand exists with `bd --help`

Command reference, priorities, commit convention: **beads-task-tracking** skill.
