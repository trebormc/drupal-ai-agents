---
name: drupal-functionaljs-test
description: >-
  Generates FunctionalJavascript tests for Drupal 10/11 using WebDriverTestBase.
  Use this skill when the code under test depends on JavaScript: AJAX forms,
  entity reference autocompletes, modals, drag-and-drop, visibility toggles,
  CKEditor, complex #states. These are the slowest PHPUnit tests in Drupal,
  use them only when there is no alternative without JavaScript.
  Trigger: "javascript test", "ajax test", "autocomplete test", "modal test",
  "webdriver test", "functional javascript".
  Never use for non-JS forms (use drupal-functional-test).
  Never use for service/entity logic (use drupal-kernel-test).
  Never use for E2E flows (use drupal-behat-test or drupal-playwright-test).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal FunctionalJavascript Test

## What It Is

Extends BrowserTestBase but uses a real Chrome browser via WebDriver.
JavaScript executes completely. AJAX works. CSS animations are disabled.

Speed: 10-170 seconds per class. Use ONLY when there is no alternative.

## Critical Difference from BrowserTestBase

`statusCodeEquals()` does NOT work in WebDriverTestBase. The Selenium2 driver does
not have access to HTTP status codes. Verify access with `pageTextContains()` or
`elementExists()`.

## Base Template

```php
<?php
declare(strict_types=1);

namespace Drupal\Tests\MODULE\FunctionalJavascript;

use Drupal\FunctionalJavascriptTests\WebDriverTestBase;

/**
 * Tests DESCRIPTION.
 *
 * @group MODULE
 */
class NameTest extends WebDriverTestBase {

  protected $defaultTheme = 'stark';
  protected static $modules = ['node', 'MODULE'];

  protected function setUp(): void {
    parent::setUp();
  }

  public function testAjaxInteraction(): void {
    $this->drupalLogin($this->adminUser);
    $this->drupalGet('route');

    $page = $this->getSession()->getPage();
    $assert = $this->assertSession();

    $page->selectFieldOption('field', 'value');
    $assert->assertWaitOnAjaxRequest();

    $element = $assert->waitForElementVisible('css', '.result');
    $this->assertNotEmpty($element);
  }

}
```

## GOLDEN RULE: Never sleep(), Always Waits

The #1 cause of flaky tests. NEVER `sleep()`. ALWAYS use waits:

```php
$assert = $this->assertSession();

// Wait for AJAX (most used)
$assert->assertWaitOnAjaxRequest();

// Wait for element in DOM
$element = $assert->waitForElement('css', '.my-element');
$this->assertNotEmpty($element);

// Wait for VISIBLE element
$element = $assert->waitForElementVisible('css', '.dropdown');

// Wait for element to disappear
$assert->waitForElementRemoved('css', '.spinner');

// Specific waits
$assert->waitForButton('Submit');
$assert->waitForLink('Next');
$assert->waitForField('field_name');
$assert->waitForId('my-id');
$assert->waitForText('Done');

// Autocomplete
$assert->waitOnAutocomplete();

// Custom JS condition
$this->getSession()->wait(5000, 'jQuery("#el").is(":visible")');
```

## Pattern: Form with AJAX

```php
public function testDependentSelect(): void {
  $this->drupalLogin($this->adminUser);
  $this->drupalGet('node/add/article');

  $page = $this->getSession()->getPage();
  $assert = $this->assertSession();

  $page->selectFieldOption('field_country', 'ES');
  $assert->assertWaitOnAjaxRequest();

  $cityField = $assert->waitForElementVisible('css', '#edit-field-city');
  $this->assertNotEmpty($cityField);

  $options = $cityField->findAll('css', 'option');
  $values = array_map(fn($o) => $o->getValue(), $options);
  $this->assertContains('madrid', $values);
}
```

## Pattern: Autocomplete (Entity Reference)

```php
public function testAutocomplete(): void {
  $this->drupalCreateNode(['type' => 'article', 'title' => 'Drupal Testing Guide']);

  $this->drupalLogin($this->adminUser);
  $this->drupalGet('node/add/page');

  $page = $this->getSession()->getPage();
  $assert = $this->assertSession();

  $field = $page->findField('field_related[0][target_id]');
  $field->setValue('Drupal');
  $assert->waitOnAutocomplete();

  $suggestions = $page->findAll('css', '.ui-autocomplete li');
  $this->assertGreaterThanOrEqual(1, count($suggestions));
  $suggestions[0]->click();

  $this->assertStringContainsString('Drupal Testing Guide', $field->getValue());
}
```

## Pattern: Modal / Dialog

```php
public function testModal(): void {
  $this->drupalLogin($this->adminUser);
  $this->drupalGet('admin/structure/block');

  $page = $this->getSession()->getPage();
  $assert = $this->assertSession();

  $page->clickLink('Place block');
  $modal = $assert->waitForElementVisible('css', '.ui-dialog');
  $this->assertNotEmpty($modal);

  $modal->fillField('Filter', 'Powered by');
  $assert->waitForText('Powered by Drupal');

  $modal->pressButton('Close');
  $assert->waitForElementRemoved('css', '.ui-dialog');
}
```

## Pattern: Visibility with #states

```php
public function testConditionalVisibility(): void {
  $this->drupalLogin($this->adminUser);
  $this->drupalGet('my-module/settings');

  $page = $this->getSession()->getPage();

  $field = $page->findField('api_key');
  $this->assertFalse($field->isVisible());

  $page->checkField('enable_api');
  $this->assertTrue($field->isVisible());
}
```

## Extra Capabilities

```php
// Verify visibility (not possible in BrowserTestBase)
$this->assertFalse($element->isVisible());

// Execute JS
$this->getSession()->executeScript('document.title = "Test"');

// Evaluate JS (returns value)
$result = $this->getSession()->evaluateScript('return document.title');

// Browser drupalSettings
$settings = $this->getDrupalSettings();

// Screenshot for debug
$this->createScreenshot('/tmp/debug.png');
```

## ChromeDriver Config

Drupal 10.3+ and 11:
```xml
<env name="MINK_DRIVER_ARGS_WEBDRIVER"
     value='["chrome", {"browserName":"chrome","goog:chromeOptions":{"args":["--disable-gpu","--headless","--no-sandbox","--disable-dev-shm-usage"]}}, "http://127.0.0.1:9515"]'/>
```

In Drupal 11 `goog:chromeOptions` is mandatory (without the `goog:` prefix it does not work).

## Anti-Patterns

1. Using `sleep()`. NEVER.
2. Using `statusCodeEquals()`. DOES NOT WORK in WebDriverTestBase.
3. Not waiting after AJAX. Will pass locally and fail in CI.
4. Tests with 15+ interactions. That is an E2E flow -> Behat or Playwright.
5. Testing things that do not need JS. Use Functional test.

## Execution Command

```bash
chromedriver --port=9515 &
ssh web ./vendor/bin/phpunit -c core --testsuite functional-javascript $DDEV_DOCROOT/modules/custom/MODULE/
ssh web ./vendor/bin/phpunit -c core --testsuite functional-javascript --group MODULE
```
