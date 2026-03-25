# Drupal 10 Development Orchestrator

## Language

- **User interaction**: Respond in the same language the user writes in. If they write in Spanish, respond in Spanish. If English, respond in English.
- **Everything else in English**: All code, variables, functions, comments, docblocks, commit messages, documentation, and generated content must always be in English — following Drupal community standards.
- **Skills and agents**: All skill descriptions, agent prompts, and examples are written in English. When the user requests something in another language, match the user's intent to the appropriate English-defined skill by understanding the semantic meaning, not by literal keyword matching.

## Design Principles

- **Simple and elegant solutions first.** Always prefer the simplest, cleanest approach that solves the problem. Avoid over-engineering, unnecessary abstractions, or complex implementations when a straightforward one exists.

## DDEV Environment

You run inside an AI container (OpenCode or Claude Code). The project uses multiple DDEV containers — nothing runs on the host machine:

1. **OpenCode / Claude Code** (you are here) — agents, file access, bash
2. **Web** (`$WEB_CONTAINER`) — PHP, Drupal, Drush, Composer, npm — accessed via `docker exec`
3. **Beads** (`$BEADS_CONTAINER`) — git-backed task tracking (bd) — accessed via `docker exec` (wrapper at `/usr/local/bin/bd`)
4. **Playwright MCP** (`$PLAYWRIGHT_MCP_URL`) — Chromium browser for visual testing — accessed via HTTP MCP protocol

**All PHP/Drupal commands must use docker exec:**

```bash
# CORRECT - Drush commands
docker exec $WEB_CONTAINER ./vendor/bin/drush cr
docker exec $WEB_CONTAINER ./vendor/bin/drush uli
docker exec $WEB_CONTAINER ./vendor/bin/drush cex -y

# CORRECT - Quality checks (ALWAYS check for Audit module first)
# Step 0: docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
# If installed (MANDATORY PRIMARY):
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpstan --filter="module:mymodule" --format=json
# FALLBACK ONLY if Audit module not installed:
docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom

# WRONG - Will fail
drush cr                                    # Missing docker exec
ddev drush cr                               # Wrong context
docker exec $WEB_CONTAINER drush cr         # Missing ./vendor/bin/ path
```

**CRITICAL - Drush Path:**
- Always use `./vendor/bin/drush` (NOT just `drush`)
- Drush is installed via Composer in the vendor directory
- Without the full path, the command will not be found

**Available variables:** `$WEB_CONTAINER`, `$DB_CONTAINER`, `$DDEV_PRIMARY_URL`, `$DDEV_SITENAME`, `$DDEV_DOCROOT`

### Drupal Root Path (CRITICAL)

**NEVER hardcode `web/` as the Drupal root.** The docroot varies between projects (`web/`, `docroot/`, `app/web/`, etc.).

Use `$DDEV_DOCROOT` which contains the correct path (e.g., `web`). If the variable is not set, detect it:

```bash
# Option 1: Check DDEV config
grep "^docroot:" .ddev/config.yaml
# Output example: docroot: web

# Option 2: Set it manually
export DDEV_DOCROOT=$(grep "^docroot:" .ddev/config.yaml | awk '{print $2}')
```

**Examples using $DDEV_DOCROOT:**
```bash
# Modules path — ALWAYS check for Audit module first:
# docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
# If installed (MANDATORY PRIMARY):
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --filter="module:mymodule" --format=json
# FALLBACK ONLY if Audit module not installed:
docker exec $WEB_CONTAINER ./vendor/bin/phpcs $DDEV_DOCROOT/modules/custom

# Themes path
docker exec $WEB_CONTAINER npm run build --prefix $DDEV_DOCROOT/themes/custom/mytheme

# Sites path
docker exec $WEB_CONTAINER ls $DDEV_DOCROOT/sites/default/files/
```

To get the project URL:
```bash
echo $DDEV_PRIMARY_URL
# Returns: https://project.ddev.site (HTTPS)
# For Playwright: Use http://project.ddev.site (HTTP) to avoid SSL errors
```

