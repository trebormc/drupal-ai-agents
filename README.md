# Drupal AI Agents

A comprehensive set of AI agents, rules, skills, and configuration for Drupal 10/11 development. Designed for [OpenCode](https://opencode.ai) and compatible with [DDEV](https://ddev.readthedocs.io/) environments.

This repository is **not** a DDEV add-on -- it is a configuration package that gets mounted into the OpenCode container (or used standalone). It provides 13 specialized agents, 4 rule sets, and 13 skills tailored for Drupal development.

## Quick Install

### Path A: With ddev-opencode (recommended)

Clone the repo and point the DDEV add-on to it:

```bash
# Clone to any local directory
git clone https://github.com/trebormc/drupal-ai-agents.git ~/drupal-ai-agents

# Copy and customize the config
cd ~/drupal-ai-agents
cp opencode.json.example opencode.json
vi opencode.json

# In your Drupal project, set the config directory
ddev dotenv set .ddev/.env.opencode \
  --host-opencode-config-dir="$HOME/drupal-ai-agents/"

ddev restart
ddev opencode
```

The entire `drupal-ai-agents` directory is mounted into the OpenCode container as its config directory. Agents, rules, skills, and `opencode.json` are all available automatically.

### Path B: Standalone (without DDEV)

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
├── opencode.json.example       Config template (copy to opencode.json)
├── opencode-notifier.json      Notification bridge config (used automatically)
├── agent/                      16 agent definitions (.md files)
│   ├── drupal-dev.md
│   ├── drupal-theme.md
│   ├── drupal-test.md
│   ├── three-judges.md
│   └── ...
├── rules/                      4 rule sets loaded as instructions
│   ├── drupal-essentials.md
│   ├── beads-workflow.md
│   ├── quality-tools-setup.md
│   └── lessons-learned.md
├── skills/                     14 reusable skills
│   ├── drupal-audit.md
│   ├── drupal-module-scaffold.md
│   ├── run-quality-checks.md
│   └── ...
└── install.sh                  Installation helper script
```

## Agents

### Drupal Development

| Agent | Model | Purpose |
|-------|-------|---------|
| `drupal-dev` | Haiku 4.5 | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | Haiku 4.5 | Frontend: Twig, CSS, JS, Tailwind, responsive |
| `drupal-test` | Haiku 4.5 | Testing: PHPUnit, coverage, test automation |
| `drupal-perf` | Haiku 4.5 | Performance: caching, queries, bottlenecks |
| `drupal-update` | Haiku 4.5 | Updates: Composer, security patches, migrations |
| `twig-audit` | Haiku 4.5 | Templates: anti-patterns, cache bubbling, raw filter |

### Quality and Validation

| Agent | Model | Purpose |
|-------|-------|---------|
| `three-judges` | Opus 4.6 | Quality gate: architecture, security, performance review |
| `output-verifier` | Opus 4.6 | Validate outputs with high confidence |
| `visual-test` | Haiku 4.5 | Playwright browser screenshots and UI checks |

### Utilities

| Agent | Model | Purpose |
|-------|-------|---------|
| `code-explorer` | Haiku 4.5 | Codebase exploration and analysis |
| `applier` | GPT-OSS 20B | Mechanical code application (SEARCH/REPLACE) |
| `ralph-planner` | Opus 4.6 | Generate requirements.md for Ralph Loop |
| `deep-research` | Opus 4.6 | Multi-source research and investigation |

## Rules

Rules are loaded as global instructions for every OpenCode session:

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
| `beads-task-tracking` | Git-backed task tracking with Beads (bd) -- create, update, close, and query tasks |
| `drupal-audit` | Code quality audits using the Drupal Audit module (phpcs, phpstan, twig, phpunit, complexity) |
| `drupal-audit-setup` | Install and configure the Drupal Audit module and submodules for local development |
| `drupal-config-management` | Configuration export/import, config_split, schema validation |
| `drupal-debugging` | Inspect services, entities, cache, watchdog logs, database queries |
| `drupal-migration` | D7-to-D10/D11 upgrades, custom migrations (CSV, JSON, API, SQL) |
| `drupal-module-scaffold` | Scaffold a new module with PSR-4 structure, services, routing, config schema |
| `drupal-unit-test` | Generate PHPUnit tests with proper mocking patterns |
| `drush-commands` | Cache clearing, database updates, module management, cron |
| `playwright-browser-testing` | Browser testing with Playwright MCP (navigation, screenshots, forms) |
| `run-quality-checks` | Full quality pipeline: Audit module primary, raw PHPCS/PHPStan fallback |
| `skill-creator` | Create and validate new OpenCode skills |
| `tailwind-drupal` | TailwindCSS setup and usage in Drupal themes |
| `xdebug-profiling` | Xdebug tracing and profiling for debugging and performance |

## DDEV Environment

These agents are designed for a multi-container DDEV architecture:

```
┌─────────────────────────────────────────────┐
│  1. OpenCode (you are here)                 │
│     -> agents, file access, bash            │
│                                             │
│  2. Web ($WEB_CONTAINER)                    │
│     -> PHP, Drupal, Drush, Composer         │
│     -> accessed via docker exec             │
│                                             │
│  3. Beads ($BEADS_CONTAINER)                │
│     -> git-backed task tracking (bd)        │
│     -> accessed via docker exec             │
│                                             │
│  4. Playwright MCP ($PLAYWRIGHT_MCP_URL)    │
│     -> headless Chromium browser            │
│     -> accessed via HTTP MCP protocol       │
└─────────────────────────────────────────────┘
```

All PHP/Drupal commands run via `docker exec $WEB_CONTAINER`.

## Customization

### Adding your own agents

1. Create a `.md` file in the `agent/` directory with the agent's system prompt.
2. Add the corresponding entry in `opencode.json` under the `agent` key, specifying model, mode, tools, and permissions.

### Adding rules

1. Create a `.md` file in the `rules/` directory.
2. Add its path to the `instructions` array in `opencode.json`.

### Adding skills

1. Create a `.md` file in the `skills/` directory following the [Agent Skills specification](https://agentskills.io).
2. Skills are auto-discovered from the `skills/` directory -- no config changes needed.

### Adapting for Claude Code

While this repo is designed for OpenCode, the agent prompts and rules make excellent source material for a `CLAUDE.md` file. Copy the relevant rules and agent instructions into your project's `CLAUDE.md` for use with [ddev-claude-code](https://github.com/trebormc/ddev-claude-code).

## Related

- [ddev-opencode](https://github.com/trebormc/ddev-opencode) -- DDEV add-on for OpenCode container
- [ddev-claude-code](https://github.com/trebormc/ddev-claude-code) -- DDEV add-on for Claude Code container
- [ddev-ralph](https://github.com/trebormc/ddev-ralph) -- Autonomous task runner
- [ddev-beads](https://github.com/trebormc/ddev-beads) -- Git-backed task tracker container
- [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) -- Playwright browser automation
- [OpenCode](https://opencode.ai) -- AI-powered development tool
- [Beads](https://github.com/steveyegge/beads) -- Git-backed task tracker for AI agents

## Disclaimer

This project is not affiliated with Anthropic, OpenCode, Beads, Playwright, Microsoft, or DDEV. AI-generated code may contain errors -- always review changes before deploying to production. See [menetray.com](https://menetray.com) for more information and [DruScan](https://druscan.com) for Drupal auditing tools.

## License

Apache-2.0. See [LICENSE](LICENSE).
