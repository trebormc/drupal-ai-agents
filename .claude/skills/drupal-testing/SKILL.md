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
| Pure PHP, no Drupal deps | Unit | Template below (Unit Test Template) |
| Advanced unit mocking | Unit | `drupal-unit-test` |
| Services, entities, DB, config, plugins, hooks | Kernel | `drupal-kernel-test` |
| UI forms, HTTP permissions, HTML output | Functional | `drupal-functional-test` |
| AJAX, modals, autocompletes, JS | FunctionalJavascript | `drupal-functionaljs-test` |
| E2E flows, acceptance (Behat project) | Behat | `drupal-behat-test` |
| Visual regression, cross-browser, E2E (no Behat) | Playwright | `drupal-playwright-test` |

**Tie-breakers (apply them, do not deliberate):** touches any Drupal service or needs >4-5 mocks → Kernel. Assertion about logic/data, not HTML/HTTP → Kernel over Functional. No-JS behavior → never FunctionalJS. `behat.yml` exists → Behat, else Playwright. Pick ONE type per behavior.

## Workflow

1. **Detect Drupal version** — check `core/lib/Drupal.php` or `composer.json`
2. **Read the code** — understand dependencies and Drupal API usage
3. **Check existing tests** — look at `tests/` folder, match existing style
4. **Apply decision tree** — use the `drupal-testing` rule
5. **Load specialized skill** — delegate to the appropriate skill
6. **Execute and verify** — run the test, fix if it fails

