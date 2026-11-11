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
  Never use `bd edit` (opens interactive editor). Git access follows the git-workflow rule.
---

## Environment

Beads runs in its own DDEV container (`ddev-{project}-beads`). A wrapper script at `/usr/local/bin/bd` is installed in your container, so all `bd` commands work directly -- they are transparently delegated to the Beads container via SSH.

The `.beads/` directory lives in the project root (`/var/www/html/.beads/`) and is shared across all containers through the project volume.

## Session start and end

The session rituals (`bd prime`, `bd ready --json`, landing the plane) are in the
always-loaded **beads-workflow** rule and belong to the main conversation.
Subagents touch Beads only when their brief names a task id, and never close a
task: the caller closes it after review. This skill is the command reference.

The beads container initializes the database itself. Do not run `bd init` (it can
touch the project's git state); if `.beads/` is missing, ask the user to run
`ddev restart`.

### If bd fails

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bd: command not found` or SSH errors | Beads container down | Ask the user to run `ddev restart` on the host |
| Unknown subcommand / flag error | Wrong syntax | Check available commands with `bd --help` |
| Command hangs | You ran `bd edit` | Never use `bd edit` — use `bd update <id> --flags` |

## Creating Tasks

**`bd create` is not idempotent: running it twice creates two tasks.** Before creating, check the task does not already exist (`bd ready --json` or `bd list --json`). If a previous create attempt failed ambiguously (e.g., SSH error), verify with `bd ready --json` before retrying.

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
```

## Quick Reference

| Action | Command |
|--------|---------|
| Get context | `bd prime` |
| List ready | `bd ready --json` |
| Create task | `bd create "Title" -p 1 --json` |
| Create subtask | `bd create "Title" -p 2 --parent <id> --json` |
| Show task | `bd show <id> --json` |
| Mark active | `bd update <id> --status in_progress` |
| Add notes | `bd update <id> --notes "..."` |
| Close task | `bd close <id> --reason "Done" --json` |

## Commit Convention

Use Conventional Commits format, in ENGLISH, with the Beads task ID at the end of the
subject (full format in the **commit-message** skill):
```bash
git commit -m "feat(mymodule): add feature X (bd-a1b2)"
```

**Note**: git write access is governed by the **git-workflow** rule.

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

1. **Do not use `bd edit`** -- it opens an interactive editor that hangs the session; use `bd update <id> --flags`
2. **Git access follows the git-workflow rule** -- by default leave all git operations to the user
3. **Always use `--json` flag** on create, close, and show for parseable output
4. **Always close tasks with a reason** -- this documents what was accomplished
5. **Reference task IDs in commit messages** -- same format as the Commit Convention above: `"feat(mymodule): add feature X (bd-a1b2)"`
