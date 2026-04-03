---
name: drupal-testing
description: >-
  Create and run PHPUnit tests for Drupal: unit, kernel, functional tests.
  Generate test files with proper PHPDoc annotations (not PHP 8 attributes)
  for Drupal 10+11 compatibility. Run test suites, check coverage, and
  validate code quality. Use when writing tests, improving coverage,
  running test suites, or setting up QA automation.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Testing

## PHPUnit Annotation Style (CRITICAL — Drupal 10+11 Compatibility)

**ALWAYS use PHPDoc annotations** — NEVER PHP 8 attributes for test metadata.
Drupal 10 uses PHPUnit 9.x (no attribute support). PHPDoc works in both Drupal 10 and 11.

| Use THIS (PHPDoc) | NOT this (PHP 8 attribute) |
|---|---|
| `@coversDefaultClass \My\Class` | `#[CoversClass(MyClass::class)]` |
| `@covers ::methodName` | `#[Covers('methodName')]` |
| `@group mymodule` | `#[Group('mymodule')]` |
| `@dataProvider providerName` | `#[DataProvider('providerName')]` |

## Test Type Selection

| Test Type | Use For | Speed | Database |
|-----------|---------|-------|----------|
| Unit | Pure PHP logic, no Drupal bootstrap | ~0.01s | No |
| Kernel | Services, entities, queries | ~0.5s | Yes |
| Functional | HTTP requests, forms, pages | ~2-5s | Yes |
| FunctionalJS | JavaScript interactions | ~10s+ | Yes |

**Rule: Use the FASTEST test type that covers the requirement.**

## Test Execution Commands

```bash
# Run all tests for a module
docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule

# Run single file
docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule/tests/src/Unit/MyServiceTest.php

# Run single method
docker exec $WEB_CONTAINER ./vendor/bin/phpunit --filter testMyMethod $DDEV_DOCROOT/modules/custom/mymodule

# Run with coverage
docker exec $WEB_CONTAINER ./vendor/bin/phpunit --coverage-html /var/www/html/coverage $DDEV_DOCROOT/modules/custom/mymodule
```

## Test Directory Structure

```
$DDEV_DOCROOT/modules/custom/mymodule/
└── tests/
    └── src/
        ├── Unit/
        │   └── Service/
        │       └── MyServiceTest.php
        ├── Kernel/
        │   └── Entity/
        │       └── MyEntityTest.php
        └── Functional/
            └── Form/
                └── MyFormTest.php
```

## Unit Test Template

```php
<?php

declare(strict_types=1);

namespace Drupal\Tests\mymodule\Unit\Service;

use Drupal\mymodule\Service\MyService;
use Drupal\Tests\UnitTestCase;

/**
 * Tests the MyService class.
 *
 * @coversDefaultClass \Drupal\mymodule\Service\MyService
 * @group mymodule
 */
final class MyServiceTest extends UnitTestCase {

  protected MyService $service;

  protected function setUp(): void {
    parent::setUp();
    $this->service = new MyService();
  }

  /**
   * @covers ::process
   */
  public function testValidInputReturnsExpected(): void {
    $result = $this->service->process('valid');
    $this->assertSame('expected', $result);
  }

  /**
   * @covers ::process
   * @dataProvider invalidInputProvider
   */
  public function testInvalidInputThrowsException(mixed $input): void {
    $this->expectException(\InvalidArgumentException::class);
    $this->service->process($input);
  }

  public static function invalidInputProvider(): array {
    return [
      'empty string' => [''],
      'null' => [NULL],
      'array' => [[]],
    ];
  }

}
```

## Kernel Test Template

```php
<?php

declare(strict_types=1);

namespace Drupal\Tests\mymodule\Kernel\Entity;

use Drupal\KernelTests\KernelTestBase;
use Drupal\mymodule\Entity\MyEntity;

/**
 * @coversDefaultClass \Drupal\mymodule\Entity\MyEntity
 * @group mymodule
 */
final class MyEntityTest extends KernelTestBase {

  protected static $modules = ['system', 'user', 'mymodule'];

  protected function setUp(): void {
    parent::setUp();
    $this->installEntitySchema('user');
    $this->installEntitySchema('my_entity');
    $this->installConfig(['mymodule']);
  }

  public function testEntityCreation(): void {
    $entity = MyEntity::create(['name' => 'Test', 'status' => TRUE]);
    $entity->save();
    $this->assertNotNull($entity->id());
  }

}
```

## Functional Test Template

```php
<?php

declare(strict_types=1);

namespace Drupal\Tests\mymodule\Functional\Form;

use Drupal\Tests\BrowserTestBase;

/**
 * @group mymodule
 */
final class MyFormTest extends BrowserTestBase {

  protected static $modules = ['mymodule'];
  protected $defaultTheme = 'stark';

  public function testFormSubmission(): void {
    $user = $this->drupalCreateUser(['access mymodule']);
    $this->drupalLogin($user);
    $this->drupalGet('/mymodule/form');
    $this->assertSession()->statusCodeEquals(200);
    $this->submitForm(['name' => 'Test Value'], 'Submit');
    $this->assertSession()->pageTextContains('Saved successfully');
  }

  public function testAccessDeniedForAnonymous(): void {
    $this->drupalGet('/mymodule/form');
    $this->assertSession()->statusCodeEquals(403);
  }

}
```

## Test Development Workflow

1. **Create test file** in the appropriate directory
2. **Write failing test first** (TDD approach)
3. **Run test** to confirm failure
4. **Implement the feature**
5. **Run test again** to confirm pass
6. **Run full suite** to check regressions
7. **Run quality checks** (PHPCS, PHPStan)

## Common Testing Pitfalls

1. **Testing implementation instead of behavior** — Assert on results, not internal method calls
2. **Over-mocking** — Only mock external dependencies. If you need 4+ mocks, refactor
3. **Shared state between tests** — Never use static properties to share data
4. **Wrong test type** — Don't use BrowserTestBase for pure PHP logic
5. **Flaky time-dependent tests** — Never use `sleep()`. Inject time as dependency

## Test Checklist

- [ ] Happy path covered
- [ ] Edge cases: empty, null, max values
- [ ] Error conditions throw appropriate exceptions
- [ ] Access control tested (permissions)
- [ ] Each test method tests ONE thing
- [ ] Tests are isolated (no shared state)
- [ ] Test names describe what they test

## Reference Skills

- **drupal-unit-test** — mock templates, service mocking patterns, data providers
- **quality-tools-setup** rule — PHPUnit, PHPCS, PHPStan configuration files
- **drupal-debugging** — test debugging and troubleshooting commands
