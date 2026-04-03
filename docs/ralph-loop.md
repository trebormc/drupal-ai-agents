# Ralph Loop — Autonomous Task Execution

Ralph Loop is an autonomous task runner that integrates with Beads for persistent task tracking.

## How It Works

```
┌──────────────────────────────────────────────────────────┐
│  ./ralph.sh --prompt requirements.md                     │
├──────────────────────────────────────────────────────────┤
│  PLANNING PHASE (Iteration 1)                            │
│    • Read requirements.md                                │
│    • Create tasks: bd create "Task" -p 1 --json          │
│    • Signal: <promise>PLANNING_COMPLETE</promise>        │
│                                                          │
│  EXECUTION PHASE (Iterations 2+)                         │
│    • Get tasks: bd ready --json                          │
│    • Work on highest priority task                       │
│    • Close: bd close <id> --reason "Done"                │
│    • Create new if discovered: bd create "New" -p 2      │
│    • Repeat until bd ready = []                          │
│                                                          │
│  EXIT: When all tasks completed                          │
└──────────────────────────────────────────────────────────┘
```

## Usage

```bash
./ralph.sh                          # Default requirements
./ralph.sh --prompt my-project.md   # Custom requirements
./ralph.sh --replan                 # Force re-planning
./ralph.sh --no-beads -p task.md    # Legacy mode (no Beads)
```

## When Running Inside Ralph Loop

If you detect `[RALPH LOOP - Iteration X]` in your prompt:

1. **Planning Phase**: Create tasks with `bd create`, then output `<promise>PLANNING_COMPLETE</promise>`
2. **Execution Phase**: Pick next task, work on it, close it, repeat
3. **Completion**: Loop exits automatically when `bd ready` returns empty

## Signals

| Signal | When to use |
|--------|-------------|
| `<promise>PLANNING_COMPLETE</promise>` | After creating all tasks in planning phase |
| `<promise>ERROR</promise>` | Unrecoverable error, cannot continue |

Do NOT use `<promise>COMPLETE</promise>` in Beads mode — loop detects completion automatically.
