[![last commit](https://img.shields.io/github/last-commit/trebormc/drupal-ai-agents)](https://github.com/trebormc/drupal-ai-agents/commits)
[![release](https://img.shields.io/github/v/release/trebormc/drupal-ai-agents)](https://github.com/trebormc/drupal-ai-agents/releases/latest)

# Drupal AI Agents

The **brain** of the [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace). A comprehensive set of AI agents, rules, skills, and configuration for **Drupal 10/11** development. Designed for [OpenCode](https://opencode.ai) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code), compatible with [DDEV](https://ddev.readthedocs.io/) environments.

> **Part of [DDEV AI Workspace](https://github.com/trebormc/ddev-ai-workspace)** — a modular ecosystem of DDEV add-ons for AI-powered Drupal development. Install the full stack with one command: `ddev add-on get trebormc/ddev-ai-workspace`
>
> Created by [Robert Menetray](https://menetray.com) · Sponsored by [DruScan](https://druscan.com)

This repository is **not** a DDEV add-on. It is a configuration package that gets synced into OpenCode and Claude Code containers via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync). It provides 10 specialized agents, 12 rules, and 24 skills tailored for Drupal development. The agents understand Drupal APIs, coding standards, caching, render arrays, the module/theme ecosystem, and quality tools like PHPStan, PHPCS, and PHPUnit.

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
│   ├── agents/                       10 agent definitions (.md files with fat frontmatter)
│   │   ├── applier.md
│   │   ├── code-explorer.md
│   │   ├── code-review.md
│   │   ├── deep-research.md
│   │   ├── drupal-dev.md
│   │   ├── drupal-test-generator.md
│   │   ├── drupal-theme.md
│   │   ├── output-verifier.md
│   │   ├── ralph-planner.md
│   │   └── visual-test.md
│   ├── rules/                        12 rule sets loaded as instructions
│   │   ├── applier-protocol.md
│   │   ├── beads-workflow.md
│   │   ├── config-management.md
│   │   ├── ddev-environment.md
│   │   ├── drupal-coding-standards.md
│   │   ├── drupal-testing.md
│   │   ├── git-workflow.md
│   │   ├── lessons-learned.md
│   │   ├── quality-tools-setup.md
│   │   ├── security-rules.md
│   │   ├── services-conventions.md
│   │   └── twig-patterns.md
│   └── skills/                       24 reusable skills
│       ├── beads-task-tracking/SKILL.md
│       ├── commit-message/SKILL.md
│       ├── config-management/SKILL.md
│       ├── drupal-audit-setup/SKILL.md
│       ├── drupal-behat-test/SKILL.md
│       ├── drupal-code-patterns/SKILL.md
│       ├── drupal-debugging/SKILL.md
│       ├── drupal-functional-test/SKILL.md
│       ├── drupal-functionaljs-test/SKILL.md
│       ├── drupal-kernel-test/SKILL.md
│       ├── drupal-migration/SKILL.md
│       ├── drupal-playwright-test/SKILL.md
│       ├── drupal-testing/SKILL.md
│       ├── drupal-unit-test/SKILL.md
│       ├── drupal-update/SKILL.md
│       ├── drush-commands/SKILL.md
│       ├── module-scaffold/SKILL.md
│       ├── performance-audit/SKILL.md
│       ├── playwright-testing/SKILL.md
│       ├── quality-checks/SKILL.md
│       ├── skill-creator/SKILL.md
│       ├── tailwind-drupal/SKILL.md
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
| `${MODEL_SMART}` | Opus 4.6 | Quality gates, planning, research |
| `${MODEL_NORMAL}` | Sonnet 4.5 | General-purpose tasks |
| `${MODEL_CHEAP}` | Haiku 4.5 | Fast, cost-effective agents |
| `${MODEL_APPLIER}` | Haiku 4.5 | Mechanical code application |

### Changing models

Edit `.env.agents` to change which models all agents use:

```bash
# OpenCode models (provider/model-id format)
OC_MODEL_SMART=opencode/kimi-k2.5
OC_MODEL_NORMAL=opencode/minimax-m2.5
OC_MODEL_CHEAP=opencode/gpt-5-nano
OC_MODEL_APPLIER=opencode/gpt-5-nano

# Claude Code models (native aliases)
CC_MODEL_SMART=opus
CC_MODEL_NORMAL=sonnet
CC_MODEL_CHEAP=haiku
CC_MODEL_APPLIER=haiku
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
| `code-review` | `MODEL_SMART` | Quality gate: correctness, security, Drupal quality, performance |
| `output-verifier` | `MODEL_SMART` | Validate outputs with high confidence |
| `visual-test` | `MODEL_NORMAL` | Playwright browser screenshots and UI checks |

### Utilities

| Agent | Token | Purpose |
|-------|-------|---------|
| `code-explorer` | `MODEL_CHEAP` | Codebase exploration and analysis |
| `applier` | `MODEL_APPLIER` | Mechanical code application (SEARCH/REPLACE) |
| `ralph-planner` | `MODEL_SMART` | Generate requirements.md for Ralph Loop |
| `deep-research` | `MODEL_NORMAL` | Multi-source research and investigation |

## Rules

Rules are loaded as global instructions. Some are path-scoped (activate only for matching file types), others apply globally.

| File | Scope | Purpose |
|------|-------|---------|
| `drupal-coding-standards.md` | `*.php` | Strict types, 2-space indent, type hints, DI, cache metadata, quality checklist |
| `twig-patterns.md` | `*.twig` | Presentation only, render full fields, cache bubbling, anti-patterns |
| `drupal-testing.md` | Global | Test type decision tree, D10 vs D11 differences, common rules |
| `beads-workflow.md` | Global | Beads task tracking: session start, during work, session end |
| `quality-tools-setup.md` | Global | PHPStan, PHPCS, Rector, GrumPHP, PHPUnit setup (Audit module priority) |
| `lessons-learned.md` | Global | Self-learning protocol: document problems and solutions |
| `services-conventions.md` | Global | Service definitions, DI, interfaces, event subscribers, tagging |
| `applier-protocol.md` | Global | SEARCH/REPLACE block format for code changes |
| `config-management.md` | Global | Config export/import, config_split, schema validation |
| `security-rules.md` | Global | Input sanitization, DB placeholders, route access, CSRF |
| `ddev-environment.md` | Global | Docker exec commands, environment variables, Audit module priority |
| `git-workflow.md` | Global | Agents must NOT commit/push; user controls git operations |

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
| `drupal-audit-setup` | Install and configure the Drupal Audit module |
| `performance-audit` | Caching, queries, lazy builders, bottlenecks, N+1 detection |
| `twig-audit` | Template anti-patterns, cache bubbling, raw filter misuse |

### Browser and UI

| Skill | Description |
|-------|-------------|
| `playwright-testing` | Interactive browser testing with Playwright MCP (navigation, screenshots) |
| `tailwind-drupal` | TailwindCSS setup and usage in Drupal themes |

### Workflow and Utilities

| Skill | Description |
|-------|-------------|
| `beads-task-tracking` | Git-backed task tracking with Beads (bd) |
| `commit-message` | Generate commit messages from git diff (Conventional Commits format) |
| `xdebug-profiling` | Xdebug tracing and profiling for debugging and performance |
| `skill-creator` | Create and validate new OpenCode skills |

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

The agent is auto-discovered from the `.claude/agents/` directory. Use model tokens (`${MODEL_SMART}`, `${MODEL_NORMAL}`, `${MODEL_CHEAP}`, `${MODEL_APPLIER}`) so the sync script resolves them correctly for each tool.

### Adding rules

1. Create a `.md` file in the `.claude/rules/` directory.
2. For OpenCode: add its path to the `instructions` array in `opencode.json`.
3. For Claude Code: rules in `.claude/rules/` are auto-discovered.

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
| [ddev-beads](https://github.com/trebormc/ddev-beads) | [Beads](https://github.com/steveyegge/beads) git-backed task tracker. | Task tracking |
| [ddev-ai-ssh](https://github.com/trebormc/ddev-ai-ssh) | SSH access to the web container. Generates per-project keys, installs sshd. | SSH infrastructure |
| [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) | Headless Playwright browser for visual testing. | Browser automation |

## Disclaimer

This project is an independent initiative by [Robert Menetray](https://menetray.com), sponsored by [DruScan](https://druscan.com). It is not affiliated with Anthropic, OpenCode, Beads, Playwright, Microsoft, or DDEV. AI-generated code may contain errors. Always review changes before deploying to production.

## License

Apache-2.0. See [LICENSE](LICENSE).
