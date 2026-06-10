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
# Enabled modules count — over ~100 on a simple site suggests module bloat
ssh web drush pm:list --status=enabled --format=list | wc -l

# Recent PHP errors — repeated warnings/notices on every request cost performance
ssh web drush watchdog:show --type=php --count=20

# Slow queries counter — a value > 0 that grows on reload means slow SQL to investigate
ssh web drush sqlq "SHOW STATUS LIKE 'Slow_queries'"
```

For function-level profiling, use the **xdebug-profiling** skill.

## Baseline Measurement (do this BEFORE and AFTER any change)

```bash
# Page timing from inside the web container (timing measurement only — this is
# NOT functional testing; functional testing still uses Playwright, never curl):
ssh web curl -s -o /dev/null -w "first: %{time_total}s\n" http://localhost/PATH
ssh web curl -s -o /dev/null -w "second (warm cache): %{time_total}s\n" http://localhost/PATH
```

Record both numbers. After your fix, re-run and compare — if there is no measurable improvement, the bottleneck is elsewhere.

## How to Detect N+1 Queries

1. Profile the slow page with the **xdebug-profiling** skill (profile mode).
2. In the analyzer output, look for entity load / query functions with a very high call COUNT (e.g. `Drupal\Core\Entity\...::load` called 200 times).
3. Find the loop in the code calling `load()` per item and replace with `loadMultiple()`.
4. Alternative: if the devel/webprofiler module is installed, enable its DB query log and look for many near-identical queries.

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
- [ ] No N+1 queries (check: "How to Detect N+1 Queries" above)
- [ ] Proper indexes on custom tables (check: `ssh web drush sqlq "EXPLAIN SELECT ..."`)
- [ ] Entity queries use accessCheck() (check: `grep -rn "entityQuery" $DDEV_DOCROOT/modules/custom/`)
- [ ] Batch API for bulk operations (>50 items)

### Render System
- [ ] Cache tags on all render arrays (check: `grep -rn "'#cache'" $DDEV_DOCROOT/modules/custom/`)
- [ ] Cache contexts appropriate
- [ ] Lazy builders for expensive/dynamic parts
- [ ] No logic in Twig templates (check with the **twig-audit** skill)

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
