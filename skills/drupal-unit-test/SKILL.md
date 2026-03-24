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
