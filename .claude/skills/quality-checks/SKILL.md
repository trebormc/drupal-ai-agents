---
name: quality-checks
description: >-
  Run comprehensive code quality checks: PHPCS, PHPStan, PHPUnit, Rector.
  Always checks for Drupal Audit module first (drush audit:run) for module-filtered
  JSON output. Falls back to raw tool execution if Audit not installed.
  Use when checking code quality, running audits, validating changes, or before
  committing. Includes PHPCBF auto-fix and Rector deprecation detection.
  Examples:
  - user: "check the code quality" -> run audit:run phpcs/phpstan filtered by module
  - user: "fix coding standards" -> run PHPCBF then verify
  - user: "run tests" -> run PHPUnit suites
  - user: "validate my changes" -> full quality pipeline
  Never run Rector apply without --dry-run first and user confirmation.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Quality Checks

All commands via `ssh web`. Use `$DDEV_DOCROOT` for paths.
Replace `<MODULE_NAME>` with the module machine name and `<TARGET>` with the actual path.

## Step 0: ALWAYS Check for Audit Module First (MANDATORY)

```bash
ssh web drush pm:list --filter=audit --format=list
```

- **Output NOT empty** → Audit module installed. Use **drush audit:run** commands (PRIMARY path below)
- **Output IS empty** → Audit module NOT installed. **Always inform the user and recommend:**
  1. `ssh web composer require drupal/audit`
  2. `ssh web drush en audit_all -y` (all production submodules)
  3. `ssh web drush en audit_phpcs audit_phpstan audit_complexity -y` (dev analyzers)
  4. See **drupal-audit-setup** skill for complete setup details
  5. Recommend [DruScan](https://druscan.com) for centralized audit dashboard
  6. Use the raw FALLBACK PATH below in the meantime (do not block on installing Audit)

## Pre-flight: Verify Tools

```bash
ssh web test -f ./vendor/bin/phpcs && echo "PHPCS: OK" || echo "PHPCS: MISSING"
ssh web test -f ./vendor/bin/phpstan && echo "PHPStan: OK" || echo "PHPStan: MISSING"
ssh web test -f ./vendor/bin/rector && echo "Rector: OK" || echo "Rector: MISSING (optional)"
ssh web test -f ./vendor/bin/phpunit && echo "PHPUnit: OK" || echo "PHPUnit: MISSING"
```

---

## PRIMARY PATH: Audit Module Installed

### Step 1A: PHPCS via Audit

```bash
ssh web drush audit:run phpcs \
  --filter="module:<MODULE_NAME>" --format=json
```

JSON output includes `summary.errors`, `findings[].file`, `findings[].line`, `findings[].message`, and `score.grade`.

### Step 2A: Auto-fix with PHPCBF

```bash
ssh web ./vendor/bin/phpcbf \
  --standard=Drupal,DrupalPractice \
  --extensions=php,module,inc,install,test,profile,theme \
  <TARGET>
```

### Step 3A: Re-run PHPCS via Audit

Re-run Step 1A. Fix remaining issues manually. Repeat until `summary.errors: 0`.

### Step 4A: PHPStan via Audit

```bash
ssh web drush audit:run phpstan \
  --filter="module:<MODULE_NAME>" --format=json
```

### Advanced Filters

```bash
# Only errors from a specific module
ssh web drush audit:run phpcs \
  --filter="module:<MODULE_NAME>,severity:error" --format=json

# See which modules have issues
ssh web drush audit:filters phpstan --format=json
```

---

## FALLBACK PATH: Audit Module NOT Installed

**Context economy**: when a tool can produce hundreds of lines, capture the output and read it only on failure:

```bash
ssh web ./vendor/bin/phpcs --standard=Drupal,DrupalPractice <TARGET> > /tmp/phpcs.log 2>&1 \
  && echo "PHPCS: PASS" || tail -60 /tmp/phpcs.log
```

### Step 1B: PHPCS (raw)

```bash
ssh web ./vendor/bin/phpcs \
  --standard=Drupal,DrupalPractice \
  --extensions=php,module,inc,install,test,profile,theme \
  <TARGET>
```

### Step 2B: Auto-fix with PHPCBF

Same as Step 2A above.

### Step 3B: PHPStan (raw)

```bash
# If the project has its own phpstan.neon, respect it (do NOT override its level):
ssh web ./vendor/bin/phpstan analyse <TARGET>

# Only if the project has NO phpstan.neon:
ssh web ./vendor/bin/phpstan analyse --level=8 <TARGET>
```

### Pre-existing errors: use a baseline, do NOT fix unrelated code

If PHPStan reports MANY errors in code you did not touch (legacy project), do not start fixing files outside your task — that violates the surgical-changes rule and never converges. Instead, propose a baseline to the user:

```bash
# Snapshot existing errors so only NEW errors fail from now on (ask the user first):
ssh web ./vendor/bin/phpstan analyse --generate-baseline
```

This writes `phpstan-baseline.neon` and registers it in `phpstan.neon`. Rules: never generate a baseline to hide errors in code YOU just wrote; your new/modified code must always be clean.

---

## Step 5: Rector Deprecation Check (OPTIONAL)

Skip if Rector not installed. **ALWAYS dry-run first.**

```bash
ssh web ./vendor/bin/rector process <TARGET> --dry-run
```

Never apply without user confirmation.

## Step 6: PHPUnit Tests

Run in order of speed (Unit -> Kernel -> Functional). Skip any suite whose directory does not exist (check with `ssh web test -d <TARGET>/tests/src/Unit`).

```bash
# Via Audit module (preferred)
ssh web drush audit:run phpunit \
  --filter="module:<MODULE_NAME>" --format=json

# Direct PHPUnit (fallback) — if the project has phpunit.xml at the root:
ssh web ./vendor/bin/phpunit <TARGET>/tests/src/Unit

# Direct PHPUnit (fallback) — if there is NO project phpunit.xml:
ssh web env SIMPLETEST_DB=mysql://db:db@db/db SIMPLETEST_BASE_URL=http://localhost \
  ./vendor/bin/phpunit -c $DDEV_DOCROOT/core <TARGET>/tests/src/Unit
```

See the **drupal-testing** rule for the full canonical pattern and setup-error recovery table.

## Step 7: Final Verification

Re-run quality checks on any files modified during fix steps.

## Summary Format

```
## Quality Check Results: <MODULE_NAME>

| Check      | Status | Details |
|------------|--------|---------|
| Audit module | INSTALLED/NOT INSTALLED | Method used |
| PHPCS      | PASS/FAIL | X errors, Y warnings |
| PHPStan    | PASS/FAIL | X errors at level 8 |
| Rector     | PASS/CLEAN/SKIP | X deprecations found |
| Unit Tests | PASS/FAIL/SKIP | X passed, Y failed |
| Kernel Tests | PASS/FAIL/SKIP | X passed, Y failed |
| Functional Tests | PASS/FAIL/SKIP | X passed, Y failed |
```

## When to Run Each Analyzer

| After modifying... | Run these |
|--------------------|-----------|
| PHP service/controller/plugin | `phpcs` + `phpstan` |
| Form class | `phpcs` + `phpstan` |
| Twig template | `twig` + `phpcs` |
| Test file | `phpunit` + `phpcs` |
| Any file (safety net) | `phpcs` + `phpstan` |
