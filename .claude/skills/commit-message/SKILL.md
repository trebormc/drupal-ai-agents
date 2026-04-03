---
name: commit-message
description: >-
  Generates high-quality commit messages by analyzing git diff and status.
  Saves the message to a text file in the project root for the user to
  review and commit manually. Uses Conventional Commits format with
  type(scope) prefix. Writes the message in the same language the user
  is using unless a specific language is requested.
  Examples:
  - user: "generate a commit message" -> analyze diff, write commit-msg.txt
  - user: "genera un mensaje de commit" -> analyze diff, write commit-msg.txt
  - user: "prepare commit message for my changes" -> analyze diff, write commit-msg.txt
  - user: "hazme el mensaje de commit" -> analyze diff, write commit-msg.txt
  Never use this to execute git commit. Never push to remote.
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

1. Write the commit message in the **same language the user is interacting in**
2. If the user explicitly requests a specific language, use that language
3. Technical terms (file names, function names, config keys) stay in their original form regardless of language
4. **Never mention AI, assistants, or automated tools** in the message — write as if the developer authored it

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

Detailed body explaining the changes:

- Point 1: what was changed and why
- Point 2: what was changed and why
- Point N: what was changed and why
```

### Subject Line Rules

1. **Max 72 characters** (hard limit)
2. **Imperative mood**: "Add feature" not "Added feature" or "Adds feature"
3. **No period** at the end
4. **Lowercase** after the colon: `fix(auth): validate token expiry`
5. Start with the **most important change** if multiple things changed

### Body Rules

1. **Blank line** between subject and body (required by git)
2. **Bullet points** for multiple changes, each explaining what + why
3. **Group by area** if changes span multiple files/concerns
4. **Be specific**: file names, function names, config keys — not vague descriptions
5. **Wrap lines at 72 characters**
6. Do NOT list every single line change — summarize at the semantic level
7. Mention **breaking changes** prominently if any

### Quality Checklist

Before writing the file:

- [ ] Subject line fits in 72 chars
- [ ] Type is correct for the dominant change
- [ ] Scope is accurate (or omitted if too broad)
- [ ] Body explains WHY, not just WHAT (the diff already shows what)
- [ ] No AI attribution or mention of automated tools
- [ ] Language matches user interaction (or explicit request)
- [ ] Technical terms remain in original language
- [ ] Breaking changes noted if applicable

## Step 4: Save the File

Write the message to `commit-msg.txt` in the project root. Then inform the user:

1. Show the generated message
2. Remind them how to use it:
   - `git add <files>` (if not already staged)
   - `git commit -F commit-msg.txt`
   - `rm commit-msg.txt`

## Examples

### Single module fix (English)

```
fix(event_manager): validate date range before saving event

- Add start/end date comparison in EventForm::validateForm()
  to prevent events where end date precedes start date
- Return early with form error instead of silently saving
  invalid data
```

### Feature addition (Spanish)

```
feat(webhooks): agregar endpoint para recibir notificaciones de pago

- Crear WebhookController con ruta /api/webhooks/payment
- Validar firma HMAC del payload antes de procesar
- Registrar servicio webhook_processor con inyeccion de
  dependencias
- Agregar permisos 'receive webhooks' en permissions.yml
```

### Refactoring (English)

```
refactor(skills): centralize audit module instructions

- Replace repeated Audit module blocks in agents with
  references to quality-tools-setup rule
- Add Related Skills sections for cross-referencing
- Fix broken references to non-existent agents
- Add agent decision tree table to CLAUDE.md
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
