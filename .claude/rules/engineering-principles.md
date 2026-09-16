---
description: Engineering principles index — one line per principle with WHEN it applies and the Drupal-shaped rule; the reasoning defaults behind the task playbooks
---

# Engineering Principles

A short catalog of defaults. Each entry names the situation that triggers it and the
rule. Apply the ones the situation names; cite the principle in your summary when it
changed a decision ("kept the `.module` hook instead of a new service: Laziness"). The
**coding-behavior** rule governs the shape of a diff and the **epistemic-discipline**
rule governs evidence; this rule governs the design choices in between.

## Core

- **Laziness protocol** — sizing a diff, refactoring, tempted to add a layer, an
  interface, a service, or a config option. Bias to deletion and the smallest change
  that solves the problem. One caller does not justify an abstraction; a `.module`
  hook that does the job beats a service + event subscriber pair that "might scale".
- **Subtract before you add** — sequencing an addition or rewrite. Remove the dead
  hook, the unused `#states`, the redundant validator, the stub reference first, then
  build on the simpler base. Cut before you polish.
- **Foundational thinking** — before writing logic. Decide the data shape first:
  which entity type or config entity, which fields, which cache tags and contexts it
  carries. When the structure is right, the code that follows is boring. Scaffold
  (info.yml, services.yml, schema, the test class) before features.
- **Redesign from first principles** — integrating a new requirement into existing
  code. Ask "if this requirement had existed on day one, what would the code look
  like?" and converge there, instead of bolting a branch onto the current shape.
- **Attack the premise** — two or more fixes that share one assumption have failed
  the same check (the same test, the same page still wrong). Stop fixing. Write the
  shared premise down in one sentence and verify it directly (a `drush php:eval`, a
  kernel test, a read of the real core source) before any third attempt.
- **Exhaust the design space** — a novel architecture or interaction with no
  precedent in the project. Name 2-3 structurally different shapes (not flavors of
  one) and compare before committing. The **code-review** agent in PLAN mode does
  this deliberation; feed it the alternatives.
- **Build the lever** — non-trivial repeated work: touching 10+ files, a data
  cleanup, a bulk rename, a recurring check. Write the script (a Rector rule, a
  `drush php:script`, a shell loop, a `drush migrate` definition) instead of hand
  editing, run it, and keep it. A script is an artifact a reviewer can rerun; 30
  hand-made SEARCH/REPLACE blocks are not. Do the first unit by hand to learn the
  recipe, then automate the rest.
- **Experience first** — product, UX, or scope trade-offs. The user of a UI is the
  editor or the visitor; the user of a service is the developer who injects it; the
  next maintainer is a user too. Fewer polished features beat more rough ones.

## Architecture

- **Model the domain** — stateful logic, or code that branches a lot or repeats a
  shape assumption across files. Encode the domain in a structure: a state field with
  allowed transitions instead of scattered booleans, a plugin type instead of a
  `switch` on strings, a value object instead of loose arrays passed around. The sign
  you skipped this: a feature grows an `if/else` chain by one more branch.
- **Boundary discipline** — wiring validation and error handling. Validate at the
  boundary (Form API validation, route parameter conversion, request parsing, config
  schema, external API responses); trust typed data inside; keep business logic in
  services that do not know about the request. No re-validation three layers deep.
- **Make operations idempotent** — anything that can run twice or crash halfway:
  `hook_update_N`, `hook_post_update`, migrations, queue workers, cron, drush
  commands, batch operations. Check existing state before creating, converge to the
  same end state on rerun, and say in the summary what a second run does.
- **Migrate callers, then delete** — replacing an internal API in CUSTOM code.
  Migrate every caller and delete the old path in the same change; no compatibility
  shim, no parallel old-and-new. (Contrib and drupal.org work is the exception: keep
  the deprecation layer the community expects, see **drupal-multi-version-compat**.)
- **Separate before serializing shared state** — two actors writing the same thing:
  two update hooks touching one config object, two queue workers on one entity, two
  Ralph tasks on one file. Give each its own target first; use locks or ordering only
  when one shared writer is a real invariant.
- **Minimize reader load** — reviewing or shaping code that is hard to trace. Count
  the layers between a question and its answer and the hidden state the reader must
  hold. Collapse one-caller wrappers, prefer locals to properties and properties to
  static state. Test: can a new reader answer "where does this value come from?" in
  under 30 seconds?

## Verification, delegation, and learning

These principles are stated in full where they are applied; this is the index:

- **Prove it works** and **Sequence verifiable units** — the verification bar and the
  per-step checks in the **task-playbooks** rule and CLAUDE.md's Plan → Implement →
  Verify loop. Tests alone are not sufficient; a subagent's summary is not the artifact.
- **Fix root causes** — the Bug fix playbook (reproduce, binary-search, confirm the
  mechanism) and the **epistemic-discipline** rule §5 (attack the premise after two
  failed fixes).
- **Test behavior, not implementation** — the NULL test, rule 13 of the
  **drupal-testing** rule.
- **Guard the context window** — CLAUDE.md's Delegation Protocol (`code-explorer` as
  context firewall, summaries and `file:line` pointers in the main thread).
- **Never block on the human** — the **coding-behavior** rule §1 (observable facts are
  checked, not asked; only product or preference calls and irreversible actions go to
  the user).
- **Encode lessons in structure** — the **lessons-learned** rule (a PHPStan rule, PHPCS
  sniff, test, or script beats another paragraph) and the **session-distill** skill.
