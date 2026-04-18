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

**Available variables:** `$DDEV_PRIMARY_URL`, `$DDEV_SITENAME`, `$DDEV_DOCROOT`, `$PLAYWRIGHT_MCP_URL`

## Model Strategy

Agents use model tokens that resolve to real model names at sync time:

| Token | Default | Used for |
|-------|---------|----------|
| `MODEL_SMART` | Opus 4.6 | Quality gates, planning, research |
| `MODEL_NORMAL` | Sonnet 4.5 | Development, review |
| `MODEL_CHEAP` | Haiku 4.5 | Exploration, fast tasks |
| `MODEL_APPLIER` | Haiku 4.5 | Mechanical code application |

To change models globally, edit `.env.agents` in the agent repository.

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `drupal-dev` | NORMAL | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | NORMAL | Frontend: Twig, CSS, JS, Tailwind |
| `drupal-test-generator` | NORMAL | Test generation: analyzes code, picks test type, generates tests |
| `code-explorer` | CHEAP | Codebase exploration (use before specialized agents) |
| `applier` | APPLIER | Apply SEARCH/REPLACE blocks mechanically |
| `code-review` | SMART | Quality gate: correctness, security, Drupal quality, performance |
| `output-verifier` | SMART | Validate outputs against requirements |
| `deep-research` | NORMAL | Multi-source investigation, technical comparisons |
| `ralph-planner` | SMART | Generate requirements.md for autonomous execution |
| `visual-test` | NORMAL | Playwright MCP browser automation |

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
| Technical research across multiple sources | `deep-research` |
| Generate requirements.md for Ralph autonomous loop | `ralph-planner` |
| Apply SEARCH/REPLACE blocks mechanically | `applier` |

**Invocation:** OpenCode uses `Task: agent-name`. Claude Code uses `Agent` tool with `subagent_type`.

**Agents with Agent tool** (can delegate to applier): `drupal-dev`, `drupal-theme`.

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

**Agents MUST NOT:** run `git commit`, `git push`, or `git add`.

Present a clear summary of all file changes. The user reviews and commits manually. Use `bd sync` for Beads state only (does not commit code).

## Web Testing

- Use the **visual-test** agent or Playwright MCP tools directly
- **NEVER use curl** for testing Drupal pages
- **ALWAYS use HTTP** (not HTTPS) for Playwright navigation in DDEV
- **NEVER create JS/Playwright script files** -- use MCP tools (`browser_navigate`, `browser_screenshot`, etc.) directly
- Authenticate with `ssh web drush uli` (convert returned HTTPS URL to HTTP)

## Rules and Skills

**Rules** auto-load based on file paths (see `.claude/rules/`). Path-scoped rules activate only for matching files (e.g., `drupal-coding-standards` for `*.php`, `twig-patterns` for `*.twig`). Global rules (git-workflow, beads-workflow) apply always.

**Skills** are auto-discovered from `.claude/skills/`. Key skills:

| Skill | Purpose |
|-------|---------|
| `quality-checks` | PHPCS, PHPStan, Rector, PHPUnit (Audit module primary) |
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
ls -la .beads/ 2>/dev/null || bd init --quiet
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
bd sync                                          # Sync Beads state
# Present summary of changes for user review
```

**WARNING**: Never use `bd edit` -- it opens an interactive editor that will hang.
