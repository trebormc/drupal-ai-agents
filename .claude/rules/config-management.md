---
description: Drupal configuration management — export, import, config_split, schema
globs:
  - "config/sync/**/*.yml"
  - "config/**/*.yml"
---

# Configuration Management

## Rules

- **Always export after changes**: `ssh web ./vendor/bin/drush cex -y`
- **Never edit config YAML files manually** — use Drupal admin UI or drush, then export
- **Use config_split** for environment-specific config (dev modules, performance settings)
- **Validate schema** — ensure `.schema.yml` exists for custom config

## Commands

```bash
# Export config
ssh web ./vendor/bin/drush cex -y

# Import config
ssh web ./vendor/bin/drush cim -y

# Check status (pending changes)
ssh web ./vendor/bin/drush config:status
```

## Config Split

- `config/sync/` — shared across all environments
- `config/split/dev/` — dev-only (devel, kint, webprofiler)
- `config/split/prod/` — production-only (aggregation, caching)
