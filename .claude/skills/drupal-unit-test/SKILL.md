---
name: drupal-unit-test
description: >-
  Generates PHPUnit unit tests for Drupal 10/11 custom modules following
  community best practices. Covers services, plugins, forms, controllers,
  and event subscribers with proper mocking patterns. Uses PHPDoc annotations
  (not PHP 8 attributes) for Drupal 10+11 compatibility.
  Examples:
  - user: "write unit tests for my module" -> generate unit test classes
  - user: "generate unit tests" -> create PHPUnit unit tests
  - user: "add tests for MyService" -> write unit test for specific class
  - user: "test coverage for my module" -> identify gaps and generate tests
  Never use for kernel tests, functional tests, or browser tests.
---

## Environment

All commands via `docker exec $WEB_CONTAINER`. Use `$DDEV_DOCROOT` for paths.
Detect test gaps: `docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpunit --filter="module:MODULE" --format=json`

## Drupal 10+11 Compatibility (CRITICAL)

Use **PHPDoc annotations only** — NEVER PHP 8 attributes. Drupal 10 = PHPUnit 9.x (no attribute support).

| Use THIS | NOT this |
|---|---|
| `@coversDefaultClass \My\Class` | `#[CoversClass(MyClass::class)]` |
| `@covers ::methodName` | `#[Covers('methodName')]` |
| `@group mymodule` | `#[Group('mymodule')]` |
| `@dataProvider providerName` | `#[DataProvider('providerName')]` |

## Workflow

1. Read source class in `src/`
2. Check existing tests in `tests/src/Unit/`
3. Generate test class following templates below
4. Run test: `docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit/Service/MyServiceTest.php`
5. Run PHPCS — **always try Audit module first**:
   ```bash
   # Preferred: Audit module (check if installed first)
   docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --filter="module:MODULE" --format=json
   # Fallback only if Audit module not installed:
   docker exec $WEB_CONTAINER ./vendor/bin/phpcs --standard=Drupal,DrupalPractice $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit/
   ```

## File Structure & Namespace

```
$DDEV_DOCROOT/modules/custom/MODULE/tests/src/Unit/
├── Service/MyServiceTest.php        # Drupal\Tests\MODULE\Unit\Service
├── Plugin/Block/MyBlockTest.php     # Drupal\Tests\MODULE\Unit\Plugin\Block
├── Form/MyFormTest.php              # Drupal\Tests\MODULE\Unit\Form
└── Controller/MyControllerTest.php  # Drupal\Tests\MODULE\Unit\Controller
```

## Template: Service Test (Complete Example)

```php
<?php

declare(strict_types=1);

namespace Drupal\Tests\mymodule\Unit\Service;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Config\ImmutableConfig;
use Drupal\mymodule\Service\MyService;
use Drupal\Tests\UnitTestCase;

/**
 * Tests the MyService class.
 *
 * @coversDefaultClass \Drupal\mymodule\Service\MyService
 * @group mymodule
 */
class MyServiceTest extends UnitTestCase {

  protected MyService $service;
  protected ConfigFactoryInterface $configFactory;

  /**
   * {@inheritdoc}
   */
  protected function setUp(): void {
    parent::setUp();
    $this->configFactory = $this->createMock(ConfigFactoryInterface::class);
    $this->service = new MyService($this->configFactory);
  }

  /**
   * @covers ::process
   */
  public function testProcessValidInput(): void {
    $config = $this->createMock(ImmutableConfig::class);
    $config->method('get')->willReturn('value');
    $this->configFactory->method('get')->willReturn($config);
    $result = $this->service->process('test');
    $this->assertIsArray($result);
    $this->assertNotEmpty($result);
  }

  /**
   * @covers ::process
   * @dataProvider processDataProvider
   */
  public function testProcessScenarios(string $input, bool $expectEmpty): void {
    $config = $this->createMock(ImmutableConfig::class);
    $config->method('get')->willReturn('default');
    $this->configFactory->method('get')->willReturn($config);
    $result = $this->service->process($input);
    $this->assertEquals($expectEmpty, empty($result));
  }

  /**
   * @return array
   *   Test scenarios.
   */
  public static function processDataProvider(): array {
    return [
      'valid input' => ['valid', FALSE],
      'another case' => ['other', FALSE],
    ];
  }

}
```

## Template: Plugin setUp (Reflection for DI)

```php
protected function setUp(): void {
  parent::setUp();
  $this->block = new MyBlock([], 'my_block', ['id' => 'my_block', 'provider' => 'mymodule']);
  // Inject mock via reflection (ONLY for DI, never for testing logic).
  $this->entityTypeManager = $this->createMock(EntityTypeManagerInterface::class);
  $ref = new \ReflectionClass($this->block);
  $prop = $ref->getProperty('entityTypeManager');
  $prop->setAccessible(TRUE);
  $prop->setValue($this->block, $this->entityTypeManager);
}
```

## Template: Form Test Methods

