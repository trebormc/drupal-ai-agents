---
name: drupal-behat-test
description: >-
  Generates Behat tests for Drupal 10/11 using the Drupal Extension for Behat.
  Use this skill when the project already has Behat configured (look for behat.yml),
  when acceptance tests written in natural language (Gherkin) are needed,
  E2E flows, or when the client needs to read and validate test scenarios.
  Trigger: "behat test", "acceptance test", "feature file", "gherkin",
  "behat scenario", "bdd test", "behavior test", or when behat.yml exists
  in the project.
  Never use for service/entity logic (use drupal-kernel-test).
  Never use for simple form testing (use drupal-functional-test).
  Never use for visual regression (use drupal-playwright-test).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Behat Test

## What It Is

Behat is a BDD (Behavior-Driven Development) framework that uses natural language
(Gherkin) to define test scenarios. The Drupal Extension provides predefined
steps for interacting with Drupal: create users, nodes, terms,
navigate, fill forms, etc.

## When to Use

- The project already uses Behat (has `behat.yml`)
- Acceptance tests that the client can read are needed
- Complete E2E flows (registration, purchase, content publishing)
- Behavior tests in natural language
- When the QA team does not know PHP but needs to write/read tests

## When NOT to Use

- Tests for services or internal logic -> Kernel test
- Simple form tests -> Functional test
- If the project does not have Behat and there is no reason to add it -> Playwright
- Visual regression -> Playwright

## Setup -- Dependencies

```bash
ssh web composer require --dev drupal/drupal-extension behat/mink-selenium2-driver
```

For Drupal 10/11, use `drupal/drupal-extension:^5`.

## Configuration -- behat.yml

```yaml
default:
  suites:
    default:
      contexts:
        - Drupal\DrupalExtension\Context\DrupalContext
        - Drupal\DrupalExtension\Context\MinkContext
        - Drupal\DrupalExtension\Context\MessageContext
        - Drupal\DrupalExtension\Context\DrushContext
        - FeatureContext
  extensions:
    Drupal\MinkExtension:
      goutte: ~
      selenium2:
        wd_host: 'http://127.0.0.1:4444/wd/hub'
        capabilities:
          browser: chrome
          extra_capabilities:
            goog:chromeOptions:
              args:
                - '--disable-gpu'
                - '--headless'
                - '--no-sandbox'
      base_url: 'http://localhost'
      ajax_timeout: 10
    Drupal\DrupalExtension:
      api_driver: 'drupal'
      drupal:
        drupal_root: 'web'
      region_map:
        content: '.region-content'
        header: '.region-header'
        sidebar_first: '.region-sidebar-first'
      selectors:
        message_selector: '.messages'
        error_message_selector: '.messages--error'
        success_message_selector: '.messages--status'
        warning_message_selector: '.messages--warning'
```

## Directory Structure

```
tests/behat/
├── behat.yml
├── features/
│   ├── article.feature
│   ├── login.feature
│   ├── admin_config.feature
│   └── bootstrap/
│       └── FeatureContext.php
└── screenshots/                <- Failure screenshots (if configured)
```

## Pattern: Content Creation Feature

```gherkin
# features/article.feature
@api @content
Feature: Article content management
  As a content editor
  I need to create and manage articles
  So that I can publish content on the website

  Background:
    Given I am logged in as a user with the "content_editor" role

  Scenario: Create a new article
    Given I am on "node/add/article"
    When I fill in "Title" with "My Test Article"
    And I fill in "Body" with "This is the article body."
    And I press "Save"
    Then I should see the success message containing "has been created"
    And I should see "My Test Article"

  Scenario: Edit an existing article
    Given "article" content:
      | title          | body           | status |
      | Existing Post  | Original body  | 1      |
    When I am on the edit page of "article" content "Existing Post"
    And I fill in "Title" with "Updated Post"
    And I press "Save"
    Then I should see the success message containing "has been updated"
    And I should see "Updated Post"

  Scenario: Delete an article
    Given "article" content:
      | title        | status |
      | To Be Deleted | 1     |
    When I am on the delete page of "article" content "To Be Deleted"
    And I press "Delete"
    Then I should see the success message containing "has been deleted"

  Scenario: Anonymous user cannot create articles
    Given I am an anonymous user
    When I go to "node/add/article"
    Then I should get a "403" HTTP response
```

