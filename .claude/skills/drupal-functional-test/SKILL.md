---
name: drupal-functional-test
description: >-
  Generates Functional tests for Drupal 10/11 using BrowserTestBase. Use this skill
  when you need to verify rendered forms, form submission via UI, permissions and
  access via HTTP, HTML output of pages, admin forms, node creation/editing via
  the interface, redirects, or anything requiring a full HTTP response but NOT JavaScript.
  Trigger: "functional test", "form test", "permissions test", "page test",
  "admin form test", "node creation test", "browser test".
  Never use for logic testable with Kernel test (use drupal-kernel-test).
  Never use for JavaScript interactions (use drupal-functionaljs-test).
  Never use for pure PHP logic (use Unit test from drupal-testing rule).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Functional Test

## What It Is

Installs a complete Drupal site and simulates HTTP requests with Mink + BrowserKit.
It is NOT a real browser. JavaScript does NOT execute.

Speed: 4-120 seconds per class (installs Drupal from scratch per class).

## When to Use

- Module configuration forms (admin forms)
- Content creation/editing/deletion via UI
- Verify permissions: without permission -> 403, with permission -> 200
- Verify HTML output of pages
- Verify that blocks appear where they should
- Test redirects and routes
- Verify status/error messages

## When NOT to Use

- If you can test the same logic with Kernel test -> use Kernel (10x faster)
- If you need JavaScript/AJAX -> FunctionalJavascript
- If it is pure PHP logic -> Unit test

## Required Properties

```php
protected $defaultTheme = 'stark';       // REQUIRED. Use 'stark' for speed.
protected static $modules = ['my_module']; // Required modules.
// protected $profile = 'testing';        // Default. Only use 'standard' if you need its config.
```

## Base Template

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\MODULE\Functional;

use Drupal\Tests\BrowserTestBase;

/**
 * Tests DESCRIPTION.
 *
 * @group MODULE
 */
class NameTest extends BrowserTestBase {

  protected $defaultTheme = 'stark';
  protected static $modules = ['node', 'block', 'MODULE'];

  protected function setUp(): void {
    parent::setUp();
    $this->drupalCreateContentType(['type' => 'article', 'name' => 'Article']);
    $this->adminUser = $this->drupalCreateUser(['administer MODULE']);
  }

  public function testSomething(): void {
    $this->drupalLogin($this->adminUser);
    $this->drupalGet('admin/config/MODULE/settings');
    $this->assertSession()->statusCodeEquals(200);
  }

}
```

## Pattern: Configuration Form Test

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\my_module\Functional;

use Drupal\Tests\BrowserTestBase;

/**
 * @group my_module
 */
class SettingsFormTest extends BrowserTestBase {

  protected $defaultTheme = 'stark';
  protected static $modules = ['my_module'];

  protected function setUp(): void {
    parent::setUp();
    $this->adminUser = $this->drupalCreateUser(['administer my_module']);
  }

  public function testFormSavesValues(): void {
    $this->drupalLogin($this->adminUser);
    $this->drupalGet('admin/config/my-module/settings');

    $assert = $this->assertSession();
    $assert->statusCodeEquals(200);
    $assert->fieldExists('max_items');

    $this->submitForm([
      'max_items' => '25',
      'cache_enabled' => TRUE,
    ], 'Save configuration');

    $assert->statusMessageContains('The configuration options have been saved', 'status');

    $config = $this->config('my_module.settings');
    $this->assertSame(25, $config->get('max_items'));
    $this->assertTrue($config->get('cache_enabled'));

    // Verify the form displays saved values
    $this->drupalGet('admin/config/my-module/settings');
    $assert->fieldValueEquals('max_items', '25');
    $assert->checkboxChecked('edit-cache-enabled');
  }

  public function testFormValidation(): void {
    $this->drupalLogin($this->adminUser);
    $this->drupalGet('admin/config/my-module/settings');

    $this->submitForm(['max_items' => '-5'], 'Save configuration');

    $this->assertSession()->statusMessageExists('error');
  }

  public function testFormRequiresPermission(): void {
    $user = $this->drupalCreateUser(['access content']);
    $this->drupalLogin($user);
    $this->drupalGet('admin/config/my-module/settings');
    $this->assertSession()->statusCodeEquals(403);
  }

}
```

## Pattern: Node Creation and Editing Test

