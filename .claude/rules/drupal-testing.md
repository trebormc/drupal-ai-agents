---
description: Drupal testing decision rules — test type selection, D10 vs D11 differences, common rules
globs:
  - "**/*Test.php"
  - "**/*TestBase.php"
  - "**/tests/**"
  - "**/*.feature"
  - "**/*.spec.ts"
---

# Drupal Testing — Decision Rules

This rule loads whenever generating tests for Drupal 10 or 11 code.
It defines which test type to use, version differences, and common rules.

## Supported Versions

- Drupal 10 (PHPUnit 9, PHP 8.1+)
- Drupal 11 (PHPUnit 10/11, PHP 8.3+)

Determine the project version before generating code. Differences affect syntax.

## Critical Differences Drupal 10 vs 11

| Aspect | Drupal 10 (PHPUnit 9) | Drupal 11 (PHPUnit 10/11) |
|---------|----------------------|--------------------------|
| `@dataProvider` | Instance methods OK | **Must be `static`** |
| `withConsecutive()` | Available | **Removed** -- use callbacks |
| Annotations | `@group`, `@covers` | Also supports PHP 8 attributes: `#[Group('x')]` |
| ChromeDriver | `chromeOptions` (deprecated 10.3) | **`goog:chromeOptions`** mandatory |
| phpunit.xml `<filter>` | `<filter><whitelist>` | **Replaced by `<source>`** |
| `printerClass` | In phpunit.xml | **Removed** -- use `HtmlOutputLogger` extension |
| `--verbose` | Supported | **Removed** in PHPUnit 10 |
| `installSchema('system', 'sequences')` | Deprecated in 10.2 | Do not use |
| PHPStan | v1 | **v2** (since 11.2) |
| `$modules` | `protected static $modules` | Same |

**If the project supports both versions:** use `static` in data providers, use
annotations (not attributes), avoid `withConsecutive()`.

## Decision Tree — Which Test Type to Generate

Follow this order. Stop at the first match.

### 1. Is it pure PHP logic without Drupal dependencies?

-> **Unit Test** (template inline below)

Indicators: the class can be instantiated without the container. Does not use entity
storage, database, config factory, or other Drupal services. If you need to mock more
than 4-5 services, move up to Kernel test.

Examples: utility classes, value objects, data transformations, calculations,
parsers, format validations.

### 2. Does it interact with services, entities, DB, config, plugins, hooks?

-> **Kernel Test** -- use skill `drupal-kernel-test`

This is the MOST USED and RECOMMENDED test type in custom Drupal. The community
prefers it over Functional tests whenever possible. Drupal core is actively
converting Functional -> Kernel for speed (~10x).

Examples: custom services with entity storage, entity CRUD, queries,
access logic, token replacement, migrations, plugin managers, event subscribers,
form handlers (logic, not UI), queue workers, cron hooks.

### 3. Do you need to verify rendered UI, forms, permissions via HTTP?

-> **Functional Test** -- use skill `drupal-functional-test`

Examples: configuration forms, node creation/editing via UI, verify that a user
without permissions gets 403, check HTML output, test redirects, verify blocks appear.

NO JavaScript. If there is AJAX -> FunctionalJavascript.

### 4. Does the functionality depend on JavaScript, AJAX, or dynamic interaction?

-> **FunctionalJavascript Test** -- use skill `drupal-functionaljs-test`

Examples: AJAX forms (select that reloads options), entity reference autocompletes,
modals, drag-and-drop, visibility toggles, CKEditor, complex #states with JS.

### 5. Is it an E2E flow, acceptance testing, or does the project already use Behat?

-> **Behat** -- use skill `drupal-behat-test`

If the project has `behat.yml`, E2E tests should be Behat for consistency.
Examples: complete user flows, acceptance criteria in Gherkin,
behavior tests that the client can read.

### 6. Do you need visual regression, cross-browser, or modern E2E without Behat?

-> **Playwright** -- use skill `drupal-playwright-test`

Examples: visual comparison between deploys, verify responsive layout, accessibility
tests, smoke tests, E2E flows in projects that do not use Behat.

## Unit Test Template (Inline -- No Skill Needed)

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
**Mocking:** Use `$this->createMock()` for dependencies. If too many (>4-5), use Kernel test.

## Common Rules for All Tests

1. Always `declare(strict_types=1);` after `<?php`.
2. Always `@group MODULE_NAME`.
3. Always type return as `void` in test methods.
4. Always call `parent::setUp()` first in `setUp()`.
5. Always `@dataProvider` with `static` method (D10+D11 compatibility).
6. Never use `sleep()` -- use waits in JS tests.
7. Never use `withConsecutive()`.
8. Prefer `assertSame()` over `assertEquals()`.
9. Prefer specific assertions: `assertCount()` instead of `assertTrue(count() === 3)`.
10. One test per behavior, not per method.

## Module Directory Structure

```
modules/custom/my_module/
├── src/
│   ├── Service/
│   ├── Plugin/
│   └── Form/
├── tests/
│   ├── src/
│   │   ├── Unit/           <- Unit tests
│   │   ├── Kernel/         <- Integration tests with kernel
│   │   ├── Functional/     <- Tests with simulated browser
│   │   └── FunctionalJavascript/ <- Tests with real Chrome
│   ├── modules/
│   │   └── my_module_test/ <- Auxiliary test module
│   └── behat/
│       └── features/       <- Behat scenarios (if applicable)
└── my_module.info.yml
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

# Form CORE (no project phpunit.xml — use Drupal core config + explicit env vars):
ssh web env SIMPLETEST_DB=mysql://db:db@db/db SIMPLETEST_BASE_URL=http://localhost \
  ./vendor/bin/phpunit -c $DDEV_DOCROOT/core $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit
```

Rules for BOTH forms:
- Always pass the test directory (or file) as an explicit path argument. Do NOT rely on `--testsuite` — suite definitions differ between configs.
- Narrow with `--filter testMethodName` or `--group MODULE` before the path argument.
- NEVER use `-c core` — the working directory in the web container is the project root, so `core/` only exists there when the docroot IS the project root. Always use `-c $DDEV_DOCROOT/core`.

```bash
# Single test method (example with Form ROOT)
ssh web ./vendor/bin/phpunit --filter testMethodName $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit

# Behat (uses behat.yml, not phpunit.xml — no config form needed)
ssh web ./vendor/bin/behat --config=behat.yml

# Playwright (runs on the HOST, not inside containers — ask the user to run it)
# npx playwright test
```

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
- Use `@covers` or `#[CoversClass()]` for precise coverage.
- Use `@codeCoverageIgnore` only for genuinely untestable code.
