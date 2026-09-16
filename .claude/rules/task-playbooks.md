---
description: Task playbooks — match the request to a playbook (investigation, bug fix, feature, refactoring, prototype, autonomous run, session handoff) and follow its steps; the verification bar for each
---

# Task Playbooks

Before starting a non-trivial task, match it to one playbook below and open your task
list with that playbook's steps first, then the task-specific items. A step you skip
stays in the list as `skip: <reason>`. Trivial work (a one-line edit, answer from
context, run one command) needs no playbook.

| The request is... | Playbook |
|---|---|
| A read-only question: how does X work, why is it built this way, are we sure about Z, X or Y? | Investigation |
| A reported defect to reproduce, root-cause, and fix | Bug fix |
| New or changed behavior | Feature |
| A behavior-preserving change to structure (rename, extract, move, dedupe, modernize) | Refactoring |
| A design or behavior question that an experiment can settle cheaper than a discussion | Prototype |
| A long run with no user present (Ralph Loop, "run until done") | Autonomous run |
| Stopping mid-task, or resuming another session's in-flight work | Session handoff |

The bar every playbook shares: **tests alone are not sufficient verification**. A
change is verified when its unit or kernel test passes AND the behavior was observed on
the real surface (a drush output, a page loaded through Playwright, a config value
read back) AND that evidence is pasted in the summary. "Inconclusive" is not a pass.

## Investigation

You own the answer. Read-only; the deliverable is a cited explanation or a
recommendation, never a code change.

1. Delegate the mapping to `code-explorer` with a three-part query (observable, known
   scope, the decision it feeds). Read only the ranges it returns.
2. For "how does it work": trace the runtime path (route → controller/form → service
   → render/cache) and cite `file:line` per hop. Verify core/contrib API behavior in
   the real source under `$DDEV_DOCROOT/core` or `modules/contrib`, never from memory.
3. For "why is it built this way": the code does not carry its motivation. Look for
   written evidence: `git log --follow -p -- <file>`, `git log -S '<symbol>'`,
   `git blame -L`, drupal.org issue numbers in commit messages, `composer.json`
   patches and their issue URLs, `CHANGELOG`/`README` of the module, config
   `dependencies:`. Tier every claim: **DIRECT** (someone wrote the reason),
   **SUPPORTED** (several indirect signals converge), **INFERRED** (your reading),
   **UNKNOWN** (you searched X, Y, Z and found nothing — say which). Never present
   the code's current shape as evidence of its intent.
4. If the user's question embeds a hypothesis ("it's a cache bug, right?"), treat it
   as one candidate among others and check it independently.
5. Answer first, evidence after, unknowns last. For "X or Y?" give a recommendation
   with a trade-off table and your real judgment; push back if the premise is wrong.

If the investigation turns out to precede a change, hand back and re-route to Bug fix
or Feature.

## Bug fix

You own the diagnosis. Every shipped line traces to runtime evidence; a change that
"might help" is a hypothesis and does not ship.

1. **Reproduce first, on the matching surface.** A page bug reproduces in the browser
   (Playwright MCP via `visual-test`, `$DDEV_HTTP_URL`, `ssh web drush uli` for
   auth); a service bug reproduces in `ssh web drush php:eval` or a kernel test; a
   drush/cron/queue bug reproduces by running it. Paste the failing output. If it
   will not reproduce, force it: tighten conditions (anonymous user, empty field,
   second language, warm cache) or instrument (`\Drupal::logger()`, `dump()` in a
   scratch script) until it fires.
2. **Binary-search the cause.** Write 2-4 candidate hypotheses, then eliminate them
   with evidence, taking the split that cuts the most remaining space each pass.
   Suspect state before code for "works after `drush cr`" bugs (render cache, config
   overrides in `settings.php`, stale container). Two failed fixes sharing one
   assumption → **attack the premise** (engineering-principles) before a third.
3. **Confirm the mechanism** with runtime evidence before planning the fix. "The
   error went away" after a fix + `drush cr` is not a confirmed cause.
4. **Plan the fix.** Significant per the CLAUDE.md four questions → `code-review`
   PLAN mode. Otherwise delegate straight to the specialist with the confirmed
   mechanism in the brief.
5. **Failing test first** when a cheap local test path exists (Kernel-first per the
   **drupal-testing** rule): write it, run it, confirm it fails for the right reason,
   then fix, then rerun. Skip only when the test would be expensive or mock-heavy;
   say so and use the closest executable check (a drush script, a browser
   scenario) instead.
6. **Verify on the same surface as step 1.** The original repro now passes; paste the
   before/after output. Run the **drupal-blast-radius** skill when the fix touches a
   shared hook, service, template, or field.
7. `code-review` CODE mode; then summary: what was broken, root cause, fix, evidence.

## Feature

You own the design. Delegate implementation, stay in the lead.

1. `code-explorer` over the affected area; identify the data shape first (entity,
   field, config) per **foundational thinking**.
