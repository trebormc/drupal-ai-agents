# Architecture

## Container Architecture

```
DDEV Network (ddev_default)
 ├─ opencode / claude-code → docker exec → web (PHP/Drupal)
 │                          → docker exec → beads (task tracking)
 │                          → HTTP MCP   → playwright-mcp (browser)
 ├─ ralph          → docker exec → opencode OR claude-code
 │                  → docker exec → beads
 ├─ beads          → bd CLI, git-backed task tracking
 ├─ playwright-mcp → headless Chromium, port 8931
 └─ web            → PHP/Drupal, database, drush, composer
```

AI containers never access the database directly. They use `docker exec` to run commands inside the web container.

## Agent Architecture

Agents are organized in three tiers by model cost:

### Tier 1: Smart (Opus) — Complex reasoning
- **three-judges**: Quality gate (architecture, security, performance review)
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