## Pattern: Login and Permissions Feature

```gherkin
# features/login.feature
@api @auth
Feature: User authentication
  As a site visitor
  I need to log in to access restricted content
  So that I can manage my account and content

  Scenario: Successful login
    Given users:
      | name     | mail              | status | pass     |
      | testuser | test@example.com  | 1      | testpass |
    When I am on "/user/login"
    And I fill in "Username" with "testuser"
    And I fill in "Password" with "testpass"
    And I press "Log in"
    Then I should see "testuser"
    And I should see the link "Log out"

  Scenario: Failed login with wrong password
    When I am on "/user/login"
    And I fill in "Username" with "testuser"
    And I fill in "Password" with "wrongpassword"
    And I press "Log in"
    Then I should see the error message "Unrecognized username or password"

  Scenario: Admin can access administration
    Given I am logged in as a user with the "administrator" role
    When I go to "admin"
    Then I should get a "200" HTTP response
    And I should see "Administration"

  Scenario: Authenticated user cannot access admin
    Given I am logged in as a user with the "authenticated" role
    When I go to "admin"
    Then I should get a "403" HTTP response
```

## Pattern: Configuration Feature

```gherkin
# features/admin_config.feature
@api @config
Feature: Module configuration
  As an administrator
  I need to configure my_module settings
  So that the module works as expected

  Background:
    Given I am logged in as a user with the "administrator" role

  Scenario: Save configuration
    When I am on "admin/config/my-module/settings"
    And I fill in "Maximum items" with "25"
    And I check "Enable cache"
    And I press "Save configuration"
    Then I should see the success message "The configuration options have been saved"

  Scenario: Configuration validates input
    When I am on "admin/config/my-module/settings"
    And I fill in "Maximum items" with "-5"
    And I press "Save configuration"
    Then I should see an error message

  Scenario: Non-admin cannot access settings
    Given I am logged in as a user with the "authenticated" role
    When I go to "admin/config/my-module/settings"
    Then I should get a "403" HTTP response
```

## Pattern: Feature with JavaScript (Selenium)

```gherkin
# features/ajax_form.feature
@api @javascript
Feature: AJAX form interactions
  As a content editor
  I need the dependent fields to update dynamically
  So that I can select the correct subcategory

  Background:
    Given I am logged in as a user with the "content_editor" role

  @javascript
  Scenario: Selecting country loads cities
    Given I am on "node/add/article"
    When I select "Spain" from "Country"
    And I wait for AJAX to finish
    Then I should see "Madrid" in the "City" select
    And I should see "Barcelona" in the "City" select
```

The `@javascript` tag makes Behat use Selenium instead of Goutte/BrowserKit.

## Predefined Steps by Drupal Extension

### Content Creation
```gherkin
Given "article" content:
  | title       | body          | status | field_tags |
  | My Article  | Body text     | 1      | Tag1, Tag2 |

Given I am viewing an "article" content with the title "My Article"
```

### Users and Roles
```gherkin
Given users:
  | name  | mail           | roles         |
  | admin | admin@test.com | administrator |

Given I am logged in as a user with the "editor" role
Given I am logged in as "admin"
Given I am an anonymous user
```

### Taxonomy
```gherkin
Given "tags" terms:
  | name     |
  | Tag One  |
  | Tag Two  |
```

### Navigation
```gherkin
When I visit "node/add/article"
When I go to "admin/config"
When I click "Edit"
When I follow "Log out"
```

### Forms
```gherkin
When I fill in "Title" with "My Title"
When I fill in "edit-body-0-value" with "Body text"
When I select "Published" from "Status"
When I check "Promoted to front page"
When I uncheck "Sticky"
When I press "Save"
```

