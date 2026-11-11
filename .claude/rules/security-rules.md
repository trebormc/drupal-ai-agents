---
description: Drupal security essentials — input sanitization, SQL injection, XSS, CSRF, access control
paths:
  - "**/modules/custom/**"
  - "**/themes/custom/**"
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

## Entity Queries and Entity Access

`->accessCheck(TRUE)` is NOT access control on its own. It filters **node** queries
(node grants) and entity types that implement query access themselves; on a custom
content entity with a plain `EntityAccessControlHandler` (logs, cost entries, tokens,
runs...) it only adds a query tag that nothing alters, and the query returns every row.

- Non-node entity types: load, then filter with `$entity->access('view', $account)`
  before mapping, counting or rendering; or implement `hook_query_<TAG>_alter` for the
  tag the entity declares. Never report a query as "access-checked" in a docblock when
  the type has no query alter.
- Listings: `total` and page size must be computed after the access filter (or with an
  explicit `status`/owner condition), or counts leak the existence of hidden rows.
- References in output (owner, assignee, agent, parent): dereference under the same rule
  as the input resolver. Resolving a reference the caller cannot view while rendering it
  as `null`, or answering "not found" vs "forbidden" differently, lets a caller
  enumerate entities. One resolver, one rule, one error message.
- Totals and aggregates (costs, time, token usage) are data about other entities: gate
  them by the permission that views those entities, not by the parent's view access.

## Rules

- Never output raw user input: use `#plain_text` or `Html::escape()`
- Never use `|raw` in Twig on user content
- Always define permissions in `.permissions.yml`
- Always use Form API for state-changing operations (CSRF protection)