```php
/** @covers ::buildForm */
public function testBuildFormStructure(): void {
  $result = $this->form->buildForm([], new FormState());
  $this->assertIsArray($result);
  $this->assertArrayHasKey('actions', $result);
}

/** @covers ::validateForm */
public function testValidateFormInvalidData(): void {
  $form = [];
  $form_state = new FormState();
  $form_state->setValues(['name' => '']);
  $this->form->validateForm($form, $form_state);
  $this->assertTrue($form_state->hasAnyErrors());
}
```

## Common Mock Patterns

```php
// Config Factory
$config = $this->createMock(ImmutableConfig::class);
$config->method('get')->willReturnCallback(fn(string $key) => $values[$key] ?? NULL);
$this->configFactory->method('get')->willReturn($config);

// Entity Query (always include accessCheck)
$query = $this->createMock(QueryInterface::class);
$query->method('accessCheck')->willReturnSelf();
$query->method('condition')->willReturnSelf();
$query->method('execute')->willReturn(['id1', 'id2']);
$storage = $this->createMock(EntityStorageInterface::class);
$storage->method('getQuery')->willReturn($query);
$this->entityTypeManager->method('getStorage')->willReturn($storage);

// Logger with assertion
$this->logger = $this->createMock(LoggerInterface::class);
$this->logger->expects($this->once())->method('error')
  ->with($this->stringContains('failed'));

// String translation — already available from UnitTestCase:
// $this->getStringTranslationStub()
```

## Advanced Mock: EntityTypeManager Chain

```php
// Full EntityTypeManager → Storage → Entity mock chain
$entity = $this->createMock(EntityInterface::class);
$entity->method('id')->willReturn('1');
$entity->method('label')->willReturn('Test');

$storage = $this->createMock(EntityStorageInterface::class);
$storage->expects($this->once())
  ->method('load')
  ->with(1)
  ->willReturn($entity);
$storage->method('loadMultiple')
  ->willReturn(['1' => $entity]);

$entityTypeManager = $this->createMock(EntityTypeManagerInterface::class);
$entityTypeManager->expects($this->once())
  ->method('getStorage')
  ->with('node')
  ->willReturn($storage);

$service = new MyService($entityTypeManager);
$result = $service->loadEntity(1);
$this->assertNotNull($result);
```

## PHPUnit Configuration (phpunit.xml)

Adapt `web/` paths to match `$DDEV_DOCROOT` if different:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/10.5/phpunit.xsd"
         bootstrap="web/core/tests/bootstrap.php"
         colors="true">
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
  <php>
    <env name="SIMPLETEST_BASE_URL" value=""/>
    <env name="SIMPLETEST_DB" value="mysql://db:db@db/db"/>
    <env name="BROWSERTEST_OUTPUT_DIRECTORY" value="/var/www/html/sites/simpletest/browser_output"/>
  </php>
</phpunit>
```

For PHPCS, PHPStan, Rector, and GrumPHP configuration, see the **quality-tools-setup** rule.

## Common Testing Pitfalls

1. **Testing implementation, not behavior** — Assert on results (WHAT), not internal calls (HOW). Don't `expects($this->exactly(N))` on internal helpers.
2. **Over-mocking** — Only mock external deps (DB, HTTP, filesystem). 4+ mocks = code needs refactoring. Use real value objects.
3. **Shared state** — Never use `static` props between tests. Use `setUp()` for fresh state each test.
4. **Wrong test type** — Don't use `BrowserTestBase` for pure logic. Use `UnitTestCase` when no Drupal bootstrap needed.
5. **Time-dependent tests** — Never `sleep()`. Inject time as dependency, test with controlled timestamps.

## Test Debugging Commands

```bash
# Run single test with verbose output
docker exec $WEB_CONTAINER ./vendor/bin/phpunit --filter testMethodName path/to/Test.php -v

# Run tests with debug info
docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule --debug

# List all tests without running
docker exec $WEB_CONTAINER ./vendor/bin/phpunit --list-tests $DDEV_DOCROOT/modules/custom/mymodule

# Run with testdox output
docker exec $WEB_CONTAINER ./vendor/bin/phpunit --testdox $DDEV_DOCROOT/modules/custom/mymodule
```

## Related Skills

- **drupal-testing** — Full test lifecycle: kernel tests, functional tests, test execution, coverage (use for non-unit test types)
- **quality-checks** — Code quality validation after writing tests
- **drupal-debugging** — Test debugging commands and troubleshooting

## Rules

1. Base class: `Drupal\Tests\UnitTestCase` (never `PHPUnit\Framework\TestCase`)
2. PHPDoc annotations only — no PHP 8 attributes
3. `declare(strict_types=1)` first line after `<?php`
4. All dependencies mocked — no DB, filesystem, or HTTP
5. No `\Drupal::service()` in tests — DI via constructor or reflection
6. No `sleep()` — use controlled time objects
7. 2-space indentation (Drupal standard)
8. Test public API only — reflection only for injecting mock dependencies
9. One assertion concept per test method
10. Descriptive names: `testProcessReturnsEmptyArrayWhenNoData`