### Assertions
```gherkin
Then I should see "Expected text"
Then I should not see "Unexpected text"
Then I should see the link "My Link"
Then I should get a "200" HTTP response
Then I should see the success message "Created"
Then I should see the error message "Required"
Then I should see the heading "Page Title"
Then the "Title" field should contain "My Value"
```

## FeatureContext -- Custom Steps

```php
<?php
// tests/behat/features/bootstrap/FeatureContext.php

use Drupal\DrupalExtension\Context\RawDrupalContext;
use Behat\Behat\Context\SnippetAcceptingContext;

class FeatureContext extends RawDrupalContext implements SnippetAcceptingContext {

  /**
   * @Then I should see :count articles in the listing
   */
  public function iShouldSeeArticlesInListing(int $count): void {
    $page = $this->getSession()->getPage();
    $articles = $page->findAll('css', '.node--type-article');
    if (count($articles) !== $count) {
      throw new \Exception(
        sprintf('Expected %d articles, found %d', $count, count($articles))
      );
    }
  }

  /**
   * @When I wait for AJAX to finish
   */
  public function iWaitForAjaxToFinish(): void {
    $this->getSession()->wait(5000, '(typeof jQuery === "undefined" || jQuery.active === 0)');
  }

  /**
   * @Given I am on the edit page of :type content :title
   */
  public function iAmOnEditPageOfContent(string $type, string $title): void {
    $node = \Drupal::entityTypeManager()
      ->getStorage('node')
      ->loadByProperties(['title' => $title, 'type' => $type]);
    $node = reset($node);
    if (!$node) {
      throw new \Exception("No $type node found with title '$title'");
    }
    $this->visitPath('/node/' . $node->id() . '/edit');
  }

  /**
   * @Given I am on the delete page of :type content :title
   */
  public function iAmOnDeletePageOfContent(string $type, string $title): void {
    $node = \Drupal::entityTypeManager()
      ->getStorage('node')
      ->loadByProperties(['title' => $title, 'type' => $type]);
    $node = reset($node);
    if (!$node) {
      throw new \Exception("No $type node found with title '$title'");
    }
    $this->visitPath('/node/' . $node->id() . '/delete');
  }

  /**
   * @Then I should see :text in the :field select
   */
  public function iShouldSeeInSelect(string $text, string $field): void {
    $page = $this->getSession()->getPage();
    $select = $page->findField($field);
    if (!$select) {
      throw new \Exception("Select field '$field' not found");
    }
    $options = $select->findAll('css', 'option');
    foreach ($options as $option) {
      if (str_contains($option->getText(), $text)) {
        return;
      }
    }
    throw new \Exception("Option containing '$text' not found in '$field'");
  }

}
```

## Useful Tags

```gherkin
@api          -> Uses Drupal API driver (creates content via API, faster)
@javascript   -> Uses Selenium (real browser with JS)
@wip          -> Work in progress, can be excluded with --tags="~@wip"
@smoke        -> Quick smoke tests to verify the site works
@regression   -> Regression tests
@MODULE       -> Tag by module to filter execution
```

## Anti-Patterns

1. Do not write steps too specific to the project in feature files. Keep
   the language close to business, not implementation.
2. Do not use `@javascript` when not needed. Goutte/BrowserKit is much faster.
3. Do not mix test logic in feature files. Logic goes in FeatureContext.
4. Do not repeat Background in each scenario. Use the feature's Background.
5. Do not create steps with hidden side effects. Each step should be predictable.

## Execution Command

```bash
# All tests
ssh web ./vendor/bin/behat --config=behat.yml

# By tag
ssh web ./vendor/bin/behat --tags=@content
ssh web ./vendor/bin/behat --tags=@my_module
ssh web ./vendor/bin/behat --tags="@smoke&&~@javascript"

# Specific feature
ssh web ./vendor/bin/behat features/article.feature

# Specific scenario by line
ssh web ./vendor/bin/behat features/article.feature:15

# List available steps
ssh web ./vendor/bin/behat --definitions

# Generate snippets for undefined steps
ssh web ./vendor/bin/behat --dry-run --append-snippets
```
