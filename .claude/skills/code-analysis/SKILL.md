---
name: code-analysis
description: >-
  Standalone code quality analysis that produces a prioritized findings report:
  BLOCKERS (the code must NOT ship until fixed) strictly separated from SUGGESTIONS
  (improvements for quality, maintainability, scalability, Drupal community practices).
  Analysis only — it never fixes code. Designed to run manually, as an end-of-task
  gate, or headless from a second AI tool for an independent second opinion; it writes
  a comparable report file per run.
  Examples:
  - user: "analyze the code of this task" -> scope from git diff, tools + manual review, report
  - user: "analyze this module's code quality" -> full module analysis, report
  - user: "can this code be merged?" -> BLOCKER-focused pass, explicit verdict
  - user: "give me a second opinion on the changes" -> independent run, compare reports
  Never use to RUN the quality tool pipeline as an end in itself (use quality-checks).
  Never use for security-coverage prep for drupal.org (use drupal-security-coverage-prep).
  Never fix findings in the same run — report only.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# Code Analysis

Independent quality verdict on a body of code. Output = a report file with findings in
exactly two buckets — **BLOCKER** (cannot ship as-is) and **SUGGESTION** (worth improving)
— plus an explicit final verdict. This skill NEVER edits code, never commits, never
"quickly fixes" a finding. All PHP tooling via `ssh web`.

## Step 1 — Scope

- **Task/changes review** (default when there are uncommitted changes): analyze exactly
  the files in `git diff --name-only` + `git diff --cached --name-only`. Read the full
  file for context, but report findings only on changed code.
- **Module review** (user names a module): everything under
  `$DDEV_DOCROOT/modules/custom/<module>`.
- State the chosen scope at the top of the report. Do not silently widen it.

## Step 2 — Automated signal (input, not verdict)

Run the **quality-checks** pipeline on the scope (Audit module first, raw
PHPCS/PHPStan/PHPUnit as fallback). Tool output feeds Step 3:

- Tool errors on YOUR scoped code → candidate findings (classify in Step 3).
- Pre-existing errors outside the scope → one SUGGESTION line ("legacy debt exists in
  X"), never a reason to expand the analysis.
- Tests: run the module's existing suites. A failing test on scoped code is ALWAYS a
  BLOCKER.

## Step 3 — Manual review with fixed classification

Read every scoped file. Classify each finding using this table — do NOT invent
severities, do NOT emit warnings without a bucket:

**BLOCKER — merge is not acceptable (any single one fails the verdict):**

| Category | Examples |
|---|---|
| Security | SQL built by string interpolation; unescaped user input in output or Twig `\|raw` on user content; state-changing route without CSRF/permission; missing access checks; `eval`/`system`/backticks on variable input; hardcoded credentials |
| Data integrity | Writes without validation that can corrupt stored data; missing transactions where partial writes break invariants; destructive updates without guard |
| Fatality | Code that fatals on a reachable path (undefined function/class/service, wrong signature vs interface, `strict_types` violations); failing or crashing tests |
| Broken contracts | Service registered with wrong/missing arguments; hooks with wrong signatures; config schema absent for shipped config; broken DI (`\Drupal::` in an injectable class is a BLOCKER only in NEW code, SUGGESTION in touched legacy code) |
| Debug residue | `dpm()`, `dump()`, `var_dump()`, `console.log()`, `dd()`, commented-out debug blocks |

**SUGGESTION — improves quality, does not block:**

| Category | Examples |
|---|---|
| Drupal community practices | Missing cache metadata refinement (tags/contexts present but coarse), `t()` vs `$this->t()`, annotation style, naming conventions |
| Translations | Non-English source string inside `t()`/`\|t`/`Drupal.t()`; variable or concatenation inside `t()`; hardcoded user-facing string without a translation function (detection greps in the **translations** rule) |
| Performance / scalability | N+1 entity loads, unbounded queries missing `range()`, cacheable render arrays with `max-age 0`, missing lazy builders on personalized blocks |
| Maintainability | Duplicated logic worth extracting, over-long methods, missing interfaces on swappable services, unclear naming, missing docblocks on non-obvious code |
| Test coverage | Critical paths without tests, DI wiring (`create()`) never executed by the suite |

**Tie-breaker rule (state it, then apply it):** when in doubt between buckets, it is a
BLOCKER only if you can describe a concrete scenario where shipping it breaks security,
data, or the site. Otherwise SUGGESTION. Weak evidence + scary category ≠ BLOCKER.

## Step 4 — Write the report file

Write to the project root: `code-analysis-<tool>.md`, where `<tool>` is the runtime
(`opencode` or `claude`). Fixed format so two runs are diffable:

```markdown
# Code Analysis Report

- **Tool/model**: <runtime and model if known>
- **Date**: <YYYY-MM-DD>
- **Scope**: <diff of task X | module Y> (<N> files)
- **Verdict**: SHIP / DO NOT SHIP (<n> blockers)

## Blockers (must fix before merge)
| # | File:line | Category | Finding | Why it blocks |
|---|-----------|----------|---------|---------------|

## Suggestions (improve when possible)
| # | File:line | Category | Finding | Benefit |
|---|-----------|----------|---------|---------|

## Tool output summary
- PHPCS: <n> errors / PHPStan: <n> errors / Tests: <pass|fail>
```

Every finding needs `file:line`, and every BLOCKER needs the concrete failure scenario
in "Why it blocks" — a blocker that cannot articulate its scenario is a SUGGESTION.

## Second-opinion workflow (cross-tool validation)

The same analysis run twice with different tools/models, then compared:

1. **First pass** — the tool that implemented the task runs this skill at task end
   (before presenting the summary). Report: `code-analysis-opencode.md`.
2. **Second pass** — an automated job launches the OTHER tool headless on the same
   scope, e.g.: `claude -p "Run the code-analysis skill on the current uncommitted changes"`.
   Report: `code-analysis-claude.md`.
3. **Compare**: findings present in BOTH reports = high confidence, fix first.
   BLOCKER in one but absent in the other = re-verify against the Step 3 table before
   trusting either. Do not average severities — re-derive from the table.
4. The user reviews both reports and decides; report files are working artifacts —
   do not commit them.

## Rules

- Analysis only: no edits, no fixes, no git operations, no `bd close`.
- Never mark the verdict SHIP while any BLOCKER row exists.
- Findings must trace to read code — never report from tool output alone without
  opening the file (tools flag false positives; see **phpstan-phpcs-conflict-resolution**).
- Related: **code-review** agent (interactive multi-perspective gate during development);
  this skill is the standalone/automatable report variant.
