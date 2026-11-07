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

## Exporting Only Your Change

`drush cex` exports ALL active config, including drift that predates your task:

1. Run `ssh web drush config:status` BEFORE changing anything and keep the list.
2. After `cex`, check `git status` against that list and restore every file you did not
   mean to change, so the diff holds only your change.
3. Read the export for unexpected keys, on multilingual sites above all. Drush runs in the
   default language, so a config ENTITY loaded and saved from a script writes that
   language's overrides into the base config. Edit raw data instead:
   `\Drupal::configFactory()->getEditable($name)->set(...)->save()`, and
   `\Drupal::languageManager()->getLanguageConfigOverride($langcode, $name)` for translations.
4. `drush locale:update` can rewrite active config whose `langcode` is not `en`: run
   `config:status` right after it.

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
