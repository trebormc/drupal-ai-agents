---
name: performance-audit
description: >-
  Audit Drupal performance: cache metadata, database queries, render arrays,
  lazy builders, BigPipe, N+1 queries. Analyze bottlenecks, implement caching
  strategies, optimize entity loading. Use when pages load slowly, optimizing
  performance, reviewing cache implementations, or profiling queries.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Performance Audit

## Diagnostic Commands

```bash
# Enabled modules count
ssh web ./vendor/bin/drush pm:list --status=enabled --format=list | wc -l

# Recent watchdog entries
ssh web ./vendor/bin/drush watchdog:show --type=php --count=20

# Clear cache
ssh web ./vendor/bin/drush cr

# Database status
ssh web ./vendor/bin/drush sqlq "SHOW STATUS LIKE 'Slow_queries'"
```

For function-level profiling, use the **xdebug-profiling** skill.

## Caching Strategy

### Cache Tags (What to invalidate)
```php
$build['#cache']['tags'] = ['node:123', 'node_list'];

// Custom tags
$build['#cache']['tags'] = Cache::mergeTags(
  $entity->getCacheTags(),
  ['mymodule:custom_list']
);
```

### Cache Contexts (When to vary)
```php
$build['#cache']['contexts'] = [
  'user.permissions',
  'user.roles:authenticated',
  'url.query_args',
  'languages:language_content',
];
```

### Cache Max-Age
```php
$build['#cache']['max-age'] = 3600;          // 1 hour
$build['#cache']['max-age'] = 0;             // Never cache (use sparingly!)
$build['#cache']['max-age'] = Cache::PERMANENT; // Until invalidated
```

### Lazy Builder for Dynamic Content
```php
$build['dynamic_part'] = [
  '#lazy_builder' => [
    'mymodule.lazy_builder:build',
    [$entity_id],
  ],
  '#create_placeholder' => TRUE,
];
```

## Database Optimization

### Avoid N+1 Queries
```php
// BAD - N+1 queries
foreach ($nids as $nid) {
  $node = Node::load($nid);
}

// GOOD - Single query
$nodes = Node::loadMultiple($nids);
```

### Efficient Entity Queries
```php
$query = \Drupal::entityQuery('node')
  ->condition('type', 'article')
  ->condition('status', 1)
  ->range(0, 50)
  ->sort('created', 'DESC')
  ->accessCheck(TRUE);
$nids = $query->execute();
```

## Performance Audit Checklist

### Database
- [ ] No N+1 queries
- [ ] Proper indexes on custom tables
- [ ] Entity queries use accessCheck()
- [ ] Batch API for bulk operations (>50 items)

### Render System
- [ ] Cache tags on all render arrays
- [ ] Cache contexts appropriate
- [ ] Lazy builders for expensive/dynamic parts
- [ ] No logic in Twig templates

### Views Specific
- [ ] Query caching enabled
- [ ] Rendered output caching enabled
- [ ] Pager configured (no unlimited)
- [ ] Only necessary fields loaded

## Optimization Workflow

### Step 1: Baseline Measurement
Measure cold cache time, warm cache time, query count, memory usage.

### Step 2: Identify Bottlenecks
Priority: Database queries → Uncached render arrays → Heavy computations → External calls

### Step 3: Implement Fix

| Problem | Solution |
|---------|----------|
| N+1 queries | Use `loadMultiple()` |
| Repeated computation | Add caching layer |
| Dynamic user content | Use lazy builder |
| Heavy view | Add Views caching |
| Large entity loads | Load only needed fields |

### Step 4: Measure Improvement
Re-run baseline tests. Document before/after metrics.

### Step 5: Validate
- Verify cache invalidation works correctly
- Test edge cases (anonymous vs authenticated)

## Library Optimization
```yaml
# Only load JS/CSS when needed
mymodule.specific:
  js:
    js/specific.js: {}
  dependencies:
    - core/drupal
```

## Reference Skills

- **xdebug-profiling** — function-level timing, call trees, cachegrind
- **drupal-debugging** — cache debugging, slow query diagnosis
