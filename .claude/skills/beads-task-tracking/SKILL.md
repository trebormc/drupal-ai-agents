---
name: beads-task-tracking
description: >-
  Manages tasks using Beads (bd), a git-backed task tracker running in a
  dedicated DDEV container. Use for creating, updating, closing, and querying
  tasks throughout development sessions. A wrapper at /usr/local/bin/bd
  delegates commands to the Beads container transparently.
  Examples:
  - user: "create a task for this feature" -> bd create "Title" -p 1 --json
  - user: "what tasks are pending" -> bd ready --json
  - user: "mark this done" -> bd close <id> --reason "Done" --json
  - user: "create a task" -> bd create "Title" -p 1 --json
  - user: "what tasks are left" -> bd ready --json
  - user: "start tracking work" -> bd init, bd create tasks
  Never use `bd edit` (opens interactive editor). Never run git commit or push.
---

## Environment

Beads runs in its own DDEV container (`ddev-{project}-beads`). A wrapper script at `/usr/local/bin/bd` is installed in your container, so all `bd` commands work directly -- they are transparently delegated to the Beads container via SSH.

The `.beads/` directory lives in the project root (`/var/www/html/.beads/`) and is shared across all containers through the project volume.

## Session Start (ALWAYS DO THIS FIRST)

```bash
# 1. Initialize Beads if not already done
ls -la .beads/ 2>/dev/null || bd init --quiet

# 2. Get context from previous sessions
bd prime

# 3. See what tasks are ready
bd ready --json
```

## Creating Tasks

```bash
# Create a task with priority (P0-P3)
bd create "Implement user authentication" -p 1 --json

# Create a subtask under a parent
bd create "Add validation for edge case" -p 2 --parent <parent-id> --json

# Create multiple tasks for a feature
bd create "Create service class" -p 1 --json
bd create "Add form handler" -p 1 --json
bd create "Write unit tests" -p 2 --json
```

### Priority Levels

| Level | Meaning | When to use |
|-------|---------|-------------|
| P0 | Critical | Blockers, security issues, broken builds |
| P1 | High | Core features, main deliverables |
| P2 | Medium | Normal tasks, enhancements |
| P3 | Low | Nice-to-haves, polish, cleanup |

## Working on Tasks

```bash
# Mark a task as in progress
bd update <id> --status in_progress

# Add progress notes as you work
bd update <id> --notes "Implemented service, working on form validation"

# Close when done
bd close <id> --reason "Implemented and all tests passing" --json
```

## Querying Tasks

```bash
# List all ready tasks
bd ready --json

# Show details of a specific task
bd show <id> --json

# Sync state (persist to git)
bd sync
```

## Session End ("Land the Plane") - MANDATORY

Before finishing any work session, ALWAYS complete these steps:

```bash
# 1. File follow-up tasks for remaining work
bd create "TODO: Add integration tests" -p 2 --json

# 2. Close all completed tasks
bd close <id> --reason "Done: implemented service and unit tests" --json

# 3. Document paused state for in-progress tasks
bd update <id> --notes "Paused at: form validation logic, needs edge case handling"

# 4. Sync Beads state
bd sync
```

## Quick Reference

| Action | Command |
|--------|---------|
| Initialize | `bd init --quiet` |
| Get context | `bd prime` |
| List ready | `bd ready --json` |
| Create task | `bd create "Title" -p 1 --json` |
| Create subtask | `bd create "Title" -p 2 --parent <id> --json` |
| Show task | `bd show <id> --json` |
| Mark active | `bd update <id> --status in_progress` |
| Add notes | `bd update <id> --notes "..."` |
| Close task | `bd close <id> --reason "Done" --json` |
| Sync state | `bd sync` |

## Integration with Ralph Loop

When running inside Ralph Loop (`[RALPH LOOP - Iteration X]`):

**Planning Phase (Iteration 1):**
```bash
# Read requirements and create tasks
bd create "Task from requirements" -p 1 --json
bd create "Another task" -p 2 --json
# Signal completion
echo "<promise>PLANNING_COMPLETE</promise>"
```

**Execution Phase (Iterations 2+):**
```bash
# Get next task
bd ready --json
# Work on it
bd update <id> --status in_progress
# ... do the work ...
bd close <id> --reason "Completed" --json
# Create new subtasks if discovered
bd create "New discovered task" -p 2 --json
```

The loop exits automatically when `bd ready` returns an empty array `[]`.

## Rules

1. **NEVER use `bd edit`** -- it opens an interactive editor that will hang
2. **NEVER run git commit or git push** -- leave all git operations to the user
3. **Always use `--json` flag** on create, close, and show for parseable output
4. **Always close tasks with a reason** -- this documents what was accomplished
5. **Always sync before ending** -- `bd sync` persists state for the next session
6. **Reference task IDs in commit messages** -- suggest format: `"Add feature X (bd-a1b2)"`
