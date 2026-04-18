# Architecture

## Container Architecture

```
DDEV Network (ddev_default)
 ├─ opencode / claude-code → SSH → web (PHP/Drupal)
 │                          → SSH → beads (task tracking)
 │                          → HTTP MCP   → playwright-mcp (browser)
 ├─ ralph          → SSH → opencode OR claude-code
 │                  → SSH → beads
 ├─ beads          → bd CLI, git-backed task tracking
 ├─ playwright-mcp → headless Chromium, port 8931
 └─ web            → PHP/Drupal, database, drush, composer
```

AI containers never access the database directly. They use SSH to run commands inside the web container.

## Agent Architecture

Agents are organized in three tiers by model cost:

### Tier 1: Smart (Opus) — Complex reasoning
- **code-review**: Quality gate (correctness, security, Drupal quality, performance)
- **deep-research**: Multi-source investigation
- **ralph-planner**: Requirements generation for autonomous execution

### Tier 2: Normal (Sonnet) — Development work
- **drupal-dev**: Backend PHP development
- **drupal-theme**: Frontend/Twig/CSS development
- **output-verifier**: Output validation
- **visual-test**: Playwright visual testing

### Tier 3: Cheap (Haiku) — Fast/mechanical
- **code-explorer**: Codebase navigation
- **applier**: Mechanical SEARCH/REPLACE application

## The Applier Pattern

Agents that generate code (drupal-dev, drupal-theme) cannot edit files directly. They:
1. Read files to understand current state
2. Generate SEARCH/REPLACE blocks
3. Delegate to the `applier` agent for mechanical application

This separation ensures code generation and code application are independent concerns.

## Agent-to-Agent Delegation

Only drupal-dev and drupal-theme have the `Agent` tool for delegating to applier.
All other agents return results directly to the orchestrator.

## Model Token System

Agent files use `${MODEL_SMART}`, `${MODEL_NORMAL}`, `${MODEL_CHEAP}`, `${MODEL_APPLIER}` tokens.
These are resolved at sync time by ddev-agents-sync using values from `.env.agents`.
