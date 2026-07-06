# Drupal AI Agents

## Language

- **User interaction**: Respond in the same language the user writes in.
- **Everything else in English**: All code, variables, functions, comments, docblocks, commit messages, and generated content must always be in English.
- **Skills and agents**: Match the user's intent to the appropriate English-defined skill by semantic meaning, not literal keyword matching.

## Design Principles

- **Simple and elegant solutions first.** Always prefer the simplest, cleanest approach. Avoid over-engineering.

## DDEV Environment

You run inside an AI container (OpenCode or Claude Code). The project uses multiple DDEV containers:

| Container | Access method | Purpose |
|-----------|---------------|---------|
| **Your container** | Direct | Agents, file access, bash |
| **Web** (`web`) | SSH | PHP, Drupal, Drush, Composer |
| **Beads** (`beads`) | `bd` wrapper | Git-backed task tracking |
| **Playwright MCP** (`$PLAYWRIGHT_MCP_URL`) | HTTP MCP | Chromium browser testing |

**All PHP/Drupal commands must use SSH:**

```bash
ssh web drush cr
ssh web ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule
```

**CRITICAL**: Always use `ssh web drush <command>` to run Drush commands (the `drush` alias is available in the web container's PATH).
**CRITICAL**: Never hardcode `web/` -- use `$DDEV_DOCROOT` (varies per project: `web/`, `docroot/`, etc.).

**Available variables:** `$DDEV_PRIMARY_URL` (HTTPS), `$DDEV_HTTP_URL` (HTTP — use for browser testing), `$DDEV_SITENAME`, `$DDEV_DOCROOT`, `$PLAYWRIGHT_MCP_URL`

## Model Strategy

Agents use model tokens that resolve to real model names at sync time:

| Token | Default | Used for |
|-------|---------|----------|
| `MODEL_MAIN` | CHEAP (OpenCode) / NORMAL (Claude Code) | The orchestrator: main conversation loop that receives prompts and delegates |
| `MODEL_GENIUS` | same as SMART | Hardest tasks: important code reviews, architecture decisions |
| `MODEL_SMART` | Opus 4.6 | Quality gates, planning, research, delegation advice |
| `MODEL_NORMAL` | Sonnet 4.5 | Development, review |
| `MODEL_CHEAP` | Haiku 4.5 | Exploration, fast tasks |
| `MODEL_APPLIER` | Haiku 4.5 | Mechanical code application |
| `MODEL_VISION` | same as NORMAL | Image/screenshot interpretation — must accept image input |

`GENIUS` falls back to `SMART`, `VISION` falls back to `NORMAL`, and `MAIN` falls back to `CHEAP` (OpenCode) / `NORMAL` (Claude Code) when not defined. Most NORMAL/CHEAP models cannot see images — anything that must interpret a screenshot goes through `MODEL_VISION` (the `visual-analyzer` agent). The orchestrator model dominates session cost, which is why `MODEL_MAIN` is deliberately cheap — quality comes from delegating to the right specialist, not from the orchestrator itself.

To change models, define only the variables you want to override (variable-level cascade, higher wins): repo `.env.agents` < `~/.ddev/agents-sync/.env.agents` on the host (all projects) < `.ddev/.env.agents` (one project).

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `drupal-dev` | NORMAL | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | NORMAL | Frontend: Twig, CSS, JS, Tailwind |
| `drupal-test-generator` | NORMAL | Test generation: analyzes code, picks test type, generates tests |
| `code-explorer` | CHEAP | Codebase exploration (use before specialized agents) |
| `task-router` | SMART | Delegation advisor: decides which agent should handle a task |
| `applier` | APPLIER | Apply SEARCH/REPLACE blocks mechanically |
| `code-review` | GENIUS | Quality gate: correctness, security, Drupal quality, performance |
| `output-verifier` | SMART | Validate outputs against requirements |
| `deep-research` | NORMAL | Multi-source investigation, technical comparisons |
| `ralph-planner` | SMART | Generate requirements.md for autonomous execution |
| `visual-test` | VISION | Playwright MCP browser automation |
| `visual-analyzer` | VISION | Interprets image/screenshot content: design review, UI analysis, comparisons |

### When to Use Each Agent

| Scenario | Agent |
|----------|-------|
| Need to find files or understand code structure | `code-explorer` |
| Backend PHP: modules, services, entities, plugins | `drupal-dev` |
| Frontend: Twig, CSS, JS, Tailwind | `drupal-theme` |
| Generate tests for Drupal code | `drupal-test-generator` |
| Validate code quality (pre/post implementation) | `code-review` |
| Validate non-code outputs (plans, configs, docs) | `output-verifier` |
| Browser screenshots and visual verification | `visual-test` |
| Interpret what a screenshot/image SHOWS (design, UI, comparisons) | `visual-analyzer` |
| Technical research across multiple sources | `deep-research` |
| Generate requirements.md for Ralph autonomous loop | `ralph-planner` |
| Apply SEARCH/REPLACE blocks mechanically | `applier` |
| Unsure which agent fits, task spans several agents, or needs decomposition | `task-router` |

**Invocation:** OpenCode uses `Task: agent-name`. Claude Code uses `Agent` tool with `subagent_type`.

**Agents with Agent tool** (can delegate to applier): `drupal-dev`, `drupal-theme`.

### Delegation Protocol

You (the main conversation) run on `MODEL_MAIN`, a cheap model chosen for coordination. Act as a dispatcher, not a specialist:

1. **Clear match** → delegate directly to the agent from the table above.
2. **Unclear match, multi-agent task, or complex decomposition** → invoke `task-router` with a short task description and the relevant context (paths, requirements, constraints — not file dumps). Follow the routing plan it returns.
3. **Trivial work** (answer from context, a one-line edit, run a command) → handle inline; delegating it costs more than doing it.
4. **Never do specialist work inline** (backend PHP, theming, test generation, code review, research) — the specialists run on stronger models than you. Doing their work yourself produces worse results AND wastes the cost savings.

## The Applier Pattern

Agents that cannot edit files directly generate **SEARCH/REPLACE blocks**, then delegate to `applier`.

**Modify existing file:**
```
path/to/file.ext
<<<<<<< SEARCH
[exact lines to find - include 2-3 context lines]
=======
[replacement code - preserve indentation exactly]
>>>>>>> REPLACE
```

**Create new file:**
```
path/to/new/file.ext
<<<<<<< CREATE
[full file content]
>>>>>>> CREATE
```

After generating blocks, delegate to the `applier` agent with the blocks as input.

## Git Policy

Git write access is **configurable per environment** via two flags in
`.env.agents`: `GIT_ALLOW_COMMIT` (git add/commit) and `GIT_ALLOW_OPERATIONS`
(push, pull, merge, rebase, checkout, reset, …). **By default nothing is
allowed** — you present a summary of changes and the user commits manually. The
**git-workflow** rule states the policy currently in effect — follow it. Even
when a git write is allowed, run it ONLY when the user explicitly asks for it —
never on your own initiative. Force-push and remote-branch deletion are
**never** allowed, regardless of the flags. When a git command is blocked,
present the changes instead of working around the block.

## Web Testing

- Use the **visual-test** agent or Playwright MCP tools directly
- **NEVER use curl** for testing Drupal pages
- **ALWAYS use HTTP** (not HTTPS) for Playwright navigation in DDEV — navigate to `$DDEV_HTTP_URL`
- **NEVER create JS/Playwright script files** -- use MCP tools (`browser_navigate`, `browser_take_screenshot`, etc.) directly
- Authenticate with `ssh web drush uli` (replace `https://` with `http://` in the returned URL before navigating)

## Rules and Skills

**Rules** are always-on instructions. Every rule file is loaded in BOTH tools:
- **Claude Code**: loads every file in `.claude/rules/` automatically at session start (native feature).
- **OpenCode**: has no auto-loaded rules directory — rules load via the `instructions` glob in `opencode.json`: `~/.config/opencode/rules/*.md`. The `~/` form is required: plain relative paths resolve against the project (not the config dir) and fail silently.

Adding a new rule = drop a `.md` file in `.claude/rules/` — no registration needed for either tool.

**Skills** are auto-discovered from `.claude/skills/`. Key skills:

| Skill | Purpose |
|-------|---------|
| `quality-checks` | PHPCS, PHPStan, Rector, PHPUnit (Audit module primary) |
| `code-analysis` | Standalone quality report: BLOCKERS vs SUGGESTIONS, second-opinion runs |
| `screenshot-analysis` | Interpret screenshot/image content (requires vision model) |
| `drupal-testing` | Test orchestrator: analyzes code, delegates to specialized test skills |
| `drupal-unit-test` | Unit test generation and mock patterns |
| `drupal-kernel-test` | Kernel tests: services, entities, DB, config, plugins |
| `drupal-functional-test` | Functional tests: forms, permissions, HTML output |
| `drupal-functionaljs-test` | FunctionalJavascript: AJAX, modals, autocompletes |
| `drupal-behat-test` | Behat: BDD, acceptance testing, Gherkin |
| `drupal-playwright-test` | Playwright: visual regression, cross-browser, E2E |
| `performance-audit` | Caching, queries, lazy builders, bottlenecks |
| `drupal-update` | Safe Composer update workflow |
| `twig-audit` | Template anti-patterns and cache bubbling |
| `beads-task-tracking` | Beads (bd) task management |
| `module-scaffold` | Scaffold new custom modules |
| `playwright-testing` | Browser automation and screenshots (MCP tools) |
| `tailwind-drupal` | TailwindCSS in Drupal |
| `commit-message` | Generate commit messages from git diff |

## Beads Task Tracking

### Session Start

```bash
# NEVER run `bd init` — the beads container auto-initializes on start.
ls .beads/ 2>/dev/null || echo "Beads not initialized — ask the user to run: ddev restart"
bd prime
bd ready --json
```

### During Work

```bash
bd create "Implement feature X" -p 1 --json
bd update bd-abc --status in_progress
bd update bd-abc --notes "Progress notes"
bd close bd-abc --reason "Completed and tested" --json
```

### Session End (mandatory)

```bash
bd create "TODO: remaining work" -p 2 --json    # File remaining items
bd close bd-xyz --reason "Done" --json           # Close completed tasks
bd update bd-abc --notes "Paused at: ..."        # Context for in-progress
# Present summary of changes for user review
```

**WARNING**: Never use `bd edit` -- it opens an interactive editor that will hang.
