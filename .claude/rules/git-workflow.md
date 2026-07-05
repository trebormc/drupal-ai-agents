---
description: Git workflow rules — git write access is controlled by configurable flags
---

# Git Workflow

Git write access is **configurable per environment** through two flags in
`.env.agents` (`GIT_ALLOW_COMMIT` and `GIT_ALLOW_OPERATIONS`); both default to
nothing allowed. The section below reflects the policy currently in effect in
this environment — it is generated at sync time, so treat it as authoritative.

${GIT_POLICY}

## Always

- Present a clear summary of all file changes and list the modified files.
- Suggest clear, conventional commit messages (reference Beads task IDs, e.g.
  `"Add feature X (bd-a1b2)"`).
- Close completed Beads tasks with `bd close <id> --reason "Done" --json`.
- Never rewrite or destroy remote history: no force-push and no remote-branch
  deletion, whatever the flags allow.
- When a git write is blocked, do not try to work around it — present the
  changes and let the user run the command manually.
