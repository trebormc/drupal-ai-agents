---
name: drupal-kernel-test
description: >-
  Generates Kernel tests for Drupal 10/11 using KernelTestBase. Use this skill
  when the code interacts with container services, entities, database,
  configuration, plugins, hooks, migrations, event subscribers, or any
  Drupal API that does not require rendering HTML in a browser. This is the most
  used and recommended test type by the Drupal community for custom modules.
  Trigger: "kernel test", "service test", "entity test", "migration test",
  "plugin test", "CRUD test", "access test", or when the code uses
  the service container but does not need UI.
  Never use for HTML rendering verification (use drupal-functional-test).
  Never use for JavaScript interactions (use drupal-functionaljs-test).
  Never use for pure PHP logic without Drupal dependencies (use Unit test from drupal-testing rule).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Kernel Test

## What It Is

A Kernel test partially boots the Drupal kernel: service container,
database (SQLite by default), entity system, configuration and hooks.
There is NO web server or browser.

Speed: 1-10 seconds per test (vs 10-120s for Functional).

This is the default test for custom modules. If in doubt between Kernel and Functional,
choose Kernel. Only upgrade to Functional when you need to verify rendered HTML output.

## When to Use

- Custom services that use entity storage, database, config, or the container
- Entity CRUD (create, read, update, delete)
- Database queries (entity queries, select queries)
- Access logic and permissions (without verifying UI)
- Plugin managers with real discovery
- Event subscribers
- Hook implementations
- Token replacement
- Migrations (migrate API)
- Field types, formatters, widgets (logic, not rendering)
- Form submit/validate handlers (handler logic, not the rendered form)
- Queue workers
- Cron hooks

## When NOT to Use

- Need to verify rendered HTML -> Functional
- Need to submit forms via UI -> Functional
- Need JavaScript -> FunctionalJavascript
- Pure PHP logic without Drupal dependencies -> Unit

## Base Template

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\MODULE\Kernel;

use Drupal\KernelTests\KernelTestBase;

/**
 * Tests DESCRIPTION.
 *
 * @group MODULE
 */
class NameTest extends KernelTestBase {

  /**
   * Required modules. List dependencies BEFORE the module under test.
   * Only the strictly necessary ones -- each extra module slows things down.
   */
  protected static $modules = [
    'system',
    'user',
    // dependencies...
    'MODULE',
  ];

  protected function setUp(): void {
    parent::setUp();
    $this->installEntitySchema('user');
    $this->installConfig(['system', 'MODULE']);
  }

  public function testSomething(): void {
    $service = $this->container->get('MODULE.my_service');
    // assertions...
  }

}
```

## Setup Methods -- What to Use for What

### installEntitySchema('entity_type_id')

Installs DB tables for a content entity. Required before doing CRUD
with that entity. DO NOT use for config entities (they have no tables).

```php
$this->installEntitySchema('user');
$this->installEntitySchema('node');
$this->installEntitySchema('taxonomy_term');
```

### installConfig(['module_name'])

Imports default config (`config/install/` and `config/optional/`) from modules.
Needed when your code reads configuration.

```php
$this->installConfig(['system', 'node', 'filter', 'my_module']);
```

### installSchema('module', ['table'])

Installs tables defined in `hook_schema()`. Only for custom tables, not for entities.

```php
$this->installSchema('my_module', ['my_module_tracking']);
```

### Container Access

```php
$entityTypeManager = $this->container->get('entity_type.manager');
$configFactory = $this->container->get('config.factory');
$myService = $this->container->get('my_module.calculator');
```

## Pattern: Custom Service Test

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\my_module\Kernel\Service;

use Drupal\KernelTests\KernelTestBase;
use Drupal\node\Entity\Node;
use Drupal\node\Entity\NodeType;
use Drupal\my_module\Service\ArticleAnalyzer;

/**
 * @coversDefaultClass \Drupal\my_module\Service\ArticleAnalyzer
 * @group my_module
 */
class ArticleAnalyzerTest extends KernelTestBase {

  protected static $modules = [
    'system', 'user', 'node', 'field', 'text', 'filter', 'my_module',
  ];

  protected ArticleAnalyzer $analyzer;

  protected function setUp(): void {
    parent::setUp();
    $this->installEntitySchema('user');
    $this->installEntitySchema('node');
    $this->installConfig(['system', 'node', 'filter', 'my_module']);

    NodeType::create(['type' => 'article', 'name' => 'Article'])->save();
    $this->analyzer = $this->container->get('my_module.article_analyzer');
  }

  /**
   * @covers ::analyze
   */
  public function testAnalyzePublishedArticle(): void {
    $node = Node::create([
      'type' => 'article',
      'title' => 'Test Article',
      'status' => 1,
    ]);
    $node->save();

    $result = $this->analyzer->analyze($node);

    $this->assertSame('published', $result->getStatus());
    $this->assertGreaterThan(0, $result->getWordCount());
  }

  /**
   * @covers ::analyze
   */
  public function testAnalyzeThrowsOnInvalidBundle(): void {
    $this->expectException(\InvalidArgumentException::class);

    NodeType::create(['type' => 'page', 'name' => 'Page'])->save();
    $node = Node::create(['type' => 'page', 'title' => 'Not article']);
    $node->save();

    $this->analyzer->analyze($node);
  }

}
```

