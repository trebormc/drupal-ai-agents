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

### Tier 0: Genius — the hardest judgment
- **code-review**: Judge panel (PLAN mode → Implementation Contract; CODE mode → verdict + conformance)

### Tier 1: Smart — Complex reasoning
- **output-verifier**: Validation of non-code outputs
- **ralph-planner**: Requirements generation for autonomous execution
- **task-router**: Delegation advisor — the cheap orchestrator consults it when routing is unclear

### Tier 2: Normal — Development work
- **drupal-dev**: Backend PHP development
- **drupal-theme**: Frontend/Twig/CSS development
- **drupal-test-generator**: Test generation

### Vision — must accept image input
- **visual-test**: Playwright browser automation
- **visual-analyzer**: Screenshot/image interpretation

### Tier 3: Cheap — Fast/mechanical
- **code-explorer**: Context firewall for codebase exploration
- **applier**: Mechanical SEARCH/REPLACE application

The always-on rules `task-playbooks` (what steps a task type follows) and
`engineering-principles` (design defaults) shape how the orchestrator drives these
agents; the verification bar is "tests alone are not sufficient".

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

Agent files use `${MODEL_GENIUS}`, `${MODEL_SMART}`, `${MODEL_NORMAL}`, `${MODEL_CHEAP}`, `${MODEL_APPLIER}` and `${MODEL_VISION}` tokens (`GENIUS` falls back to `SMART`, `VISION` to `NORMAL` when not defined).
These are resolved at sync time by ddev-agents-sync using values from `.env.agents`.
`${MODEL_MAIN}` sets the tool's own default (orchestrator) model — cheap by design; see
[model-strategy.md](model-strategy.md).
