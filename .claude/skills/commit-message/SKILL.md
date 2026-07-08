---
name: commit-message
description: >-
  Generates concise commit messages by analyzing git diff and status.
  Saves the message to a text file in the project root for the user to
  review and commit manually. Uses Conventional Commits format with
  type(scope) prefix, ALWAYS in English (Drupal community standard),
  with a drupal.org variant (issue ID + By: lines) for contrib work.
  Examples:
  - user: "generate a commit message" -> analyze diff, write commit-msg.txt
  - user: "genera un mensaje de commit" -> analyze diff, write commit-msg.txt
  - user: "prepare commit message for my changes" -> analyze diff, write commit-msg.txt
  - user: "hazme el mensaje de commit" -> analyze diff, write commit-msg.txt
  Never use this to execute git commit. Never push to remote.
# Enforcement, not just prose: while this skill is active the harness blocks
# every state-changing git command. The skill only reads git state and writes
# commit-msg.txt.
disallowed-tools:
  - Bash(git commit*)
  - Bash(* && git commit*)
  - Bash(git add*)
  - Bash(* && git add*)
  - Bash(git push*)
  - Bash(* && git push*)
---

## Purpose

Generate a commit message file from the current git state. The user reviews it and commits manually. This skill does NOT run `git commit` or `git push`.

## Output File

The message is saved to `commit-msg.txt` in the project root. The user can then:

```bash
# Option A: use the file directly
git commit -F commit-msg.txt

# Option B: copy the subject line only
git commit -m "$(head -1 commit-msg.txt)"

# After committing, clean up
rm commit-msg.txt
```

## Language Rules

1. Commit messages are **ALWAYS in English** — Drupal community standard, same
   contract as the **translations** rule: the conversation language never leaks into
   the repository. A user talking in Spanish still gets an English commit message.
   The single exception: the user EXPLICITLY requests another language for this message.
2. Technical terms (file names, function names, config keys) stay in their original form
3. **Never mention AI, assistants, or automated tools** in the message — write as if the developer authored it

## Step 1: Gather Context

Run these commands to understand the full picture:

```bash
# Overview: what files changed, how much
git diff --stat
git diff --cached --stat

# New, deleted, renamed files (not visible in diff)
git status --short

# Full diff for semantic analysis
git diff
git diff --cached

# Recent commit style for consistency
git log --oneline -10
```

**Important distinctions:**
- `git diff` = unstaged changes (not yet added)
- `git diff --cached` = staged changes (already `git add`-ed)
- If everything is unstaged, analyze `git diff`. If staged, analyze `git diff --cached`. If mixed, analyze both.

## Step 2: Analyze Changes

From the diff output, determine:

### 2a. Change Type (Conventional Commits)

| Type | When to use |
|------|-------------|
| `feat` | New functionality, new files that add capabilities |
| `fix` | Bug fix, error correction, broken behavior repaired |
| `refactor` | Code restructuring without changing behavior |
| `docs` | Documentation, README, comments only |
| `style` | Formatting, whitespace, linting fixes (no logic change) |
| `test` | Adding or modifying tests |
| `chore` | Build config, dependencies, CI, tooling |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `build` | Build system, external dependencies |

If changes span multiple types, use the **dominant** type. If truly mixed, use the type that best describes the primary intent.

### 2b. Scope (from file paths)

Infer scope from the changed files:

- All changes in `modules/custom/mymodule/` → scope: `mymodule`
- All changes in `themes/custom/mytheme/` → scope: `mytheme`
- All changes in `.claude/agents/` → scope: `agents`
- All changes in `.claude/skills/` → scope: `skills`
- All changes in `.claude/rules/` → scope: `rules`
- All changes in `config/sync/` → scope: `config`
- Changes span multiple areas → omit scope or use the most relevant one
- Single file change → scope from parent directory or module name

### 2c. Intent Analysis

Read the diff carefully to understand:

- **What** changed (the facts — added function, removed class, changed config value)
- **Why** it changed (the intent — fix a bug, add a feature, improve performance)
- **Impact** (what behavior is different after this commit)

## Step 3: Write the Message

### Format

```
type(scope): concise subject line (max 72 chars)

- Point: what changed and why (one line per bullet, no internal line breaks)
- Point: ...
```

**Size budget — the message must be useful without being long:**
- The subject line alone is a COMPLETE message for small self-explanatory changes
  (one file, one concern). Do not pad a body out of habit.
