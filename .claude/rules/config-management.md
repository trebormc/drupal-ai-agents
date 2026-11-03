---
description: Drupal configuration management — export, import, config_split, schema
paths:
  - "**/config/sync/**/*.yml"
  - "**/config/install/**/*.yml"
  - "**/config/schema/**/*.yml"
---

# Configuration Management

## Rules

- **Always export after changes**: `ssh web drush cex -y`
- **Never edit config YAML files manually** — use Drupal admin UI or drush, then export
- **Use config_split** for environment-specific config (dev modules, performance settings)
- **Validate schema** — ensure `.schema.yml` exists for custom config

## Commands

```bash
# Export config
ssh web drush cex -y

# Import config
ssh web drush cim -y

# Check status (pending changes)
ssh web drush config:status
```

## Config Split

- `config/sync/` — shared across all environments
- `config/split/dev/` — dev-only (devel, kint, webprofiler)
- `config/split/prod/` — production-only (aggregation, caching)

## Deploy order after a merge

`drush updb -y` → `drush cim -y` → `drush cr` → check one new route with `curl`. A new
module enabled by `cim` is not routable until the cache rebuild (its routes answer 404),
and update hooks that queue batches (locale imports) need `updb` before you test the UI.
