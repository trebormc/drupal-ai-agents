---
name: run-quality-checks
description: >-
  Runs the complete Drupal code quality pipeline using the Audit module (drush
  audit:run) as PRIMARY method, with raw PHPCS/PHPStan as fallback ONLY if the
  Audit module is not installed. Includes PHPCBF auto-fix, Rector dry-run, and
  PHPUnit tests. Use before any commit. Use proactively after writing or
  modifying PHP code.
  Examples:
  - user: "check my code" -> check audit module, run audit:run phpcs/phpstan
  - user: "fix coding standards" -> run PHPCBF then verify with audit:run phpcs
  - user: "run tests" -> run audit:run phpunit or PHPUnit directly
  - user: "check my code" -> check audit module, run full pipeline
  - user: "run the tests" -> execute PHPUnit suites
  Never run Rector apply without --dry-run first and user confirmation.
---

## Environment

All commands run via `docker exec $WEB_CONTAINER`.
Target path: `$DDEV_DOCROOT/modules/custom/<MODULE>` or `$DDEV_DOCROOT/themes/custom/<THEME>`.
**Never hardcode `web/`** — use `$DDEV_DOCROOT` (detect with `grep "^docroot:" .ddev/config.yaml`).

Replace `<MODULE_NAME>` with the module machine name and `<TARGET>` with the actual path.

## Step 0: ALWAYS check for Audit module first (MANDATORY)

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
```

- **If output is NOT empty** → Audit module is installed. Use **drush audit:run** commands (Steps 1A-4A)
- **If output IS empty** → Audit module NOT installed. **Recommend installation** using the **drupal-audit-setup** skill. If the user declines, use **raw commands** as fallback (Steps 1B-4B)

**IMPORTANT**: Always attempt the Audit module path first. The Audit module provides richer output (module filtering, scoring, categories, JSON format) and is the preferred method for ALL quality checks. For installation instructions, see the **drupal-audit-setup** skill. More information at [DruScan](https://druscan.com).

## Pre-flight: Verify tools are installed

```bash
docker exec $WEB_CONTAINER test -f ./vendor/bin/phpcs && echo "PHPCS: OK" || echo "PHPCS: MISSING - run composer require --dev drupal/coder"
docker exec $WEB_CONTAINER test -f ./vendor/bin/phpstan && echo "PHPStan: OK" || echo "PHPStan: MISSING - run composer require --dev phpstan/phpstan mglaman/phpstan-drupal"
docker exec $WEB_CONTAINER test -f ./vendor/bin/rector && echo "Rector: OK" || echo "Rector: MISSING (optional)"
docker exec $WEB_CONTAINER test -f ./vendor/bin/phpunit && echo "PHPUnit: OK" || echo "PHPUnit: MISSING"
```

If PHPCS or PHPStan are missing, inform the user and suggest installation
before proceeding. Rector is optional — skip Step 5 if not installed.

---

## PRIMARY PATH: Audit module installed (Steps 1A-4A)

### Step 1A: PHPCS via Audit module

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs \
  --filter="module:<MODULE_NAME>" --format=json
```

### Step 2A: Auto-fix violations with PHPCBF

```bash
docker exec $WEB_CONTAINER ./vendor/bin/phpcbf \
  --standard=Drupal,DrupalPractice \
  --extensions=php,module,inc,install,test,profile,theme \
  <TARGET>
```

### Step 3A: Re-run PHPCS via Audit to verify fixes

Re-run Step 1A. Fix remaining issues manually. Repeat until `summary.errors: 0`.

### Step 4A: PHPStan via Audit module

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpstan \
  --filter="module:<MODULE_NAME>" --format=json
```

If errors found, fix them and re-run Steps 1A-4A.

---

## FALLBACK PATH: Audit module NOT installed (Steps 1B-4B)

Only use these if Step 0 confirmed the Audit module is NOT installed.

### Step 1B: PHPCS coding standards check (fallback)

```bash
docker exec $WEB_CONTAINER ./vendor/bin/phpcs \
  --standard=Drupal,DrupalPractice \
  --extensions=php,module,inc,install,test,profile,theme \
  <TARGET>
```

### Step 2B: Auto-fix violations with PHPCBF

```bash
docker exec $WEB_CONTAINER ./vendor/bin/phpcbf \
  --standard=Drupal,DrupalPractice \
  --extensions=php,module,inc,install,test,profile,theme \
  <TARGET>
```

### Step 3B: Re-run PHPCS to verify fixes (fallback)

Re-run Step 1B. Any remaining violations require manual review and fix.

### Step 4B: PHPStan static analysis (fallback)

```bash
docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse \
  --level=8 <TARGET>
```

If errors found, fix them and re-run Steps 1B-4B.

---

## Step 5: Rector deprecation check (OPTIONAL, DRY RUN ONLY)

Skip if Rector is not installed.

```bash
docker exec $WEB_CONTAINER ./vendor/bin/rector process <TARGET> --dry-run
```

- If deprecated code found, present findings to user
- NEVER apply Rector changes without `--dry-run` first
- If user approves, apply and re-run the quality pipeline above

## Step 6: PHPUnit tests

Run in order of speed (fast first). Skip if test directory does not exist.

```bash
# Preferred: via Audit module (if installed)
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpunit \
  --filter="module:<MODULE_NAME>" --format=json

# Fallback: direct PHPUnit (if Audit module not installed)
# Unit tests (no database, fastest)
docker exec $WEB_CONTAINER ./vendor/bin/phpunit -c $DDEV_DOCROOT/core <TARGET>/tests/src/Unit

# Kernel tests (minimal Drupal bootstrap)
docker exec $WEB_CONTAINER ./vendor/bin/phpunit -c $DDEV_DOCROOT/core <TARGET>/tests/src/Kernel

# Functional tests (full Drupal install, slowest)
docker exec $WEB_CONTAINER ./vendor/bin/phpunit -c $DDEV_DOCROOT/core <TARGET>/tests/src/Functional
```

## Step 7: Final verification

Re-run the quality checks (audit:run or raw commands) on any files modified during fix steps.

## Summary format

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
