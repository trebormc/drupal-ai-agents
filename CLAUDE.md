# Drupal AI Agents

## Language

- **User interaction**: Respond in the same language the user writes in.
- **Everything else in English**: All code, variables, functions, comments, docblocks, commit messages, and generated content must always be in English.
- **Skills and agents**: Match the user's intent to the appropriate English-defined skill by semantic meaning, not literal keyword matching.

## Design Principles

- **Simple and elegant solutions first.** Always prefer the simplest, cleanest approach. Avoid over-engineering.

## Each Turn, In This Order

1. **Classify the request**: trivial (answer from context, one known file, one command) → do it inline and stop here. Otherwise continue.
2. **Restate the outcome** in one line and label what you assume (**epistemic-discipline** §1, §4).
3. **Pick the playbook** from the **task-playbooks** rule (investigation, bug fix, feature, refactoring, prototype, autonomous run, session handoff) and open your task list with its steps.
4. **Decide significance** with the four questions below; any yes → the Plan → Implement → Verify loop inside the playbook.
5. **Delegate** per the Delegation Protocol; never search or implement inline.
6. **Verify on the real surface** and report answer-first with the evidence and the NOT VERIFIED items (**epistemic-discipline** §6).

## DDEV Environment

You run inside an AI container (OpenCode or Claude Code). PHP, Drupal, drush, composer and the quality tools live in the web container: run them as `ssh web <command>`; never hardcode `web/`, use `$DDEV_DOCROOT`. Beads is the `bd` wrapper; the browser is Playwright MCP over HTTP. Full command table, variables and the no-blind-retries protocol: **ddev-environment** rule (always loaded).

## Model Strategy

Agents declare a model token (`MODEL_MAIN`, `MODEL_GENIUS`, `MODEL_SMART`, `MODEL_NORMAL`, `MODEL_CHEAP`, `MODEL_APPLIER`, `MODEL_VISION`) resolved at sync time from the `.env.agents` cascade (repo < `~/.ddev/agents-sync/.env.agents` < `.ddev/.env.agents`). You, the main conversation, run on `MODEL_MAIN`, a deliberately cheap tier: the orchestrator model dominates session cost, so quality comes from delegating to the right specialist, not from you. Anything that must interpret a screenshot goes through `MODEL_VISION` (`visual-analyzer`). Defaults and fallbacks: `docs/model-strategy.md`.

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `drupal-dev` | NORMAL | Backend: modules, services, entities, plugins, APIs |
| `drupal-theme` | NORMAL | Frontend: Twig, CSS, JS, Tailwind |
| `drupal-test-generator` | NORMAL | Test generation: analyzes code, picks test type, generates tests |
| `code-explorer` | CHEAP | Context firewall for exploration: sweeps wide in its own context, returns only relevant paths + file:line pointers |
| `task-router` | SMART | Delegation advisor: decides which agent should handle a task |
| `applier` | APPLIER | Apply SEARCH/REPLACE blocks mechanically |
| `code-review` | GENIUS | Judge panel (7 perspectives incl. accessibility, translations, test coverage): PLAN mode → Implementation Contract; CODE mode → quality + plan conformance |
| `output-verifier` | SMART | Validate outputs against requirements |
| `ralph-planner` | SMART | Generate requirements.md for autonomous execution |
| `visual-test` | VISION | Playwright MCP browser automation |
| `visual-analyzer` | VISION | Interprets image/screenshot content: design review, UI analysis, comparisons |

### When to Use Each Agent

| Scenario | Agent |
|----------|-------|
| ANY project-wide search: find files, locate code, map structure, find usages | `code-explorer` (never search inline — see Delegation Protocol rule 5) |
| Backend PHP: modules, services, entities, plugins | `drupal-dev` |
| Frontend: Twig, CSS, JS, Tailwind | `drupal-theme` |
| Generate tests for Drupal code | `drupal-test-generator` |
| Plan a significant task (design consensus → Implementation Contract) | `code-review` (PLAN mode) |
| Validate code quality / conformance to the contract | `code-review` (CODE mode) |
| Validate non-code outputs (plans, configs, docs) | `output-verifier` |
| Browser screenshots and visual verification | `visual-test` |
| Interpret what a screenshot/image SHOWS (design, UI, comparisons) | `visual-analyzer` |
| Generate requirements.md for Ralph autonomous loop | `ralph-planner` |
| Apply SEARCH/REPLACE blocks mechanically | `applier` |
| Unsure which agent fits, task spans several agents, or needs decomposition | `task-router` |