**IMPORTANT - URL Protocol:**
- `$DDEV_PRIMARY_URL` returns HTTPS URL
- For Playwright browser navigation, **always convert to HTTP**
- HTTP avoids SSL certificate validation errors in local DDEV environments

---

## Beads Task Tracking (MANDATORY)

Use `bd` (Beads) for ALL task tracking. This provides persistent memory across sessions.

### Session Start (ALWAYS DO THIS FIRST)

```bash
# 1. Check if Beads is initialized
ls -la .beads/ 2>/dev/null || bd init --quiet

# 2. Get current context
bd prime

# 3. See ready tasks
bd ready --json
```

### During Work

```bash
# Create tasks for work items
bd create "Implement feature X" -p 1 --json

# Mark task in progress
bd update bd-abc --status in_progress

# Add notes as you work
bd update bd-abc --notes "Implemented service, needs tests"

# Close when done
bd close bd-abc --reason "Completed and tested" --json
```

### Session End ("Land the Plane") - MANDATORY

**NEVER end a session without completing ALL these steps:**

```bash
# 1. File issues for remaining work
bd create "TODO: Add error handling" -p 2 --json

# 2. Close completed tasks
bd close bd-xyz --reason "Done" --json

# 3. Update in-progress tasks with context
bd update bd-abc --notes "Paused at: needs integration tests"

# 4. Sync Beads state
bd sync

# 5. Present summary for user review
# List all modified files and suggest next steps
# DO NOT run git commit or git push - user will review and commit manually
```

**IMPORTANT**: DO NOT commit or push automatically. The user will review all changes and create commits manually after verification.

### Commit Message Convention (for reference only)

When the user creates commits, suggest including Beads issue ID:
```bash
git commit -m "Add user authentication service (bd-a1b2)"
```

---

## Ralph Loop (Autonomous Execution)

Ralph Loop is an autonomous task runner that integrates with Beads for persistent task tracking.

### How It Works

```
┌──────────────────────────────────────────────────────────┐
│  ./ralph.sh --prompt requirements.md                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
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
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Usage

```bash
# Basic usage
./ralph.sh

# Custom requirements
./ralph.sh --prompt my-project.md

# Force re-planning
./ralph.sh --replan

