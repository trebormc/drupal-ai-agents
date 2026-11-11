---
description: Drupal coding standards, type hints, DI, cache metadata
paths:
  - "**/modules/custom/**/*.php"
  - "**/modules/custom/**/*.module"
  - "**/modules/custom/**/*.install"
  - "**/modules/custom/**/*.theme"
  - "**/themes/custom/**/*.theme"
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
| Injected properties | `protected`, never `private`, in anything using `DependencySerializationTrait` (FormBase, EntityForm, Core PluginBase and their children): PHPStan `dependencySerializationTraitProperty.unsupportedPrivateProperty`. No `readonly` there on PHP < 8.4 |
| Debug code | NEVER commit: `dpm()`, `kint()`, `dump()`, `console.log()` |
| User-facing strings | ENGLISH source + translation function (`$this->t()`, `\|t`, `Drupal.t()`) — see **translations** rule |
| Comments | Docblocks on every class/method/function (PHPCS Drupal standard requires them, one-line summary that says what, not how). Inline comments only for a non-obvious WHY the code cannot show. No narration (`// loop over nodes`), no phase markers (`// Step 1`), no commented-out code, no `@todo` without an issue link. A workaround that needs a paragraph to justify it is a fix in the wrong place |

## Cache Metadata (Required on ALL render arrays)

```php
return [
  '#theme' => 'my_template',
  '#data' => $data,
  '#cache' => [
    // Tags from the objects rendered, contexts for what the output varies by.
    // Set max-age only when the data really expires on a clock.
    'tags' => $node->getCacheTags(),
    'contexts' => ['user.permissions'],
  ],
];
```

## Query Best Practices

```php
// GOOD - batch load
$nodes = Node::loadMultiple($nids);

// GOOD - with limits
$query = $storage->getQuery()
  ->accessCheck(TRUE)   // filters nodes; on other entity types it only adds a tag:
  ->condition('status', 1)   // filter those with $entity->access('view') after loading
  ->range(0, 50);

// BAD - N+1 queries
foreach ($nids as $nid) { $node = Node::load($nid); }

// BAD - query() rewrites { and } as table quoting, even inside a quoted value: stores ""
$database->query("UPDATE {my_table} SET data = '{}'");
// GOOD - bind anything with braces
$database->query('UPDATE {my_table} SET data = :data', [':data' => '{}']);
```

## Quality Checklist

Before completing ANY task:
- [ ] `declare(strict_types=1)` present
- [ ] All type hints complete
- [ ] DI used (no static `\Drupal::` calls in classes)
- [ ] Cache metadata on render arrays
- [ ] No debug code
- [ ] User-facing strings: English source, wrapped in translation functions, literal-only with placeholders (**translations** rule — run its detection greps on your changes)
- [ ] PHPStan clean for YOUR code (level 8 target; if the project ships its own `phpstan.neon`, respect its level; for pre-existing errors in legacy code use a baseline — see **quality-checks** skill — do NOT fix unrelated files)
- [ ] PHPCS clean
