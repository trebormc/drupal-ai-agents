---
description: Drupal security essentials — input sanitization, SQL injection, XSS, CSRF, access control
globs:
  - "web/modules/custom/**/*"
  - "web/themes/custom/**/*"
---

# Security Rules

## Input Sanitization

```php
Html::escape($userInput);           // Plain text
Xss::filter($userInput);            // Limited HTML
UrlHelper::filterBadProtocol($url); // URLs
```

## Database — ALWAYS Use Placeholders

```php
$db->query("SELECT * FROM {users} WHERE name = :name", [':name' => $input]);
```

## Translations

```php
$this->t('Hello @name', ['@name' => $username]);
// @=escape, :=URL, %=em+escape
```

## Route Access

```yaml
# Permission-based
requirements:
  _permission: 'access content'

# Entity access
requirements:
  _entity_access: 'node.update'

# CSRF for state-changing
requirements:
  _csrf_token: 'TRUE'
```

## Rules

- Never output raw user input: use `#plain_text` or `Html::escape()`
- Never use `|raw` in Twig on user content
- Always define permissions in `.permissions.yml`
- Always use Form API for state-changing operations (CSRF protection)
