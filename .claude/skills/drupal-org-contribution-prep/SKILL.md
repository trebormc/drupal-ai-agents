---
name: drupal-org-contribution-prep
description: >-
  Prepares a custom module's repository for contribution to drupal.org: GitLab CI, test-suite
  registration, repository hygiene, and the hand-off documents future maintainers (human or AI)
  need. Use before publishing or contributing a module to the community.
  Examples:
  - user: "prepare this module for drupal.org" -> CI + suite registration + hygiene
  - user: "I want to contribute the module to the community" -> full prep workflow
  - user: "set up gitlab ci for drupal.org" -> gitlab_templates include + opt-ins
  - user: "publish the module on drupal.org" -> hygiene sweep + TECHNICAL_DEBT.md
  Never use for security-advisory coverage prep (use drupal-security-coverage-prep). Never use
  for multi-core compatibility triage (use drupal-multi-version-compat).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# Drupal.org Contribution Prep

A module can be functionally perfect and still present badly. Fix presentation before
contributing. All test commands via `ssh web`.

## 1. Test-suite registration (the silent-failure trap)

`phpunit.xml.dist` MUST declare `unit`, `kernel` AND `functional` suites. A project declaring
only `unit` accumulates kernel failures nobody sees (in the field: 10 kernel failures + a
missing fixtures directory went unnoticed for months).

```xml
<testsuites>
  <testsuite name="unit">
    <directory>web/modules/custom/*/tests/src/Unit</directory>
  </testsuite>
  <testsuite name="kernel">
    <directory>web/modules/custom/*/tests/src/Kernel</directory>
  </testsuite>
  <testsuite name="functional">
    <directory>web/modules/custom/*/tests/src/Functional</directory>
  </testsuite>
</testsuites>
```

(Adapt `web/` to the real `$DDEV_DOCROOT`.) Then actually RUN all three suites — do not stop at
registering them. Also verify every fixture path referenced in any `setUp()` exists in the repo:

```bash
grep -rn "fixtures" $DDEV_DOCROOT/modules/custom/<module>/tests --include=*.php | grep -oE "[A-Za-z0-9_./-]*fixtures[A-Za-z0-9_./-]*" | sort -u
# ls each resulting path — a missing directory means tests silently test nothing.
```

## 2. GitLab CI

`.gitlab-ci.yml` including the official `gitlab_templates` (`$_GITLAB_TEMPLATES_REPO`) with
opt-ins matching the declared core range:

```yaml
include:
  - project: $_GITLAB_TEMPLATES_REPO
    ref: $_GITLAB_TEMPLATES_REF
    file: .gitlab-ci.yml
variables:
  OPT_IN_TEST_PREVIOUS_MAJOR: 1
  OPT_IN_TEST_NEXT_MINOR: 1
  OPT_IN_TEST_NEXT_MAJOR: 1
```

A green pipeline is the first thing reviewers look at. Layout gotcha: the module's own
`phpstan.neon` on drupal.org CI resolves includes against an ADJACENT `vendor/`; installed under
`modules/contrib` those includes fail. Document a local-equivalent config rather than "fixing"
the neon — it is correct for its target environment.

## 3. Repository hygiene

- Remove orphaned dirs (empty submodule stubs, stale fixture duplicates). Upgrade Status parses
  ALL Twig files, so a broken leftover fixture becomes a public finding in bot issues.
- Check the git INDEX, not just the worktree — staged-then-deleted ghost files ride along
  silently:

  ```bash
  git status --short | grep "^AD"        # ghost entries: staged, then deleted on disk
  git rm --cached <path>                 # remove each from the index (do NOT git add anything)
  ```

- Internal working notes → a committed, ENGLISH `TECHNICAL_DEBT.md`. Run every verification
  command BEFORE documenting it (one of ours did not work as written). Fixed structure:

  ```markdown
  # Technical Debt — <module>
  ## Status snapshot (<YYYY-MM-DD>)
  <one paragraph: suites green?, PHPStan level, PHPCS clean?, supported cores>
  ## Deferred / blocked
  - <item> — blocked by: <condition>. Unblock when: <exact condition>.
  ## Deliberate suppressions
  - <file:line> <rule/identifier> — kept because: <reason>.
  ## Conventions
  - <e.g. "annotations, not PHP attributes, while D10 is supported">
  ## Verification commands (each one verified to work)
  - `<exact command>` — expected: <result>
  ```

- Fact-check that document on every session that changes code: stale claims are worse than none,
  because agents trust it.

## 4. Hand-off conventions for AI agents

Leave the repo self-describing for the next agent:

- `TECHNICAL_DEBT.md` as above — the anti-"helpful fix" fence.
- Commit-message-file workflow if the human commits manually (`commit-msg.txt` at the repo root,
  regenerated per pending diff, excluded from the commit itself — see the **commit-message** skill).
- Deferred work filed in the tracker with its unblock condition, NOT as TODO comments.

## 5. Release readiness (report only)

Security advisory coverage and most reviewer goodwill require a STABLE release; dev/alpha/beta/RC
do not count. Check the issue queue for open "security"-tagged issues before any coverage
application (see **drupal-security-coverage-prep**).

## Verification

Pipeline green on all opted-in core versions; all three suites runnable locally with the
documented commands; `git status` clean of ghost entries; `TECHNICAL_DEBT.md` claims spot-checked
against the code.
