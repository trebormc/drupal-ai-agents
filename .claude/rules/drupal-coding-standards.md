---
description: Drupal coding standards, type hints, DI, cache metadata
globs:
  - "web/modules/custom/**/*.php"
  - "web/modules/custom/**/*.module"
  - "web/modules/custom/**/*.install"
  - "web/modules/custom/**/*.theme"
---

# Drupal Coding Standards

## Non-Negotiable

```php
<?php
declare(strict_types=1);  // ALWAYS first line after <?php
```

| Rule | Requirement |
|------|-------------|
| Indentation | 2 spaces |
| Type hints | ALL parameters and returns |
| DI | Constructor injection, never `\Drupal::service()` in classes |
| Cache | Metadata on ALL render arrays |
| Debug code | NEVER commit: `dpm()`, `kint()`, `dump()`, `console.log()` |

## Cache Metadata (Required on ALL render arrays)

```php
return [
  '#theme' => 'my_template',
  '#data' => $data,
  '#cache' => [
    'tags' => ['node:123', 'node_list'],
    'contexts' => ['user.permissions'],
    'max-age' => 3600,
  ],
];
```

## Query Best Practices

```php
// GOOD - batch load
$nodes = Node::loadMultiple($nids);

// GOOD - with limits
$query = $storage->getQuery()
  ->accessCheck(TRUE)
  ->condition('status', 1)
  ->range(0, 50);

// BAD - N+1 queries
foreach ($nids as $nid) { $node = Node::load($nid); }
```

## Quality Checklist

Before completing ANY task:
- [ ] `declare(strict_types=1)` present
- [ ] All type hints complete
- [ ] DI used (no static `\Drupal::` calls in classes)
- [ ] Cache metadata on render arrays
- [ ] No debug code
- [ ] PHPStan level 8 clean
- [ ] PHPCS clean
