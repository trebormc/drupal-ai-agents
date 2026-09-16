[![last commit](https://img.shields.io/github/last-commit/trebormc/drupal-ai-agents)](https://github.com/trebormc/drupal-ai-agents/commits)
[![release](https://img.shields.io/github/v/release/trebormc/drupal-ai-agents)](https://github.com/trebormc/drupal-ai-agents/releases/latest)

# Drupal AI Agents

The **brain** of the [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace). A comprehensive set of AI agents, rules, skills, and configuration for **Drupal 10/11** development. Designed for [OpenCode](https://opencode.ai) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code), compatible with [DDEV](https://ddev.readthedocs.io/) environments.

> **Part of [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace)** — a modular ecosystem of DDEV add-ons for AI-powered Drupal development. Install the full stack with one command: `ddev add-on get trebormc/ddev-ai-workspace`
>
> Created by [Robert Menetray](https://menetray.com) · Sponsored by [DruScan](https://druscan.com)

This repository is **not** a DDEV add-on. It is a configuration package that gets synced into OpenCode and Claude Code containers via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync). It provides 11 specialized agents, 17 rules, and 38 skills tailored for Drupal development. The agents understand Drupal APIs, coding standards, caching, render arrays, the module/theme ecosystem, and quality tools like PHPStan, PHPCS, and PHPUnit.

## Quick Install

### With DDEV AI Workspace (recommended)

The **recommended way** is to install the full [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace), which installs all tools and syncs this repository automatically with a single command:

```bash
ddev add-on get trebormc/ddev-ai-workspace
ddev restart
ddev opencode    # or: ddev claude-code
```

### With a single AI tool

If you only install [ddev-opencode](https://github.com/trebormc/ddev-opencode) or [ddev-claude-code](https://github.com/trebormc/ddev-claude-code), this repository is also **automatically synced** via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync). No manual clone is needed.

```bash
ddev add-on get trebormc/ddev-opencode
ddev restart
ddev opencode
```

To add private agent repos alongside the public ones, edit `.ddev/.env.agents-sync`:

```bash
AGENTS_REPOS=https://github.com/trebormc/drupal-ai-agents.git,https://github.com/your-org/private-agents.git
```

To manually trigger an update: `ddev agents-update`

### Standalone (without DDEV)

```bash
# Clone directly to the OpenCode config directory
git clone https://github.com/trebormc/drupal-ai-agents.git ~/.config/opencode

# Copy and customize the config
cd ~/.config/opencode
cp opencode.json.example opencode.json
vi opencode.json

# Authenticate
opencode auth login

# Run
opencode
```

## Directory Structure

```
drupal-ai-agents/
├── CLAUDE.md                          Main instructions (language, design, environment, agents)
├── opencode.json.example             OpenCode config template (copy to opencode.json)
├── opencode-notifier.json            Notification bridge config (used automatically)
├── .env.agents                       Model alias definitions (tokens → real model names)
├── install.sh                        Installation helper script (standalone mode)
├── .claude/
│   ├── settings.json                 Claude Code permissions and hooks
│   ├── agents/                       11 agent definitions (.md files with fat frontmatter)
│   │   ├── applier.md
│   │   ├── code-explorer.md
│   │   ├── code-review.md
│   │   ├── drupal-dev.md
│   │   ├── drupal-test-generator.md
│   │   ├── drupal-theme.md
│   │   ├── output-verifier.md
│   │   ├── ralph-planner.md
│   │   ├── task-router.md
│   │   ├── visual-analyzer.md
│   │   └── visual-test.md
│   ├── rules/                        17 rule sets loaded as instructions
│   │   ├── applier-protocol.md
│   │   ├── beads-workflow.md
│   │   ├── coding-behavior.md
│   │   ├── config-management.md
│   │   ├── ddev-environment.md
│   │   ├── drupal-coding-standards.md
│   │   ├── drupal-testing.md
│   │   ├── engineering-principles.md
│   │   ├── epistemic-discipline.md
│   │   ├── git-workflow.md
│   │   ├── lessons-learned.md
│   │   ├── quality-tools-setup.md
│   │   ├── security-rules.md
│   │   ├── services-conventions.md
│   │   ├── task-playbooks.md
│   │   ├── translations.md
│   │   └── twig-patterns.md
│   └── skills/                       38 reusable skills
│       ├── arena-protocol/SKILL.md
│       ├── beads-task-tracking/SKILL.md
│       ├── commit-message/SKILL.md
│       ├── config-management/SKILL.md
│       ├── drupal-accessibility/SKILL.md
│       ├── drupal-audit-setup/SKILL.md
│       ├── drupal-behat-test/SKILL.md
│       ├── drupal-blast-radius/SKILL.md
│       ├── drupal-code-patterns/SKILL.md
│       ├── drupal-debugging/SKILL.md
│       ├── drupal-functional-test/SKILL.md
│       ├── drupal-functionaljs-test/SKILL.md
│       ├── drupal-kernel-test/SKILL.md
│       ├── drupal-migration/SKILL.md
│       ├── drupal-playwright-test/SKILL.md
│       ├── drupal-render-pipeline/SKILL.md
│       ├── drupal-testing/SKILL.md
│       ├── drupal-unit-test/SKILL.md
│       ├── drupal-update/SKILL.md
│       ├── drupal-verification-skill/SKILL.md
│       ├── drush-commands/SKILL.md
│       ├── module-scaffold/SKILL.md
│       ├── performance-audit/SKILL.md
│       ├── playwright-testing/SKILL.md
│       ├── quality-checks/SKILL.md
│       ├── session-distill/SKILL.md
│       ├── skill-creator/SKILL.md
│       ├── tailwind-drupal/SKILL.md
│       ├── technical-writing/SKILL.md
│       ├── twig-audit/SKILL.md
│       └── xdebug-profiling/SKILL.md
└── docs/                             Additional documentation
    ├── architecture.md
    ├── model-strategy.md
    └── ralph-loop.md
```

## Model Token System

Agent `.md` files use **model tokens** instead of hardcoded model names. This makes agents portable across OpenCode and Claude Code, and allows changing models globally from a single file.

### Tokens

| Token | Default | Use for |
|-------|---------|---------|
| `${MODEL_MAIN}` | CHEAP (OpenCode) / NORMAL (Claude Code) | The orchestrator: default model of the main conversation loop |
| `${MODEL_GENIUS}` | same as SMART | Hardest tasks: important code reviews, architecture decisions |
| `${MODEL_SMART}` | Opus 4.6 | Quality gates, planning, research, delegation advice |
| `${MODEL_NORMAL}` | Sonnet 4.5 | General-purpose tasks |
| `${MODEL_CHEAP}` | Haiku 4.5 | Fast, cost-effective agents |
| `${MODEL_APPLIER}` | Haiku 4.5 | Mechanical code application |
| `${MODEL_VISION}` | same as NORMAL | Image/screenshot interpretation — MUST accept image input |

When not defined in `.env.agents`, `GENIUS` falls back to `SMART`, `VISION` falls back to `NORMAL`, and `MAIN` falls back to `CHEAP` on OpenCode / `NORMAL` on Claude Code, so older override files keep working. Override `GENIUS` with a stronger model when available; `VISION` must be vision-capable or image analysis agents cannot see screenshots.

`${MODEL_MAIN}` sets the DEFAULT model of the tool itself, not an agent: the sync injects it as the top-level `model` in the generated `opencode.json` and as the `model` key in the generated Claude Code settings. It is deliberately a cheap tier because the main conversation dominates session cost — the orchestrator delegates specialist work and consults the `task-router` agent when the routing is unclear (see [docs/model-strategy.md](docs/model-strategy.md)).

### Changing models

Edit `.env.agents` to change which models all agents use:

```bash
# OpenCode models (provider/model-id format)
OC_MODEL_MAIN=opencode/deepseek-v4-flash
OC_MODEL_GENIUS=opencode/glm-5.2
OC_MODEL_SMART=opencode/glm-5.2
OC_MODEL_NORMAL=opencode/deepseek-v4-pro
OC_MODEL_CHEAP=opencode/deepseek-v4-flash
OC_MODEL_APPLIER=opencode/gpt-5-nano
OC_MODEL_VISION=opencode/minimax-m3

# Claude Code models (native aliases)
CC_MODEL_MAIN=sonnet
CC_MODEL_GENIUS=opus
CC_MODEL_SMART=opus
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
CC_MODEL_VISION=sonnet
```

When synced via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync), `envsubst` replaces tokens with the correct values for each tool. To override without forking this repo, create a private repo with just `.env.agents` and add it as a second entry in `AGENTS_REPOS`.

## Fat Frontmatter

Each agent `.md` uses a single frontmatter that works for both OpenCode and Claude Code:

```yaml
---
description: Short description of the agent.
model: ${MODEL_CHEAP}

# OpenCode fields (Claude Code ignores these)
mode: subagent
tools:
  read: true
  glob: true
  grep: true
  bash: false
permission:
  bash: deny

# Claude Code field (OpenCode ignores this)
allowed_tools: Read, Glob, Grep
---

Agent system prompt here...
```

During sync, [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync) generates separate copies:
- **OpenCode** (`/agents-opencode/`): removes `allowed_tools:`, keeps everything else
- **Claude Code** (`/agents-claude/`): removes `mode:`, `tools:` (object), `permission:`, renames `allowed_tools:` → `tools:`

## Agents

### Drupal Development

| Agent | Token | Purpose |
|-------|-------|---------|
| `drupal-dev` | `MODEL_NORMAL` | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | `MODEL_NORMAL` | Frontend: Twig, CSS, JS, Tailwind, responsive |
| `drupal-test-generator` | `MODEL_NORMAL` | Test generation: analyzes code, picks type, generates tests |

### Quality and Validation

| Agent | Token | Purpose |
|-------|-------|---------|
| `code-review` | `MODEL_GENIUS` | Judge panel (correctness, security, quality, performance, accessibility, translations, test coverage): PLAN mode → Implementation Contract; CODE mode → tiered-veto verdict + plan conformance |
| `output-verifier` | `MODEL_SMART` | Validate outputs with high confidence |
| `visual-test` | `MODEL_VISION` | Playwright browser screenshots and UI checks |
| `visual-analyzer` | `MODEL_VISION` | Interprets image/screenshot content: design review, comparisons |

### Utilities

| Agent | Token | Purpose |
|-------|-------|---------|
| `code-explorer` | `MODEL_CHEAP` | Context firewall for exploration: sweeps hundreds of candidates in its own disposable context, returns only relevant paths with file:line pointers and minimal excerpts |
| `task-router` | `MODEL_SMART` | Delegation advisor: tells the cheap orchestrator which agent should handle a task |
| `applier` | `MODEL_APPLIER` | Mechanical code application (SEARCH/REPLACE) |
| `ralph-planner` | `MODEL_SMART` | Generate requirements.md for Ralph Loop |

## Rules

All rules are always-on global instructions, loaded in both tools: Claude Code reads `.claude/rules/` natively; OpenCode loads them via the `instructions` glob (`~/.config/opencode/rules/*.md`) in `opencode.json`. Adding a new rule requires no registration.

| File | Scope | Purpose |
|------|-------|---------|
| `coding-behavior.md` | Global | LLM behavioral guardrails: surface assumptions, simplicity first, surgical changes, verifiable goals |
| `epistemic-discipline.md` | Global | Reasoning guardrails: intent under the words, risk-weighted effort, evidence over plausibility, confidence labels, self-attack, answer-first reporting |
| `engineering-principles.md` | Global | Design defaults with their triggers: laziness, subtract first, model the domain, boundary discipline, idempotent operations, build the lever, prove it works, fix root causes, encode lessons in structure |
| `task-playbooks.md` | Global | Task-shaped workflows: investigation, bug fix (reproduce → binary search → failing test → same-surface verify), feature, refactoring (pin behavior first), prototype, autonomous run, session handoff; the "tests alone are not sufficient" bar |
| `drupal-coding-standards.md` | Global | Strict types, 2-space indent, type hints, DI, cache metadata, quality checklist |
| `twig-patterns.md` | Global | Presentation only, render full fields, cache bubbling, anti-patterns |
| `drupal-testing.md` | Global | Test type decision tree, D10 vs D11 differences, common rules |
| `beads-workflow.md` | Global | Beads task tracking: session start, during work, session end |
| `quality-tools-setup.md` | Global | PHPStan, PHPCS, Rector, GrumPHP, PHPUnit setup (Audit module priority) |
| `lessons-learned.md` | Global | Self-learning protocol: document problems and solutions |
| `services-conventions.md` | Global | Service definitions, DI, interfaces, event subscribers, tagging |
| `applier-protocol.md` | Global | SEARCH/REPLACE block format for code changes |
| `config-management.md` | Global | Config export/import, config_split, schema validation |
| `security-rules.md` | Global | Input sanitization, DB placeholders, route access, CSRF |
| `translations.md` | Global | i18n contract: English source strings ALWAYS, `t()`/`\|t`/`Drupal.t()` on all user-facing text, literals + placeholders only |
| `ddev-environment.md` | Global | Docker exec commands, environment variables, Audit module priority |
| `git-workflow.md` | Global | Configurable per-tool git access (GIT_ALLOW_COMMIT / GIT_ALLOW_OPERATIONS list opencode/claude); default: user commits manually |

## Skills

Reusable skill definitions that agents can invoke:

### Testing

| Skill | Description |
|-------|-------------|
| `drupal-testing` | Test orchestrator: analyzes code, determines type, delegates to specialized skills |
| `drupal-unit-test` | Unit tests with proper mocking patterns |
| `drupal-kernel-test` | Kernel tests: services, entities, DB, config, plugins, hooks |
| `drupal-functional-test` | Functional tests: forms, permissions, HTML output |
| `drupal-functionaljs-test` | FunctionalJavascript: AJAX, modals, autocompletes, WebDriverTestBase |
| `drupal-behat-test` | Behat: BDD, acceptance testing, Gherkin scenarios |
| `drupal-playwright-test` | Playwright: visual regression, cross-browser, E2E test files |
| `drupal-test-suite-audit` | Audit and refactor an existing test suite: remove zero-value tests, close DI gaps |

### Development

| Skill | Description |
|-------|-------------|
| `module-scaffold` | Scaffold a new module with PSR-4 structure |
| `drupal-code-patterns` | Reference patterns: forms, blocks, routing, controllers, Batch/Queue API |
| `drupal-migration` | D7-to-D10/D11 upgrades, custom migrations (CSV, JSON, API, SQL) |
| `drupal-update` | Safe Composer update workflow: core, contrib, security patches |
| `config-management` | Configuration export/import, config_split, schema validation |
| `drupal-debugging` | Inspect services, entities, cache, watchdog logs, database queries |
| `drush-commands` | Cache clearing, database updates, module management, cron |

### Quality and Performance

| Skill | Description |
|-------|-------------|
| `quality-checks` | Full quality pipeline: Audit module primary, raw PHPCS/PHPStan fallback |
| `code-analysis` | Standalone quality report: BLOCKERS vs SUGGESTIONS, cross-tool second opinion |
| `drupal-audit-setup` | Install and configure the Drupal Audit module |
| `performance-audit` | Caching, queries, lazy builders, bottlenecks, N+1 detection |
| `drupal-render-pipeline` | Expert render/caching semantics: max-age bubbling, AccessResult cacheability, lazy builder constraints, escaping |
| `twig-audit` | Template anti-patterns, cache bubbling, raw filter misuse |
| `phpstan-phpcs-conflict-resolution` | Resolve PHPCS/PHPStan conflicts and suppression mechanics |
| `drupal-security-coverage-prep` | Audit against the drupal.org security review checklist |
| `drupal-blast-radius` | What a change breaks outside the diff: hook implementers, decorators, views/displays, config dependencies, templates; proves the safety fact by running code |

### Browser and UI

| Skill | Description |
|-------|-------------|
| `playwright-testing` | Interactive browser testing with Playwright MCP (navigation, screenshots) |
| `tailwind-drupal` | TailwindCSS setup and usage in Drupal themes |
| `drupal-accessibility` | WCAG 2.2 AA the Drupal way: Form API ARIA, #states vs #access, hiding utilities, Drupal.announce |
| `screenshot-analysis` | Interpret screenshot/image content: design review, comparisons (vision model) |
| `drupal-verification-skill` | Generate and maintain a project-local `verify-<site>` skill: launch/doctor, Playwright + drush recipes, evidence rules, feature map |

### Contribution

| Skill | Description |
|-------|-------------|
| `drupal-org-contribution-prep` | Prepare a module for drupal.org: CI, suite registration, hygiene |
| `drupal-multi-version-compat` | Drupal 10/11/12 compatibility and Project Update Bot triage |

### Workflow and Utilities

| Skill | Description |
|-------|-------------|
| `beads-task-tracking` | Git-backed task tracking with Beads (bd) |
| `commit-message` | Generate commit messages from git diff (Conventional Commits format) |
| `xdebug-profiling` | Xdebug tracing and profiling for debugging and performance |
| `skill-creator` | Create and validate new OpenCode skills |
| `session-distill` | Convert verified session learnings (failed attempts + final fix) into durable guidance: patch, project skill, or new shared skill |
| `technical-writing` | Module READMEs, change records, drupal.org issue summaries, ADRs, MR bodies: one Diátaxis mode per document, plain sentences, no AI tells |
| `arena-protocol` | The three roles inside a [ddev-ai-arena](https://github.com/trebormc/ddev-ai-arena) run: project manager (brief with contract + mechanical rubric, verdict trailer), candidate (isolated copy, `arena-report.md` with `STATUS`), judge (gates, rubric, conformance, then quality, blind) |

## Customization

### Adding your own agents

Create a `.md` file in `.claude/agents/` with fat frontmatter and a system prompt:

```yaml
---
description: My custom agent for code review.
model: ${MODEL_NORMAL}
mode: subagent
tools:
  read: true
  glob: true
  grep: true
  bash: false
  write: false
  edit: false
permission:
  bash: deny
allowed_tools: Read, Glob, Grep
---

You are a code review specialist...
```

The agent is auto-discovered from the `.claude/agents/` directory. Use model tokens (`${MODEL_GENIUS}`, `${MODEL_SMART}`, `${MODEL_NORMAL}`, `${MODEL_CHEAP}`, `${MODEL_APPLIER}`, `${MODEL_VISION}`) so the sync script resolves them correctly for each tool.

### Adding rules

1. Create a `.md` file in the `.claude/rules/` directory.
2. No registration needed: Claude Code reads `.claude/rules/` natively and OpenCode loads every rule through the `instructions` glob in `opencode.json`. Rules are always in context in both tools, so keep them short.

### Adding skills

1. Create a `SKILL.md` file in `.claude/skills/{skill-name}/` following the [Agent Skills specification](https://agentskills.io).
2. Skills are auto-discovered from the `.claude/skills/` directory. No config changes needed.

### Private agent repo

To add custom agents without forking this repo:

1. Create a git repository with the same structure (`.claude/agents/`, `.claude/rules/`, `.claude/skills/`, `.env.agents`).
2. Add it to `AGENTS_REPOS` in `.ddev/.env.agents-sync`:
   ```bash
   AGENTS_REPOS=https://github.com/trebormc/drupal-ai-agents.git,https://github.com/your-org/private-agents.git
   ```
3. Files from your repo override the public ones (same filename = override).

## Part of DDEV AI Workspace

This configuration package is part of [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace), a modular ecosystem of DDEV add-ons for AI-powered Drupal development.

| Repository | Description | Relationship |
|------------|-------------|--------------|
| [ddev-ai-workspace](https://github.com/trebormc/ddev-ai-workspace) | Meta add-on that installs the full AI development stack with one command. | Workspace |
| [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync) | Auto-syncs this repo, resolves model tokens, generates tool-specific configs. | Syncs this package |
| [ddev-opencode](https://github.com/trebormc/ddev-opencode) | [OpenCode](https://opencode.ai) AI CLI container. Reads agents from `/agents-opencode`. | Consumer |
| [ddev-claude-code](https://github.com/trebormc/ddev-claude-code) | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI container. Reads agents from `/agents-claude`. | Consumer |
| [ddev-ralph](https://github.com/trebormc/ddev-ralph) | Autonomous AI task orchestrator. Uses `ralph-planner` agent and Beads workflow. | Consumer |
| [ddev-ai-arena](https://github.com/trebormc/ddev-ai-arena) | Host package (skill + scripts, not a DDEV add-on) that runs N AI candidates in isolated worktree environments, gates them mechanically and judges them blind. | Consumer: the `arena-protocol` skill defines its roles |
| [ddev-beads](https://github.com/trebormc/ddev-beads) | [Beads](https://github.com/steveyegge/beads) git-backed task tracker. | Task tracking |
| [ddev-ai-ssh](https://github.com/trebormc/ddev-ai-ssh) | SSH access to the web container. Generates per-project keys, installs sshd. | SSH infrastructure |
| [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) | Headless Playwright browser for visual testing. | Browser automation |

## Disclaimer

This project is an independent initiative by [Robert Menetray](https://menetray.com), sponsored by [DruScan](https://druscan.com). It is not affiliated with Anthropic, OpenCode, Beads, Playwright, Microsoft, or DDEV. AI-generated code may contain errors. Always review changes before deploying to production.

## License

Apache-2.0. See [LICENSE](LICENSE).