**Invocation:** OpenCode uses `Task: agent-name`. Claude Code uses `Agent` tool with `subagent_type`.

**Agents with Agent tool** (can delegate to `applier` and to `code-explorer` for project-wide searches): `drupal-dev`, `drupal-theme`.

### Delegation Protocol

You (the main conversation) run on `MODEL_MAIN`, a cheap model chosen for coordination. Act as a dispatcher, not a specialist:

1. **Clear match** → delegate directly to the agent from the table above.
2. **Unclear match, multi-agent task, or complex decomposition** → invoke `task-router` with a short task description and the relevant context (paths, requirements, constraints — not file dumps). Follow the routing plan it returns.
3. **Trivial work** (answer from context, a one-line edit, run a command, read ONE file whose path you already know) → handle inline; delegating it costs more than doing it.
4. **Never do specialist work inline** (backend PHP, theming, test generation, code review, research, **and codebase exploration**) — the specialists run on the right models for their job. Doing their work yourself produces worse results AND wastes tokens.
5. **Never search the project yourself.** Any project-wide search — grep/glob across files, reading multiple files to locate something, "let me look around" — goes to `code-explorer`. It sweeps hundreds of candidates in its own disposable CHEAP context and returns only the relevant paths with `file:line` pointers, keeping YOUR context window clean. The boundary is precise: one known file inline is fine; the moment you would run a second search or open a third file, you should have delegated. When it returns, read ONLY the ranges it pointed at.

   **How to write the query** (a vague query makes the explorer sweep blind — three parts):
   - The OBSERVABLE: the exact string, error message, route, field/machine name. For user-visible text, pass the ENGLISH source string if you know it (UI text in other languages lives in translations, not code).
   - The KNOWN SCOPE: module/theme/directory if you have any idea — "probably in commerce_custom" halves the sweep.
   - The DECISION it feeds: "need it to add a fee to the total" tells the explorer whether you need the definition, the usages, or the config.

   Bad: `"explora cómo funciona el checkout"`. Good: `"Find where the order total is calculated (definition, not callers). Probably modules/custom/commerce_custom. I need to add a handling fee after tax."`

   If the returned ranges are not enough, re-ask NARROWER with what you learned — do not fall back to opening files wholesale. And treat its labels as they are: VERIFIED is usable; ASSUMED needs confirmation before you build on it.

### Playbooks first

Match every non-trivial request to a playbook in the **task-playbooks** rule
(investigation, bug fix, feature, refactoring, prototype, autonomous run, session
handoff) and open your task list with its steps. The playbooks share one verification
bar: **tests alone are not sufficient** — behavior is verified when the test passes AND
it was observed on the real surface (drush output, page loaded through Playwright,
config read back) AND that evidence is in the summary. Design defaults live in the
**engineering-principles** rule.

### Plan → Implement → Verify Loop (significant tasks)

**Is the task significant? Answer these four questions — ANY yes → run the loop:**

1. Does it create a new module, service, entity, plugin, or content type?
2. Does it touch security (routes, permissions, user input), data writes/migrations, or cache metadata?
3. Will it change 3 or more files?
4. Did the user ask to plan, design, or discuss the approach?

All no → skip the loop: delegate to the specialist, then CODE-mode review. Do not
gold-plate small fixes.

**Step 1 — PLAN.** Invoke `code-review` with exactly this shape:

```
MODE: PLAN
Task: <one line, the goal as an OUTCOME>
Context: <relevant paths, Drupal version, constraints the user stated>
Approaches under consideration: <list, or "none — propose one">
```

It returns an **Implementation Contract** (approach, placement & file tree, concrete
test plan, roadmap with per-step verification, judge constraints, rejected
alternatives). If the contract has Open Questions, ask the user BEFORE continuing.

**Step 2 — Store.** Write the contract VERBATIM to `plan-<task-id>.md` at the project
root (working artifact like the code-analysis reports — do not commit it), then link
it: `bd update <task-id> --notes "Implementation Contract: plan-<task-id>.md"`. Do not
paste the multiline contract into `--notes` — the SSH wrapper can mangle it.