```php
/**
 * @group my_module
 */
class ArticleFormTest extends BrowserTestBase {

  protected $defaultTheme = 'stark';
  protected static $modules = ['node', 'field', 'text', 'filter', 'my_module'];

  protected function setUp(): void {
    parent::setUp();
    $this->drupalCreateContentType(['type' => 'article', 'name' => 'Article']);
    $this->author = $this->drupalCreateUser([
      'access content',
      'create article content',
      'edit own article content',
      'delete own article content',
    ]);
  }

  public function testCreateArticle(): void {
    $this->drupalLogin($this->author);
    $this->drupalGet('node/add/article');
    $this->assertSession()->statusCodeEquals(200);

    $this->submitForm([
      'title[0][value]' => 'Test Article',
      'body[0][value]' => 'Body content.',
    ], 'Save');

    $assert = $this->assertSession();
    $assert->statusMessageContains('has been created', 'status');
    $assert->pageTextContains('Test Article');

    $node = $this->drupalGetNodeByTitle('Test Article');
    $this->assertNotNull($node);
    $this->assertSame('article', $node->bundle());
  }

  public function testEditArticle(): void {
    $this->drupalLogin($this->author);
    $node = $this->drupalCreateNode([
      'type' => 'article',
      'title' => 'Original',
      'uid' => $this->author->id(),
    ]);

    $this->drupalGet('node/' . $node->id() . '/edit');
    $this->assertSession()->fieldValueEquals('title[0][value]', 'Original');

    $this->submitForm(['title[0][value]' => 'Updated'], 'Save');
    $this->assertSession()->statusMessageContains('has been updated', 'status');
  }

  public function testDeleteArticle(): void {
    $this->drupalLogin($this->author);
    $node = $this->drupalCreateNode([
      'type' => 'article',
      'title' => 'To Delete',
      'uid' => $this->author->id(),
    ]);

    $this->drupalGet('node/' . $node->id() . '/delete');
    $this->submitForm([], 'Delete');
    $this->assertSession()->statusMessageContains('has been deleted', 'status');
  }

  public function testOtherUserCannotEdit(): void {
    $other = $this->drupalCreateUser(['access content', 'edit own article content']);
    $node = $this->drupalCreateNode([
      'type' => 'article',
      'uid' => $this->author->id(),
    ]);

    $this->drupalLogin($other);
    $this->drupalGet('node/' . $node->id() . '/edit');
    $this->assertSession()->statusCodeEquals(403);
  }

}
```

## Pattern: Page Output and Blocks Test

```php
public function testBlockAppears(): void {
  $this->drupalLogin($this->adminUser);
  $this->drupalPlaceBlock('my_module_stats_block', [
    'region' => 'content',
    'label' => 'Stats',
    'label_display' => TRUE,
  ]);

  $this->drupalGet('<front>');
  $assert = $this->assertSession();
  $assert->pageTextContains('Stats');
  $assert->elementExists('css', '.block-my-module-stats-block');
}
```

## Assertion Reference -- $this->assertSession()

```php
$assert = $this->assertSession();

// HTTP status
$assert->statusCodeEquals(200);

// Visible text (no HTML)
$assert->pageTextContains('Welcome');
$assert->pageTextNotContains('Access denied');

// Raw HTML
$assert->responseContains('<div class="my-class">');

// Form fields
$assert->fieldExists('title[0][value]');
$assert->fieldValueEquals('title[0][value]', 'Expected');
$assert->checkboxChecked('edit-status-value');

// CSS elements
$assert->elementExists('css', '.my-class');
$assert->elementNotExists('css', '.should-not-exist');
$assert->elementTextContains('css', 'h1', 'Title');
$assert->elementsCount('css', '.item', 5);

// Links and buttons
$assert->linkExists('Log out');
$assert->linkByHrefExists('/node/add');
$assert->buttonExists('Save');

// Status messages (Drupal 9.3+)
$assert->statusMessageContains('has been created', 'status');
$assert->statusMessageExists('error');
$assert->statusMessageNotExists('error');

// URL
$assert->addressEquals('node/1');
```

## Navigation Methods

```php
$this->drupalGet('admin/config');
$this->drupalLogin($account);
$this->drupalLogout();
$this->submitForm(['field' => 'value'], 'Save');
$this->clickLink('Edit');
$node = $this->drupalCreateNode(['type' => 'article', 'title' => 'Test']);
$node = $this->drupalGetNodeByTitle('Test');
```

## Anti-Patterns

1. Do not use `drupalPostForm()` -- it is deprecated. Use `submitForm()`.
2. Do not verify business logic with Functional tests if a Kernel test works.
3. Do not forget `$defaultTheme`. Without it the test fails.
4. Do not depend on theme markup. Search by text or classes you control.
5. Do not use `assertSession()->statusCodeEquals()` if you will later migrate to FunctionalJS (it does not support it).

## Execution Command

```bash
ssh web ./vendor/bin/phpunit -c core --testsuite functional $DDEV_DOCROOT/modules/custom/MODULE/
ssh web ./vendor/bin/phpunit -c core --filter testFormSavesValues
ssh web ./vendor/bin/phpunit -c core --testsuite functional --group MODULE
```
