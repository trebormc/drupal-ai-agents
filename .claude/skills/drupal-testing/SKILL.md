---
name: drupal-testing
description: >-
  Orchestrator for Drupal testing. Analyzes code, determines the correct test type,
  and delegates to the appropriate specialized skill. Covers the full test lifecycle:
  Unit, Kernel, Functional, FunctionalJavascript, Behat and Playwright.
  Use when writing tests, improving coverage, running test suites, or when
  the user asks to "generate tests" without specifying a type.
  For specific test types, use the specialized skills directly:
  drupal-unit-test (unit), drupal-kernel-test (kernel), drupal-functional-test
  (functional), drupal-functionaljs-test (JS), drupal-behat-test (behat),
  drupal-playwright-test (playwright).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Testing — Orchestrator

This skill coordinates test generation for Drupal 10/11 projects. It analyzes
the code under test and delegates to the appropriate specialized skill.

## Decision Flow

See the `drupal-testing` rule for the complete decision tree. Quick summary:

| Code Type | Test Type | Skill |
|-----------|-----------|-------|
| Pure PHP, no Drupal deps | Unit | Template in `drupal-testing` rule |
| Advanced unit mocking | Unit | `drupal-unit-test` |
| Services, entities, DB, config, plugins, hooks | Kernel | `drupal-kernel-test` |
| UI forms, HTTP permissions, HTML output | Functional | `drupal-functional-test` |
| AJAX, modals, autocompletes, JS | FunctionalJavascript | `drupal-functionaljs-test` |
| E2E flows, acceptance (Behat project) | Behat | `drupal-behat-test` |
| Visual regression, cross-browser, E2E (no Behat) | Playwright | `drupal-playwright-test` |

## Workflow

1. **Detect Drupal version** — check `core/lib/Drupal.php` or `composer.json`
2. **Read the code** — understand dependencies and Drupal API usage
3. **Check existing tests** — look at `tests/` folder, match existing style
4. **Apply decision tree** — use the `drupal-testing` rule
5. **Load specialized skill** — delegate to the appropriate skill
6. **Execute and verify** — run the test, fix if it fails

## Test Execution Commands

Replace `MODULE` with the module machine name.

**STEP 1 — Pick the config form. Run ONCE, then use the matching form for the whole session:**

```bash
ssh web test -f phpunit.xml && echo "ROOT" || echo "CORE"
```

```bash
# Form ROOT (project phpunit.xml exists — it already sets env vars):
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Kernel
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Functional
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/FunctionalJavascript

# Form CORE (no project phpunit.xml — Drupal core config + explicit env vars):
ssh web env SIMPLETEST_DB=mysql://db:db@db/db SIMPLETEST_BASE_URL=http://localhost \
  ./vendor/bin/phpunit -c $DDEV_DOCROOT/core $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Single test method (add --filter before the path; works with both forms)
ssh web ./vendor/bin/phpunit --filter testMethodName $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Coverage (requires Xdebug; report written to /tmp/coverage in the web container)
ssh web env XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-html /tmp/coverage \
  $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Behat (uses behat.yml, not phpunit.xml)
ssh web ./vendor/bin/behat --config=behat.yml

# Playwright (runs on the HOST — ask the user to run: npx playwright test)
```

**Rules:** always pass the test directory as an explicit path; never rely on `--testsuite`; never use `-c core` (use `-c $DDEV_DOCROOT/core` only in Form CORE). If a test fails to start (DB/URL/autoload errors), see the error table in the **drupal-testing** rule.

## Test Directory Structure

```
$DDEV_DOCROOT/modules/custom/MODULE/
└── tests/
    ├── src/
    │   ├── Unit/                     <- drupal-unit-test
    │   ├── Kernel/                   <- drupal-kernel-test
    │   ├── Functional/               <- drupal-functional-test
    │   └── FunctionalJavascript/     <- drupal-functionaljs-test
    ├── modules/
    │   └── MODULE_test/              <- Auxiliary test module
    └── behat/
        └── features/                 <- drupal-behat-test
```

## Common Rules (All Test Types)

1. Always `declare(strict_types=1);` after `<?php`
2. Always `@group MODULE_NAME`
3. Always type return as `void` in test methods
4. Always call `parent::setUp()` first in `setUp()`
5. Always use `static` data providers (D10+D11 compatibility)
6. Never use `sleep()` — use waits in JS tests
7. Never use `withConsecutive()` — removed in PHPUnit 10
8. Prefer `assertSame()` over `assertEquals()`
9. One test per behavior, not per method
10. Use PHPDoc annotations, not PHP 8 attributes (D10 compatibility)

## Related Skills

- **drupal-unit-test** — Advanced mock patterns, service mocking, reflection DI
- **drupal-kernel-test** — Services, entities, DB, config, plugins, hooks
- **drupal-functional-test** — Forms, permissions, HTML output
- **drupal-functionaljs-test** — AJAX, modals, autocompletes
- **drupal-behat-test** — BDD, acceptance testing, Gherkin
- **drupal-playwright-test** — Visual regression, cross-browser, E2E
- **quality-checks** — Code quality validation after writing tests
- **drupal-debugging** — Test debugging and troubleshooting
