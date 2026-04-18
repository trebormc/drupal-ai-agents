---
description: Git workflow rules — agents must not commit or push
---

# Git Workflow

## Agents MUST NOT

- Run `git commit` commands
- Run `git push` commands
- Run `git add` commands
- Run `git checkout`, `git reset`, `git merge`, `git rebase`
- Create commits automatically after making changes

## Agents SHOULD

- Present a clear summary of all file changes
- Suggest appropriate commit messages
- List modified files for user review
- Close completed Beads tasks with `bd close <id> --reason "Done" --json`

## User Workflow

1. Agent makes changes and presents summary
2. User reviews all changes
3. User runs `git add`, `git commit`, `git push` manually
4. User has full control over what gets committed