Common rules 1-13 in the **drupal-testing** rule apply to every generated test.
Annotations (`@group`, `@covers`, `@dataProvider`), not attributes — except
`#[RunTestsInSeparateProcesses]` on Kernel/Functional/FunctionalJS classes on Drupal 11.3+
(see the rule; the specialized skills' templates already include it).

## Unit Test Template

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\MODULE\Unit;

use Drupal\MODULE\CLASS_UNDER_TEST;
use Drupal\Tests\UnitTestCase;

/**
 * @coversDefaultClass \Drupal\MODULE\CLASS_UNDER_TEST
 * @group MODULE
 */
class CLASS_UNDER_TESTTest extends UnitTestCase {

  protected CLASS_UNDER_TEST $sut;

  protected function setUp(): void {
    parent::setUp();
    $this->sut = new CLASS_UNDER_TEST();
  }

  /**
   * @covers ::method
   */
  public function testMethod(): void {
    $result = $this->sut->method('input');
    $this->assertSame('expected', $result);
  }

  /**
   * @covers ::method
   * @dataProvider providerData
   */
  public function testMethodWithData(string $input, string $expected): void {
    $this->assertSame($expected, $this->sut->method($input));
  }

  public static function providerData(): array {
    return [
      'normal case' => ['input', 'expected'],
      'empty case' => ['', ''],
    ];
  }

  /**
   * @covers ::method
   */
  public function testMethodWithException(): void {
    $this->expectException(\InvalidArgumentException::class);
    $this->sut->method(NULL);
  }

}
```

**Location:** `modules/custom/MODULE/tests/src/Unit/` mirroring `src/`.
**Mocking:** Use `$this->createMock()` for dependencies. If too many (>4-5), use Kernel test (or the **drupal-unit-test** skill for advanced mock patterns).

## Module Directory Structure

```
$DDEV_DOCROOT/modules/custom/MODULE/
├── src/
│   ├── Service/
│   ├── Plugin/
│   └── Form/
├── tests/
│   ├── src/
│   │   ├── Unit/                     <- Unit tests (template above / drupal-unit-test)
│   │   ├── Kernel/                   <- Integration tests with kernel (drupal-kernel-test)
│   │   ├── Functional/               <- Tests with simulated browser (drupal-functional-test)
│   │   └── FunctionalJavascript/     <- Tests with real Chrome (drupal-functionaljs-test)
│   ├── modules/
│   │   └── MODULE_test/              <- Auxiliary test module
│   └── behat/
│       └── features/                 <- Behat scenarios, if applicable (drupal-behat-test)
└── MODULE.info.yml
```

## Running PHPUnit (Canonical Pattern)

Replace `MODULE` with the module machine name in all commands below.

**STEP 1 — Pick the config form. Run this ONCE, then use the matching form for the whole session:**

```bash
ssh web test -f phpunit.xml && echo "ROOT" || echo "CORE"
```

**STEP 2 — Run tests with the matching form:**

```bash
# Form ROOT (project has phpunit.xml at project root — it already sets env vars):
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Kernel
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Functional
ssh web ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/FunctionalJavascript

# Form CORE (no project phpunit.xml — use Drupal core config + explicit env vars):
ssh web env SIMPLETEST_DB=mysql://db:db@db/db SIMPLETEST_BASE_URL=http://localhost \
  ./vendor/bin/phpunit -c $DDEV_DOCROOT/core $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit
```

Rules for BOTH forms:
- Always pass the test directory (or file) as an explicit path argument. Do NOT rely on `--testsuite` — suite definitions differ between configs.
- Narrow with `--filter testMethodName` or `--group MODULE` before the path argument.
- NEVER use `-c core` — the working directory in the web container is the project root, so `core/` only exists there when the docroot IS the project root. Always use `-c $DDEV_DOCROOT/core`.
- Do not `export` env vars in the agent container (they would not reach the web container via SSH) — pass them inline with `env` as shown.

```bash
# Single test method (example with Form ROOT; add --filter before the path in either form)
ssh web ./vendor/bin/phpunit --filter testMethodName $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Coverage (requires Xdebug; report written to /tmp/coverage in the web container)
ssh web env XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-html /tmp/coverage \
  $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Behat (uses behat.yml, not phpunit.xml — no config form needed)
ssh web ./vendor/bin/behat --config=behat.yml

# Playwright (runs on the HOST, not inside containers — ask the user to run it)
# npx playwright test
```

A project-root `phpunit.xml` (Form ROOT) can be created with the template in the **quality-tools-setup** skill.

**If a test fails to START (setup error, not an assertion failure):**

| Error | Cause | Fix |
|-------|-------|-----|
| `Class not found` | Stale autoloader | `ssh web composer dump-autoload`, then retry |
| `Could not connect to database` / `SQLSTATE` | SIMPLETEST_DB not set | Use Form CORE with explicit env vars |
| `Failed to connect to localhost` | SIMPLETEST_BASE_URL not set | Use Form CORE with explicit env vars |
| `Test site directory exists already` | Stale test site | `ssh web rm -rf $DDEV_DOCROOT/sites/simpletest/` then retry |
| ChromeDriver/WebDriver errors (FunctionalJS) | Driver not running | See **drupal-functionaljs-test** skill troubleshooting |

## Recommended Coverage

No official minimum in Drupal. Reasonable targets:

- 80% line coverage as industry standard.
- More important than percentage: cover critical paths and edge cases.
- Use `@covers` / `@coversDefaultClass` for precise coverage (annotations, not `#[CoversClass()]`, for D10+D11 compatibility).
- Use `@codeCoverageIgnore` only for genuinely untestable code.

## Related Skills

- **drupal-unit-test** — Advanced mock patterns, service mocking, reflection DI
- **drupal-kernel-test** — Services, entities, DB, config, plugins, hooks
- **drupal-functional-test** — Forms, permissions, HTML output
- **drupal-functionaljs-test** — AJAX, modals, autocompletes
- **drupal-behat-test** — BDD, acceptance testing, Gherkin
- **drupal-playwright-test** — Visual regression, cross-browser, E2E
- **quality-tools-setup** — First-time PHPStan/PHPCS/Rector/GrumPHP/phpunit.xml setup
- **quality-checks** — Code quality validation after writing tests
- **drupal-debugging** — Test debugging and troubleshooting
