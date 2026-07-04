---
name: drupal-multi-version-compat
description: >-
  Makes and keeps a contrib module compatible with Drupal 10, 11 and 12 at once, and triages
  automated compatibility issues (Project Update Bot / Upgrade Status). The right answer is often
  "do NOT apply the bot's patch yet" — this skill encodes which findings to accept and which to
  reject.
  Examples:
  - user: "make this module Drupal 12 compatible" -> apply the accept/reject matrix
  - user: "make it compatible with Drupal 10 and 11" -> core_version_requirement + CI opt-ins
  - user: "triage the Project Update Bot issue" -> verify vs local code, draft the reply
  - user: "upgrade status flags deprecated APIs" -> measure with PHPStan, fix only the real ones
  Never use for a full core UPGRADE of a running site (use drupal-update). Never blindly apply bot
  Rector patches — they can break D10 or violate Drupal coding standards.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x/12.x"
  environment: "ddev"
---

# Drupal Multi-Version Compatibility

Multi-version support creates conflicts where generic "modernize" advice is wrong. Measure
locally, then apply the matrix. All commands via `ssh web`.

## Step 1 — Measure, never trust the report

Bot / Upgrade Status reports come from the drupal.org snapshot, which may be many commits behind
your working tree. Verify every finding against local code first (in a real case 4 of 6 finding
categories were already fixed locally and one referenced deleted code).

Local measurement, no extra tooling: PHPStan with `phpstan-deprecation-rules`. If
`phpstan/extension-installer` is present, the deprecation rules are ALREADY active in every
normal run — a level-8 clean run means zero deprecated API usage. Do NOT add a manual
`includes:` entry for the deprecation rules in that case: PHPStan aborts the whole run with
an error when the same extension is included twice.

```bash
# 1. Is extension-installer present? If yes, deprecation rules already run — add NO includes.
ssh web composer show phpstan/extension-installer
# 2. Measure. Every remaining deprecation finding is real; anything the bot reports beyond
#    this list is stale.
ssh web ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom/<module>
```

## Step 2 — Accept/reject matrix

| Change | Verdict for `^10.2 || ^11 || ^12` |
|---|---|
| `core_version_requirement: ^10.2 \|\| ^11 \|\| ^12` in EVERY info.yml (submodules too) | REQUIRED |
| `REQUIREMENT_*` constants (removed in D12) | REQUIRED — normalize ONCE (one helper converting the `RequirementSeverity` enum and legacy ints to a single int), NOT the bot's per-line `DeprecationHelper::backwardsCompatibleCall()` |
| PHPUnit annotations → attributes | REJECT while D10 is supported: `#[DataProvider]` is invisible to PHPUnit 9 → data-provider tests silently break on D10. Keep annotations, accept the doc-comment warnings, file a follow-up |
| Procedural hooks → OOP `#[Hook]` classes | REJECT: needs D11.1+; procedural hooks work in 10/11/12. Optional even after dropping D10 |
| `#[RunTestsInSeparateProcesses]` on Kernel AND Functional test classes | REQUIRED (deprecated without it since D11.3, throws in D12; harmless on D10 — unknown attributes are ignored) |
| Rector patch brace style | Always re-run PHPCS: bot output uses PSR-12 braces that violate the Drupal standard |

### The REQUIREMENT_* normalization pattern

`REQUIREMENT_ERROR` etc. are deprecated since D11.2 and removed in D12; the replacement is the
`RequirementSeverity` int-backed enum (same values: Info -1, OK 0, Warning 1, Error 2). Do NOT
scatter `DeprecationHelper::backwardsCompatibleCall()` at every usage as the bot patch does —
write ONE helper and route all severity handling through it:

```php
use Drupal\Core\Extension\Requirement\RequirementSeverity;

/**
 * Normalizes a requirement severity to its legacy int value on any core.
 */
private function severityToInt(mixed $severity): int {
  if (class_exists(RequirementSeverity::class) && $severity instanceof RequirementSeverity) {
    return $severity->value;
  }
  return (int) $severity;
}
```

Where the module EMITS a severity (e.g. `hook_requirements()`), emit the enum when the class
exists and fall back to the legacy constant otherwise — one conditional, at one place.

## Step 3 — CI as permanent verification

`.gitlab-ci.yml` with the drupal.org `gitlab_templates` include and:

```yaml
OPT_IN_TEST_PREVIOUS_MAJOR: 1   # Drupal 10
OPT_IN_TEST_NEXT_MINOR: 1
OPT_IN_TEST_NEXT_MAJOR: 1       # Drupal 12
```

This runs the real test suites against every supported core on every push — the only proof that
matters, since a local environment runs a single core. (See **drupal-org-contribution-prep** for
full CI setup.)

## Step 4 — Respond to the bot issue

Draft a comment for the drupal.org issue: which findings were already fixed (with commit refs),
which were applied, which are rejected and why. Then close as Fixed and optionally remove the
`ProjectUpdateBotD12` tag to stop repeated patches.

## Pitfalls learned in the field

- Stale findings inflate the count (25 identical info.yml errors) — group by category before
  estimating work.
- "Drop Drupal 10?" is a PRODUCT decision: for some modules (e.g. site-audit tooling) D10 sites
  are the core audience. Keep D10 until its EOL or until the next-major CI job breaks, then bump
  `1.x` to `^11 || ^12` or open a `2.x` branch.
- Document every REJECTED modernization + its unblock condition in a committed `TECHNICAL_DEBT.md`
  so future agents do not "fix" it again.

## Verification

All of these must hold before reporting done:

```bash
# Every info.yml (submodules included) declares the full range:
grep -rn "core_version_requirement" $DDEV_DOCROOT/modules/custom/<module> --include=*.info.yml
# Zero deprecations + level clean:
ssh web ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom/<module>
# Drupal standard intact after any applied patch:
ssh web ./vendor/bin/phpcs --standard=Drupal,DrupalPractice $DDEV_DOCROOT/modules/custom/<module>
# Tests still pass on the LOCAL core (CI covers the other cores):
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/<module>/tests/src/Unit
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/<module>/tests/src/Kernel
```

The final proof is the GitLab CI pipeline green on all opted-in cores — local runs cover one
core only.