- Body only when it adds information the diff cannot show: the WHY, the trade-off,
  the breaking change. Maximum 6 bullets or 3 short paragraphs.
- The diff already shows WHAT changed — never narrate it line by line.

### Drupal.org contribution format (contrib/core issues)

When the work belongs to a drupal.org issue (contrib module, core patch, or the
**drupal-org-contribution-prep** skill is in play), use the community format instead:

```
type: #{issue-id} Short summary of the change

Optional body — the why, not the what.

By: drupal-username
By: other-contributor
```

- The issue ID is the numeric segment of the issue URL (same number on drupal.org
  and GitLab).
- `By:` lines use **drupal.org usernames** — never emails, GitLab handles, or
  `@user` syntax. Ask the user for their username if unknown.

### Subject Line Rules

1. **Max 72 characters** (hard limit)
2. **Imperative mood**: "Add feature" not "Added feature" or "Adds feature"
3. **No period** at the end
4. **Lowercase** after the colon: `fix(auth): validate token expiry`
5. Start with the **most important change** if multiple things changed

### Body Rules

1. **Blank line** between subject and body (required by git)
2. **Bullet points** for multiple changes, each explaining what + why
3. **One line per bullet/paragraph — no hard line breaks inside them.** Git and the
   forges render long lines fine; mid-sentence breaks make the message harder to read
   and to copy. Only the subject line has a hard length limit.
4. **Group by area** if changes span multiple files/concerns
5. **Be specific**: file names, function names, config keys — not vague descriptions
6. Do NOT list every single line change — summarize at the semantic level
7. Mention **breaking changes** prominently if any

### Quality Checklist

Before writing the file:

- [ ] Subject line fits in 72 chars
- [ ] Type is correct for the dominant change
- [ ] Scope is accurate (or omitted if too broad)
- [ ] **English** (unless the user explicitly requested another language)
- [ ] Body earns its place: adds WHY/trade-offs the diff cannot show — or is omitted
- [ ] No hard line breaks inside bullets/paragraphs
- [ ] Max 6 bullets / 3 short paragraphs
- [ ] drupal.org format (issue ID + By: lines) if the work belongs to a d.o issue
- [ ] No AI attribution or mention of automated tools
- [ ] Breaking changes noted if applicable

## Step 4: Save the File

Write the message to `commit-msg.txt` in the project root and verify it:

```bash
test -f commit-msg.txt && head -3 commit-msg.txt
```

Then inform the user:

1. Show the generated message
2. Remind them how to use it:
   - `git add <files>` (if not already staged)
   - `git commit -F commit-msg.txt`
   - `rm commit-msg.txt`

**You only GENERATE the message. NEVER run `git add` or `git commit` from inside this skill.**

> If the **git-workflow** rule allows commits in this environment, committing
> is a separate step that happens **after** this skill — and only when the user
> asked for a commit, never proactively: the caller runs `git add <files>`,
> `git commit -F commit-msg.txt`, then `rm commit-msg.txt`. Push only if the
> rule also allows repository operations, and only if the user asked to push.
> When commits are not allowed, present the message for the user to commit
> manually.

## Examples

### Small self-explanatory change — subject only, no body

```
fix(event_manager): validate date range before saving event
```

### Feature addition — body earns its place

```
feat(webhooks): add payment notification endpoint

- Create WebhookController at /api/webhooks/payment with HMAC signature validation before processing, so forged payloads are rejected early
- Register webhook_processor service with constructor injection
- Add 'receive webhooks' permission in permissions.yml
```

### Drupal.org contribution (contrib module issue)

```
fix: #3586461 Prevent fatal on empty field value in formatter

By: drupal-username
By: reviewer-username
```

### Refactoring

```
refactor(skills): centralize audit module instructions

- Replace repeated Audit module blocks in agents with references to the quality-tools-setup rule
- Fix broken references to non-existent agents
```

### Multi-scope changes

```
chore: update dependencies and fix linting errors

- Bump drupal/core from 10.3.1 to 10.3.5 (security)
- Fix PHPCS violations in event_manager module
- Update PHPStan baseline after dependency changes
- Remove deprecated hook_entity_info() usage
```

## Related Skills

- **quality-checks** — Run code quality checks before committing
- **beads-task-tracking** — Reference task IDs in commit messages (e.g., `fix(auth): validate tokens (bd-a1b2)`)
- **git-workflow** (rule) — Decides whether the agent may commit the generated message, or only the user can
