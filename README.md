# Drupal AI Agents

A comprehensive set of AI agents, rules, skills, and configuration for Drupal 10/11 development. Designed for [OpenCode](https://opencode.ai) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code), compatible with [DDEV](https://ddev.readthedocs.io/) environments.

This repository is **not** a DDEV add-on -- it is a configuration package that gets synced into OpenCode and Claude Code containers via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync). It provides 13 specialized agents, 4 rule sets, and 14 skills tailored for Drupal development.

## Quick Install

### With DDEV (recommended)

When you install [ddev-opencode](https://github.com/trebormc/ddev-opencode) or [ddev-claude-code](https://github.com/trebormc/ddev-claude-code), this repository is **automatically synced** via [ddev-agents-sync](https://github.com/trebormc/ddev-agents-sync). No manual clone is needed.

```bash
# Install OpenCode or Claude Code — agents are synced automatically
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
├── CLAUDE.md                   Main instructions (language, design, environment, agents)
├── opencode.json.example       OpenCode config template (copy to opencode.json)
├── opencode-notifier.json      Notification bridge config (used automatically)
├── .env.agents                 Model alias definitions (tokens → real model names)
├── agent/                      13 agent definitions (.md files with fat frontmatter)
│   ├── drupal-dev.md
│   ├── drupal-theme.md
│   ├── code-review.md
│   └── ...
├── rules/                      4 rule sets loaded as instructions
│   ├── drupal-essentials.md
│   ├── beads-workflow.md
│   ├── quality-tools-setup.md
│   └── lessons-learned.md
├── skills/                     14 reusable skills
│   ├── drupal-audit/SKILL.md
│   ├── drupal-module-scaffold/SKILL.md
│   └── ...
└── install.sh                  Installation helper script (standalone mode)
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
| `drupal-dev` | `MODEL_CHEAP` | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | `MODEL_CHEAP` | Frontend: Twig, CSS, JS, Tailwind, responsive |
| `drupal-test` | `MODEL_CHEAP` | Testing: PHPUnit, coverage, test automation |
| `drupal-perf` | `MODEL_CHEAP` | Performance: caching, queries, bottlenecks |
| `drupal-update` | `MODEL_CHEAP` | Updates: Composer, security patches, migrations |
| `twig-audit` | `MODEL_CHEAP` | Templates: anti-patterns, cache bubbling, raw filter |

### Quality and Validation

| Agent | Token | Purpose |
|-------|-------|---------|
| `code-review` | `MODEL_SMART` | Quality gate: architecture, security, performance review |
| `output-verifier` | `MODEL_SMART` | Validate outputs with high confidence |
| `visual-test` | `MODEL_CHEAP` | Playwright browser screenshots and UI checks |

### Utilities

| Agent | Token | Purpose |
|-------|-------|---------|
| `code-explorer` | `MODEL_CHEAP` | Codebase exploration and analysis |
| `applier` | `MODEL_APPLIER` | Mechanical code application (SEARCH/REPLACE) |
| `ralph-planner` | `MODEL_SMART` | Generate requirements.md for Ralph Loop |
| `deep-research` | `MODEL_SMART` | Multi-source research and investigation |

## Rules

Rules are loaded as global instructions for every session:

| File | Purpose |
|------|---------|
| `rules/drupal-essentials.md` | Drupal coding standards, security, dependency injection |
| `rules/beads-workflow.md` | Beads task tracking workflow |
| `rules/quality-tools-setup.md` | PHPUnit, PHPStan, PHPCS setup and usage |
| `rules/lessons-learned.md` | Self-learning system -- agents record lessons for future sessions |

## Skills

Reusable skill definitions that agents can invoke:

| Skill | Description |
|-------|-------------|
| `beads-task-tracking` | Git-backed task tracking with Beads (bd) |
| `drupal-audit` | Code quality audits using the Drupal Audit module |
| `drupal-audit-setup` | Install and configure the Drupal Audit module |
| `drupal-config-management` | Configuration export/import, config_split, schema validation |
| `drupal-debugging` | Inspect services, entities, cache, watchdog logs, database queries |
| `drupal-migration` | D7-to-D10/D11 upgrades, custom migrations (CSV, JSON, API, SQL) |
| `drupal-module-scaffold` | Scaffold a new module with PSR-4 structure |
| `drupal-unit-test` | Generate PHPUnit tests with proper mocking patterns |
| `drush-commands` | Cache clearing, database updates, module management, cron |
| `playwright-browser-testing` | Browser testing with Playwright MCP |
| `run-quality-checks` | Full quality pipeline: Audit module primary, raw PHPCS/PHPStan fallback |
| `skill-creator` | Create and validate new OpenCode skills |
| `tailwind-drupal` | TailwindCSS setup and usage in Drupal themes |
| `xdebug-profiling` | Xdebug tracing and profiling for debugging and performance |

## Customization

### Adding your own agents

Create a `.md` file in `agent/` with fat frontmatter and a system prompt:

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

The agent is auto-discovered from the `agent/` directory. Use model tokens (`${MODEL_SMART}`, `${MODEL_NORMAL}`, `${MODEL_CHEAP}`, `${MODEL_APPLIER}`) so the sync script resolves them correctly for each tool.

### Adding rules

1. Create a `.md` file in the `rules/` directory.
2. Add its path to the `instructions` array in `opencode.json`.

### Adding skills

1. Create a `SKILL.md` file in `skills/{skill-name}/` following the [Agent Skills specification](https://agentskills.io).
2. Skills are auto-discovered from the `skills/` directory -- no config changes needed.

### Private agent repo

To add custom agents without forking this repo:

1. Create a git repository with the same structure (`agent/`, `rules/`, `skills/`, `.env.agents`).
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
| [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) | Headless Playwright browser for visual testing. | Browser automation |

## Disclaimer

This project is not affiliated with Anthropic, OpenCode, Beads, Playwright, Microsoft, or DDEV. AI-generated code may contain errors -- always review changes before deploying to production. See [menetray.com](https://menetray.com) for more information and [DruScan](https://druscan.com) for Drupal auditing tools.

## License

Apache-2.0. See [LICENSE](LICENSE).