## Pattern: Entity CRUD Test

```php
public function testCreateAndLoadEntity(): void {
  $node = Node::create([
    'type' => 'article',
    'title' => 'My article',
    'status' => 0,
  ]);
  $node->save();

  // Reload from DB to verify real persistence
  $loaded = Node::load($node->id());
  $this->assertNotNull($loaded);
  $this->assertSame('My article', $loaded->getTitle());
  $this->assertFalse((bool) $loaded->isPublished());
}

public function testUpdateEntity(): void {
  $node = Node::create(['type' => 'article', 'title' => 'Original']);
  $node->save();

  $node->setTitle('Updated');
  $node->save();

  $loaded = Node::load($node->id());
  $this->assertSame('Updated', $loaded->getTitle());
}

public function testDeleteEntity(): void {
  $node = Node::create(['type' => 'article', 'title' => 'To delete']);
  $node->save();
  $nid = $node->id();

  $node->delete();
  $this->assertNull(Node::load($nid));
}
```

## Pattern: Access and Permissions Test

```php
use Drupal\user\Entity\User;
use Drupal\user\Entity\Role;

public function testAccessCheck(): void {
  $user_without_permission = User::create(['name' => 'no_access', 'status' => 1]);
  $user_without_permission->save();

  $role = Role::create([
    'id' => 'my_role',
    'label' => 'My Role',
  ]);
  $role->grantPermission('access my_module reports');
  $role->save();

  $user_with_permission = User::create(['name' => 'with_access', 'status' => 1]);
  $user_with_permission->addRole('my_role');
  $user_with_permission->save();

  $checker = $this->container->get('my_module.access_checker');
  $this->assertFalse($checker->canViewReports($user_without_permission));
  $this->assertTrue($checker->canViewReports($user_with_permission));
}
```

## Pattern: Configuration Test

```php
public function testDefaultConfig(): void {
  $config = $this->config('my_module.settings');
  $this->assertSame(10, $config->get('max_items'));
  $this->assertTrue($config->get('cache_enabled'));
}

public function testConfigChange(): void {
  $config = $this->config('my_module.settings');
  $config->set('max_items', 50)->save();

  $service = $this->container->get('my_module.listing');
  $this->assertSame(50, $service->getMaxItems());
}
```

## Pattern: Event Subscriber Test

```php
public function testEventSubscriber(): void {
  $node = Node::create(['type' => 'article', 'title' => 'Test', 'status' => 1]);
  $node->save();

  $event = new ArticlePublishedEvent($node);
  $dispatcher = $this->container->get('event_dispatcher');
  $dispatcher->dispatch($event, ArticlePublishedEvent::EVENT_NAME);

  $this->assertTrue($event->wasProcessed());
}
```

## Pattern: Auxiliary Test Module

When you need routes, services, or config that only exist for the test:

```yaml
# tests/modules/my_module_test/my_module_test.info.yml
name: 'My Module Test'
type: module
core_version_requirement: ^10 || ^11
package: Testing
dependencies:
  - my_module:my_module
hidden: true
```

In the test:
```php
protected static $modules = ['my_module', 'my_module_test'];
```

## Useful Core Traits

```php
use Drupal\Tests\node\Traits\NodeCreationTrait;
use Drupal\Tests\user\Traits\UserCreationTrait;
use Drupal\Tests\node\Traits\ContentTypeCreationTrait;
use Drupal\Tests\Traits\Core\CronRunTrait;

class MyTest extends KernelTestBase {
  use NodeCreationTrait;
  use UserCreationTrait;
  use ContentTypeCreationTrait;
  use CronRunTrait;
}
```

## Anti-Patterns

1. Do not install unnecessary modules in `$modules`. Each one adds time.
2. Do not use `installEntitySchema()` for config entities. They have no tables.
3. Do not use `enableModules()` in setUp(). Use the `$modules` property.
4. Do not make assertions about rendered HTML. That is a Functional test.
5. Do not create unnecessary fixtures. Only what the test needs.
6. Do not forget to reload entities. After modifying, use `Entity::load($id)` to verify persisted state.

## Execution Command

```bash
export SIMPLETEST_DB="sqlite://localhost/:memory:"
ssh web ./vendor/bin/phpunit -c core --testsuite kernel $DDEV_DOCROOT/modules/custom/MODULE/
ssh web ./vendor/bin/phpunit -c core --filter testName $DDEV_DOCROOT/modules/custom/MODULE/tests/src/Kernel/
ssh web ./vendor/bin/phpunit -c core --group MODULE --testsuite kernel
```