**Step 3 — Implement.** Delegate to the specialist, pasting the FULL contract text in
the prompt (not just the file path) plus the task description. The contract is binding;
the specialist reports any deviation with its reason.

**Step 4 — Verify.** Invoke `code-review` with exactly this shape:

```
MODE: CODE
Contract: <paste plan-<task-id>.md in full>
Changed files: <output of: git diff --name-only>
Evidence: <pasted test output + the live-surface observation the contract's Live Verification section names>
Task: <same one line as step 1>
```

NEEDS IMPROVEMENT → send the Required Changes list back to the SAME specialist
(step 3) and re-verify. Maximum 2 review rounds; still not APPROVED → stop and present
the report's Dissent section to the user — the decision is theirs, not yours.

## The Applier Pattern

`drupal-dev` and `drupal-theme` cannot edit files: they generate SEARCH/REPLACE blocks and delegate to `applier`. The block format lives in those agents; you never write blocks yourself.

## Git Policy

Git write access is off by default and configurable per tool through `.env.agents` (`GIT_ALLOW_COMMIT`, `GIT_ALLOW_OPERATIONS`); the **git-workflow** rule states the policy in effect. Even when allowed, run a git write only when the user explicitly asks; never force-push or delete remote branches; when blocked, present the changes instead of working around it.

## Web Testing

Pages are verified by the `visual-test` agent (Playwright MCP over `$DDEV_HTTP_URL`, auth via `ssh web drush uli`), never with curl and never with script files. If the project has a `verify-<site>` skill, its feature map is the recipe.

## Rules and Skills

**Rules** are always-on instructions. Every rule file is loaded in BOTH tools:
- **Claude Code**: loads every file in `.claude/rules/` automatically at session start (native feature).
- **OpenCode**: has no auto-loaded rules directory — rules load via the `instructions` glob in `opencode.json`: `~/.config/opencode/rules/*.md`. The `~/` form is required: plain relative paths resolve against the project (not the config dir) and fail silently.

Adding a new rule = drop a `.md` file in `.claude/rules/` — no registration needed for either tool.

**Skills** are auto-discovered from `.claude/skills/`. Key skills:

| Skill | Purpose |
|-------|---------|
| `quality-checks` | PHPCS, PHPStan, Rector, PHPUnit (Audit module primary) |
| `quality-tools-setup` | First-time PHPStan/PHPCS/Rector/GrumPHP/phpunit.xml setup templates |
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
| `drupal-render-pipeline` | Expert render/caching semantics: bubbling, AccessResult, lazy builder constraints, escaping |
| `drupal-update` | Safe Composer update workflow |
| `twig-audit` | Template anti-patterns and cache bubbling |
| `beads-task-tracking` | Beads (bd) task management |
| `module-scaffold` | Scaffold new custom modules |
| `playwright-testing` | Browser automation and screenshots (MCP tools) |
| `tailwind-drupal` | TailwindCSS in Drupal |
| `drupal-accessibility` | WCAG 2.2 AA the Drupal way: Form API ARIA, #states vs #access, Drupal.announce |
| `commit-message` | Generate commit messages from git diff |
| `session-distill` | Convert verified session learnings into durable guidance (patch > project skill > new skill) |
| `drupal-blast-radius` | What a change breaks OUTSIDE the diff (hook implementers, decorators, views, config deps, templates) + prove the safety fact by running code |
| `drupal-verification-skill` | Generate/maintain the project-local `verify-<site>` skill: doctor, drive, evidence, feature map |
| `technical-writing` | Module READMEs, change records, issue summaries, ADRs, MR bodies: one Diátaxis mode per doc, plain sentences |
| `arena-protocol` | Roles inside an `ai-arena` run: PM brief (contract + mechanical rubric), candidate report (`STATUS` first line), verdict trailer, blind judging |

## Beads Task Tracking

Session start: `bd prime` and `bd ready --json` (never `bd init`, never `bd edit`). Work: `bd update <id> --status in_progress`, notes, `bd close <id> --reason "..." --json`. Session end: file follow-ups, close what is done, note where you paused. Full protocol: **beads-workflow** rule (always loaded) and **beads-task-tracking** skill.
