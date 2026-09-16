---
description: Drupal testing decision rules — test type selection, D10 vs D11 differences, common rules
paths:
  - "**/*Test.php"
  - "**/*TestBase.php"
  - "**/tests/**"
  - "**/*.feature"
  - "**/*.spec.ts"
---

# Drupal Testing — Decision Rules

This rule loads whenever generating tests for Drupal 10 or 11 code.
It defines which test type to use, version differences, and common rules.
Unit template, directory layout, run commands: **drupal-testing** skill.

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
| `#[RunTestsInSeparateProcesses]` | Recommended | **Required on Kernel/Functional/FunctionalJS classes since 11.3** (`use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;`) — never on Unit tests |

**If the project supports both versions:** use `static` in data providers, use
annotations (not attributes), avoid `withConsecutive()`.

**Annotations vs attributes (applies to every test type):** use PHPDoc annotations
(`@group`, `@covers`, `@coversDefaultClass`, `@dataProvider`) for Drupal 10+11
compatibility — PHPUnit 9 on Drupal 10 ignores metadata attributes. The ONE exception is
`#[RunTestsInSeparateProcesses]`: add it to Kernel, Functional and FunctionalJavascript
classes when the project runs Drupal 11.3+ (deprecated without it, throws in 12); it is
harmless to omit on 10.x. Never add it to Unit tests.

## Decision Tree — Which Test Type to Generate

Follow this order. Stop at the first match.

**Tie-breakers (when two types seem to fit, do not deliberate — apply these):**
- Unit vs Kernel: if the class touches ANY Drupal service, or needs more than 4-5 mocks → Kernel.
- Kernel vs Functional: if the assertion is about logic/data (not rendered HTML or HTTP responses) → Kernel (it is ~10x faster).
- Functional vs FunctionalJavascript: only go FunctionalJS if the behavior does not exist without JavaScript.
- Behat vs Playwright: if `behat.yml` exists in the project → Behat; otherwise → Playwright.
- State your choice in one sentence in the test's docblock or your summary — do not write tests of two types for the same behavior.

### 1. Is it pure PHP logic without Drupal dependencies?

-> **Unit Test** (template in the **drupal-testing** skill; advanced mocking in `drupal-unit-test`)

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
11. **Always assert the return value of `waitForElement()` / `waitForText()` and
    friends** — they return `NULL` on timeout instead of failing, so a bare call
    produces a test that always passes: wrap it in
    `$this->assertNotEmpty($this->assertSession()->waitForElement('css', '#el'));`.
12. **Functional tests run TWO Drupal instances** (the PHPUnit process and the web
    server) sharing one database but separate memory. State, services, or static
    caches set in test code are invisible to the requests the test makes — when this
    bites, rebuild containers/caches explicitly and comment WHY.
13. **The NULL test — a test must be able to fail for a defect.** Before keeping a
    test ask: would it still pass if every method of the class under test returned
    `NULL`? If yes, it observes no behavior. Five shapes that fail this check:
    - Weak assertion only: `assertNotNull`, `assertTrue((bool) $x)`, `assertInstanceOf`
      on the return, no assertion at all.
    - Mock-only: asserting a mock's `expects($this->once())` was satisfied with no
      assertion on the result or the state after the call.
    - Self-referential: `assertSame($sut->compute($a), $sut->compute($a))` or the
      expected value built by calling the code under test.
    - Constant pin: restating a hand-maintained constant or config default
      (`assertSame(50, MyService::LIMIT)`).
    - Fixture asserts fixture: asserting data the `setUp()` created while the subject
      never runs in the test body.
    Fix: call the subject with one concrete input and assert the literal output or the
    observable effect (`assertSame('hello-world', $sut->slugify('Hello, World!'))`);
    for a mock, assert the payload it received; for an absence, assert the presence on
    the other input in the same test. No such assertion exists → delete the test.

Directory layout, canonical PHPUnit run pattern (ROOT/CORE forms + setup-error table),
coverage targets: **drupal-testing** skill.