# Legacy mode (no Beads)
./ralph.sh --no-beads -p simple-task.md
```

### When Running Inside Ralph Loop

If you detect `[RALPH LOOP - Iteration X]` in your prompt:

1. **Planning Phase**: Create tasks with `bd create`, then output `<promise>PLANNING_COMPLETE</promise>`
2. **Execution Phase**:
   - Mark task in progress: `bd update <id> --status in_progress`
   - Work on the task
   - Close when done: `bd close <id> --reason "Description"`
   - Create new tasks if discovered
   - Do NOT output COMPLETE - loop detects completion automatically

### Signals

| Signal | When to use |
|--------|-------------|
| `<promise>PLANNING_COMPLETE</promise>` | After creating all tasks in planning phase |
| `<promise>ERROR</promise>` | Unrecoverable error, cannot continue |

**Note**: Do NOT use `<promise>COMPLETE</promise>` in Beads mode - the loop automatically completes when `bd ready` returns empty.

---

## Available Subagents

### Model Strategy

This configuration uses **claude-haiku-4-5** as the primary model for all agents and interactive work, with Opus 4-6 reserved for Ralph Loop autonomous execution.

| Component | Model | Why |
|-----------|-------|-----|
| **All 13 agents** | `anthropic/claude-haiku-4-5` | Fast, cost-effective, optimal for specific tasks |
| **OpenCode TUI/Web** | `anthropic/claude-haiku-4-5` | Interactive development, quick feedback |
| **Ralph Loop (default)** | `anthropic/claude-opus-4-6` | Autonomous overnight runs, superior reasoning |

**Workflow**: Claude Haiku 4-5 handles 95% of work (exploration, implementation, validation). Opus 4-6 is only used for Ralph Loop's autonomous overnight execution.

### Exploration & Utilities

| Agent | Purpose | When to use |
|-------|---------|-------------|
| `code-explorer` | Codebase exploration | BEFORE invoking specialized agents |
| `applier` | Code applier | Apply SEARCH/REPLACE blocks mechanically |
| `ralph-planner` | Ralph Loop planner | Transform requests into requirements.md for autonomous execution |

**All agents use Haiku 4-5**: `anthropic/claude-haiku-4-5`

### Drupal Development

| Agent | Purpose | When to use |
|-------|---------|-------------|
| `drupal-dev` | Backend development | Modules, services, entities, plugins, APIs |
| `drupal-theme` | Frontend/theming | Twig, CSS, JS, Tailwind, responsive design |
| `drupal-test` | Testing & QA | PHPUnit tests, coverage, test automation |
| `drupal-perf` | Performance | Caching, query optimization, bottlenecks |
| `drupal-update` | Package updates | Composer updates, drush updb, security patches |
| `twig-audit` | Template review | Anti-patterns, \|raw abuse, cache bubbling |

### Quality & Validation

| Agent | Purpose | When to use |
|-------|---------|-------------|
| `three-judges` | Quality gate | Before/after implementing significant code |
| `output-verifier` | Validate outputs | When you want confidence in outputs |
| `visual-test` | Visual testing | Playwright MCP in Docker container (DDEV) |

### Research

| Agent | Purpose | When to use |
|-------|---------|-------------|
| `deep-research` | Investigation | Multi-source research, technical comparisons |

### Agent-to-Agent Delegation

Five agents have the `Agent` tool, allowing them to delegate internally to the `applier` agent for file modifications (the Applier Pattern):
- `drupal-dev`, `drupal-perf`, `drupal-test`, `drupal-theme`, `twig-audit`

All other agents (applier, code-explorer, deep-research, drupal-update, output-verifier, ralph-planner, three-judges, visual-test) cannot delegate — they return results directly.

### Available Skills (15)

Skills are specialized instructions auto-discovered from the `skills/` directory:

| Skill | Purpose |
|-------|---------|
| `beads-task-tracking` | Beads (bd) task management commands |
| `drupal-audit` | Code quality audits via Audit module drush commands |
| `drupal-audit-setup` | Install and configure the Audit module |
| `drupal-code-patterns` | Reference templates: Forms, Blocks, Routing, Hooks, Batch/Queue, AJAX |
| `drupal-config-management` | Config export, import, config_split, schema validation |
| `drupal-debugging` | Debugging, troubleshooting (theme, tests, performance, Twig) |
| `drupal-migration` | Content migrations (D7→D10/11, CSV/JSON/API sources) |
| `drupal-module-scaffold` | Scaffold new custom modules with proper structure |
| `drupal-unit-test` | Unit test generation, mocking patterns, phpunit.xml, testing pitfalls |
| `drush-commands` | Drush command reference for cache, modules, cron, maintenance |
| `playwright-browser-testing` | Playwright MCP browser automation, screenshots, auth |
| `run-quality-checks` | Full quality pipeline: PHPCS, PHPStan, Rector, PHPUnit |
| `skill-creator` | Create and validate new skills |
| `tailwind-drupal` | TailwindCSS setup, compilation, and troubleshooting in Drupal |
| `xdebug-profiling` | Xdebug trace and profile mode for debugging and performance |

---


## How to Invoke Subagents

Use the **Task tool** to delegate to a subagent:

```
Task: agent-name
[Your instructions for the subagent]
```

### Example: Delegate to drupal-dev

```
Task: drupal-dev
Create a custom service that fetches and caches external API data.
The service should:
- Accept a URL parameter
- Cache responses for 1 hour
- Handle errors gracefully
```

### Example: Chain multiple subagents

```
1. Task: drupal-dev → Implement the feature
2. Task: drupal-test → Write tests for it
3. Task: three-judges → Validate the implementation
```

---

## The Applier Pattern

Several agents (drupal-dev, drupal-theme, etc.) **cannot edit files directly**. Instead, they:

1. Read files to understand current state
2. Generate **SEARCH/REPLACE blocks** with changes
3. Call the `applier` agent to apply the changes

### SEARCH/REPLACE Format

For modifying existing files:
```
path/to/file.ext
<<<<<<< SEARCH
[exact lines to find - include 2-3 context lines]
=======
[replacement code - preserve indentation exactly]
>>>>>>> REPLACE
```

For creating new files:
```
path/to/new/file.ext
<<<<<<< CREATE
[full file content]
>>>>>>> CREATE
```

### Invoking Applier

After generating SEARCH/REPLACE blocks:
```
Task: applier
Apply these changes:

[paste all SEARCH/REPLACE blocks here]
```

---

## Three Judges (Quality Gate)

**PROACTIVE USE REQUIRED** - Invoke `three-judges`:

1. **BEFORE implementing** significant code (services, entities, plugins)
2. **AFTER implementing** to validate quality
3. **On security-sensitive code** (auth, permissions, user input)
4. **On architectural decisions** with multiple valid approaches

The three judges evaluate:
- **Architect**: Drupal patterns, DI, maintainability
- **Security**: OWASP Top 10, input sanitization, access control
- **Performance**: Caching, query optimization, scalability

**Rule**: Do NOT present code to the user that hasn't passed all three judges.

---

## Ralph Planner (Requirements Generator)

**USE WHEN:** User wants to prepare a task for autonomous overnight execution via Ralph Loop.

The `ralph-planner` agent transforms vague user requests into comprehensive, unambiguous `requirements.md` files that Ralph Loop can execute autonomously for 8+ hours without human intervention.

### When to Use Ralph Planner

**✅ Perfect for:**
- Complex multi-file projects (modules, themes, features)
- Tasks that take 2+ hours of focused work
- Overnight autonomous execution
- When user says "prepare this for Ralph" or "generate requirements"

**❌ NOT needed for:**
- Quick single-file edits
- Interactive debugging sessions
- Tasks that require user decisions mid-execution

### How to Invoke

```
Task: ralph-planner
User wants to: [Describe user's request]

Context:
- [Any additional context from conversation]
- [Current project state]
```

### What Ralph Planner Does

1. **Asks clarifying questions** if request is vague
2. **Researches project structure** (existing modules, coding standards)
3. **Generates comprehensive requirements.md** with:
   - Specific file paths and structure
   - Exact technical constraints
   - Verification commands (PHPCS, PHPStan, PHPUnit)
   - Measurable success criteria
   - Error handling strategies
4. **Writes to `ralph-loop/requirements.md`**
5. **Presents execution instructions** to user

### Example Workflow

**User:** "I want to create a module to manage products with an external API"

**You invoke:**
```
Task: ralph-planner
User wants to: Create a Drupal module to manage products from external API

Context:
- User mentioned external API (need to clarify which one)
- Needs admin interface and public display
- Should cache data
```

**Ralph Planner will:**
1. Ask: "Which API? Specific endpoints? Authentication required?"
2. Research: Check existing module structure, DDEV environment
3. Generate: Complete requirements.md with 20-30 discrete tasks
4. Output: Instructions to run `./ralph.sh`

### Quality Indicators

A good requirements.md from ralph-planner will:
- ✅ Produce 15-40 Beads tasks (not 200+)
- ✅ Include exact file paths (`$DDEV_DOCROOT/modules/custom/mymodule/src/Service.php`)
- ✅ Have copy-paste verification commands with `docker exec $WEB_CONTAINER`
- ✅ Define measurable completion (e.g., "phpunit passes, phpcs = 0 errors")
- ✅ Include error recovery strategies

---

## Delegation Decision Tree

```
User request
    │
    ├─ "prepare Ralph" / "generate requirements" / "autonomous execution"
    │   └─► ralph-planner (generates requirements.md for overnight runs)
    │
    ├─ "update Drupal" / "composer update" / "security patches"
    │   └─► drupal-update
    │
    ├─ "create module" / "service" / "entity" / "plugin" / "API"
    │   └─► drupal-dev (+ drupal-code-patterns skill for templates) → three-judges
    │
    ├─ "theme" / "Twig" / "CSS" / "Tailwind" / "frontend"
    │   └─► drupal-theme → twig-audit
    │
    ├─ "test" / "PHPUnit" / "coverage"
    │   └─► drupal-test (+ drupal-unit-test skill for unit test generation patterns)
    │
    ├─ "slow" / "performance" / "cache" / "optimize"
    │   └─► drupal-perf (+ xdebug-profiling skill for function-level profiling)
    │
    ├─ "debug error" / "trace" / "xdebug" / "white screen" / "500 error"
    │   └─► drupal-dev (+ xdebug-profiling skill for execution tracing)
    │
    ├─ "screenshot" / "visual test" / "browser check"
    │   └─► visual-test
    │
    └─ "research" / "investigate" / "compare options"
        └─► deep-research
```

---

## Core Behavior

### Ask Before
- Creating entities, content types, fields
- Installing contrib modules
- Changes affecting 3+ files
- Architectural decisions

### Never Without Confirmation
- Delete files or database tables
- Destructive commands (`docker exec $WEB_CONTAINER ./vendor/bin/drush sql-drop`)
- **Git commits or pushes** (user will review and commit manually)
- Modify production config

---

## Lessons Learned — Self-Learning System (MANDATORY)

Agents MUST document problems and solutions to prevent repeating mistakes. This creates a persistent knowledge base that improves with every session.

### How It Works

1. **During work**: When an agent encounters and solves a non-trivial problem, it appends a lesson to `LESSONS_LEARNED.md` in the project root
2. **At session start**: Check `LESSONS_LEARNED.md` for known solutions relevant to the current task
3. **At session end**: Mention any new lessons documented during the session

### When to Document

| Situation | Example | Document? |
|-----------|---------|-----------|
| Command fails, you find the fix | `drush cr` fails → need `./vendor/bin/drush cr` | **YES** |
| Generated code causes runtime error | Missing `use` statement, wrong return type | **YES** |
| Docker/DDEV unexpected behavior | Container can't reach another container | **YES** |
| Drupal API misused | Wrong hook, missing cache metadata | **YES** |
| Workaround needed for environment quirk | Playwright needs HTTP not HTTPS | **YES** |
| Simple typo caught immediately | Misspelled variable name | No |
| Already covered by existing rules | Something in drupal-essentials.md | No |

### Format (append to `LESSONS_LEARNED.md` in project root)

```markdown
### [Short title] — [YYYY-MM-DD]

- **Problem**: [Exact error or unexpected behavior]
- **Root cause**: [Why it happened]
- **Solution**: [The fix — include exact command/code]
- **Category**: [docker | drupal-api | php | drush | composer | phpcs | phpstan | phpunit | twig | playwright | beads | permissions | other]
- **Applies to**: [agent:name | skill:name | rule:name | CLAUDE.md]
- **Suggested improvement**: [What to add to the target so this never happens again]
```

### Session Start Check

```bash
# Check for existing lessons before starting work
test -f LESSONS_LEARNED.md && echo "=== LESSONS LEARNED ===" && cat LESSONS_LEARNED.md | head -100
```

### During Ralph Loop

In autonomous mode, lesson documentation is **critical** — the same mistake across 50+ iterations wastes significant time and tokens. Document immediately so subsequent iterations benefit within the same run.

### Goal

The `LESSONS_LEARNED.md` file serves as a **staging area**. The user will periodically review it and promote lessons into permanent agent/skill/rule updates. This creates a feedback loop:

```
Error occurs → Agent solves it → Documents lesson → User reviews →
Updates agent/skill/rule → Future sessions avoid the error entirely
```

---

## Git Version Control Policy (CRITICAL)

### Agents MUST NOT:
- Run `git commit` commands
- Run `git push` commands
- Run `git add` commands
- Create commits automatically after making changes
- Push changes to remote repositories

### Agents SHOULD:
- Present a clear summary of all file changes
- Suggest appropriate commit messages
- List modified files for user review
- Use `bd sync` to sync Beads state (does not commit code)

### User Workflow:
1. Agent makes changes and presents summary
2. User reviews all changes
3. User runs `git add`, `git commit`, `git push` manually
4. User has full control over what gets committed

**Remember**: The user explicitly wants to review ALL code before committing. Never bypass this workflow.

---

## Web Interaction Policy (CRITICAL)

For browser testing, use the **playwright-browser-testing** skill. It covers
tools, authentication, SSL workarounds, screenshots, selectors, and troubleshooting.

**Four non-negotiable rules:**
1. **NEVER use curl** for testing Drupal pages — use Playwright MCP
2. **ALWAYS use HTTP** (not HTTPS) for all Playwright navigation in DDEV
3. **Authenticate with `docker exec $WEB_CONTAINER ./vendor/bin/drush uli`** for admin/protected pages (convert returned HTTPS URL to HTTP)
4. **NEVER create JavaScript/Playwright script files** (`.js`, `.mjs`, `.ts`) to interact with the browser — always use MCP tools (`browser_navigate`, `browser_screenshot`, etc.) directly. If MCP fails, troubleshoot the connection — do NOT generate scripts as a workaround

Delegate browser testing tasks to the **visual-test** agent.

---

## Code Standards (Non-Negotiable)

```php
<?php

declare(strict_types=1);  // ALWAYS

namespace Drupal\mymodule\Service;

// Type hints on ALL parameters and returns
public function process(string $input): array {
  // Dependency injection, never \Drupal::service() in classes
}
```

- 2-space indentation (Drupal standard)
- No debug code: `dpm()`, `kint()`, `var_dump()`, `console.log()`
- Cache metadata on ALL render arrays

---

## Reference Resources

### Examples for Developers Module
The [Examples for Developers](https://www.drupal.org/project/examples) module provides well-documented, working code samples for Drupal's core APIs. Install it as a dev dependency:

```bash
docker exec $WEB_CONTAINER composer require --dev drupal/examples
```

Available examples at `$DDEV_DOCROOT/modules/contrib/examples/`:
- **block_example** - Block plugins
- **form_api_example** - Forms, AJAX, multistep forms
- **hooks_example** - Hook implementations
- **events_example** - Event subscribers
- **plugin_type_example** - Custom plugin types
- **batch_example** - Batch operations
- **queue_example** - Queue workers
- **render_example** - Render arrays and caching
- **cache_example** - Cache API usage

**Always consult relevant example modules before implementing new patterns.**

---

## Quick Commands

### Drupal/PHP (via docker exec)

**IMPORTANT: All drush commands require `./vendor/bin/drush` path**

```bash
# Cache
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# Config
docker exec $WEB_CONTAINER ./vendor/bin/drush cex -y
docker exec $WEB_CONTAINER ./vendor/bin/drush cim -y

# Authentication (for Playwright testing)
docker exec $WEB_CONTAINER ./vendor/bin/drush uli
# Returns HTTPS URL - convert to HTTP for Playwright

# Code quality — ALWAYS check for Audit module first (MANDATORY)
# Step 0: docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
# If installed (PRIMARY — use this):
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --filter="module:mymodule" --format=json
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpstan --filter="module:mymodule" --format=json
# FALLBACK ONLY if Audit module not installed:
docker exec $WEB_CONTAINER ./vendor/bin/phpcs $DDEV_DOCROOT/modules/custom
docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom --level=8

# Tests
docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule

# Updates
docker exec $WEB_CONTAINER composer outdated --direct
docker exec $WEB_CONTAINER composer update --with-all-dependencies
docker exec $WEB_CONTAINER ./vendor/bin/drush updatedb -y
```

### Beads Task Tracking

```bash
# Session start
bd prime                              # Get context
bd ready --json                       # List ready tasks

# Task management
bd create "Title" -p 1 --json         # Create task (P0-P3)
bd show bd-abc --json                 # View task
bd update bd-abc --status in_progress # Update status
bd update bd-abc --notes "Progress"   # Add notes
bd close bd-abc --reason "Done"       # Close task

# Session end
bd sync                               # Sync to git
bd doctor                             # Check health
```
