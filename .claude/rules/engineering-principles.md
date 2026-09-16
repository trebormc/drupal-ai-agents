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

## Verification

- **Prove it works** — before declaring done. Verify against the real artifact: run
  the drush command, load the page through Playwright, read the config value, paste
  the test output. "It compiles", "PHPStan is clean", and a subagent's summary are
  proxies. Tests alone are not sufficient verification for user-facing behavior.
- **Fix root causes** — debugging. Reproduce first, ask why until the mechanism is
  explained, and resist the null check or the `try/catch` that silences the symptom.
  If the fix needs a paragraph-long comment to justify it, the code is wrong. Check
  whether the same pattern exists elsewhere before closing.
- **Sequence verifiable units** — multi-step work. Break it into units that each end
  in a check (a test, a drush output, a page state) and verify each before the next.
  Order the work so it proves itself: failing test, then fix; baseline, then change.
- **Test behavior, not implementation** — writing or keeping a test. Call the code the
  way its users do and assert a literal expected value. Full rule and the
  "would it still pass if every dependency returned NULL?" check in the
  **drupal-testing** rule.

## Delegation

- **Guard the context window** — large outputs, long files, repeated reads, fan-out.
  Route bulk to `code-explorer` and specialists; keep summaries and `file:line`
  pointers in the main thread, never raw dumps. Capture verbose tool output to a file
  and read only the tail on failure.
- **Never block on the human** — tempted to ask "should I do X?" on reversible work.
  If the answer is observable (does the method exist, does the page render, does the
  test pass), run the check instead of asking. Ask only for product or preference
  calls, and always for irreversible actions (data deletion, config import on a
  shared environment, anything git-destructive). The **coding-behavior** rule §1
  states the interactive/autonomous split.

## Meta

- **Encode lessons in structure** — you write the same instruction a second time, or a
  correction recurs. Turn it into a PHPStan rule, a PHPCS sniff, a test, a
  `composer.json` script, or a CI check instead of more markdown. Pick the strongest
  mechanism the situation allows (a type that cannot represent the invalid state, a
  lint that fails the build, then a runtime check, then a documented rule). The
  **lessons-learned** rule and the **session-distill** skill route this.