2. Significant per the CLAUDE.md four questions → `code-review` PLAN mode; store the
   Implementation Contract; it is binding for the implementer. Otherwise, delegate
   directly. Never fold a design decision silently into implementation: if you skipped
   PLAN, write `plan skipped: <reason>` in the summary.
3. Write the throughput checkpoint as todo items (keep `n/a: <reason>` when a
   dimension does not apply): blocking first steps (scaffold, schema, the test class);
   independent workstreams (module vs theme vs tests can run in parallel agents);
   shared mutable state (two agents must not edit one file or one config object);
   smallest safe decomposition.
4. Delegate with a specific scope: file paths, the data shape and its organizing
   structure, success criteria, and the contract text. Review the diff yourself; a
   specialist's summary is not the artifact.
5. Verify on the matching surface (kernel/functional test + drush or browser
   evidence). Export config if changed.
6. `code-review` CODE mode (conformance + quality). Summary: what you built, what you
   chose and why, open decisions, NOT VERIFIED items.

## Refactoring

You own the contract. The structure changes; the behavior does not. If the cleanup
reveals a bug or a missing feature, split it out and route it to its own playbook.

1. **Pin the behavior first.** Run the existing tests for the area; if there are none,
   write a characterization test (Kernel-first) or capture a baseline (a drush output,
   a rendered page snapshot via Playwright, a `config:get` dump) BEFORE moving any
   structure. PHPStan and PHPCS are not a pin.
2. Name the target shape in one paragraph (module layout, services, call graph) as if
   built today; run the **drupal-blast-radius** skill to list every consumer the
   change reaches (hook implementers, decorators, templates, views, config
   dependencies, tests).
3. Subtract before you add: delete dead code and one-caller wrappers first.
4. Move in small behavior-preserving steps, each keeping the pin green. In custom code
   migrate every caller and delete the old API in the same change; in contrib keep the
   deprecation layer. Spot-check every rename in strings, YAML, Twig, and docs — grep
   misses those.
5. Prove behavior is unchanged on the real artifact (same tests green, same baseline
   output diffed). Confirm the diff lowers reader load; if it does not, revert it.
6. `code-review` CODE mode. Summary: what changed structurally, the pin you held it
   against, the equivalence evidence, no new behavior.

## Prototype

You own a decision, not code. Use when the question is a fact you could observe by
running something (does this API behave that way, which of two layouts reads better,
how long does this query take) instead of asking the user.

1. State the decision the experiment settles. No decision → not a prototype; route to
   Feature.
2. Build the smallest throwaway thing that answers it: a `drush php:script` in a
   scratch file, a kernel test asserting the questioned behavior, two variants of a
   template behind a query parameter for screenshots, a query timed with
   `Database::startLog()` or Xdebug. No production framework, no quality pass.
3. Observe: paste the output, timing, or screenshots. The observation is the test.
4. Present the alternatives, the evidence, your recommendation, and the scratch path.
   Delete or clearly mark the throwaway. Hand the chosen direction to Feature.

Reserve questions to the user for genuine product or preference calls no experiment
can settle.

## Autonomous run (Ralph Loop)

You own the exit condition. There is no user to ask.

1. State the exit predicate before the first iteration: `bd ready --json` empty, the
   named tests green, the page state observed. Never relax it to declare victory.
2. Each iteration: pick the next ready task, make the smallest change the evidence
   justifies, verify it, close the task or revert. Keep the decision trail in Beads:
   `bd update <id> --notes "<what changed> | why | evidence: <command/file:line> |
   result: <tests green|reverted|blocked>"` — one row per iteration, evidence as a
   pointer, not prose.
3. Assumptions go in the task notes as `ASSUMPTION: ...` (coding-behavior §1) and the
   most conservative interpretation wins.
4. Discoveries are yours: file a new `bd create` for out-of-scope findings, fix
   blocking tooling in its own task, never park reversible work for the human.
5. A plateau is not a stop: change the approach. A genuine dead end is: record it in
   the task notes and stop, do not spin.

## Session handoff

**Pause safely** (explicit stop, context compaction near, going offline):

1. Stop at a safe boundary: finish or back out of the current atomic step; never leave
   a half-applied SEARCH/REPLACE set or a broken `.module` file.
2. Make the state durable without git writes: the Beads task notes carry intent, what
   is done and VERIFIED, what is NOT VERIFIED, the next action, key files, and gotchas
   (`bd update <id> --notes "Paused at: ..."`); the Implementation Contract stays in
   `plan-<task-id>.md`. Say plainly what is on disk versus still only in your head.

**Pick up** (resuming another session's work):

1. Read the trail first: `bd show <id> --json`, `plan-<task-id>.md`, `git status`,
   `git diff`, `LESSONS_LEARNED.md`. The trail is authoritative input — do not redo
   completed work.
2. Diff done versus planned and name the resume point.
3. Verify the inherited claims against the real artifact before building on them (run
   the named test, load the page). A prior self-report is not proof.
4. Route the remaining work to its playbook.
