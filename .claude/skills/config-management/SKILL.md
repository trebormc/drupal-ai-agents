---
name: drupal-config-management
description: >-
  Manages Drupal configuration: export, import, config_split setup, schema
  validation, and environment-specific overrides via settings.php. Use when
  dealing with config sync, config_split, settings.php overrides, or config
  schema creation.
  Examples:
  - user: "set up config split for dev/stage/prod" -> configure config_split
  - user: "my config import fails" -> diagnose and fix config sync issues
  - user: "add config schema for my module" -> generate proper schema.yml
  - user: "configure config split" -> configure config_split
  - user: "export configuration" -> guide through drush cex workflow
  - user: "config import fails" -> diagnose config sync issues
  Never directly modify files in config/sync/ — always use drush cex.
---

## Environment

All commands via `ssh web drush`.
Config sync directory: `config/sync/` (relative to project root).

## Config export/import workflow

### Standard workflow
```bash
# Export (after making changes in UI or code)
ssh web drush cex -y

# Import (when pulling changes from git)
ssh web drush cim -y

# Preview what will change on import
ssh web drush cim --diff
```

### Resolving import conflicts
```bash
# Check current config status
ssh web drush config:status

# "Only in sync dir" — new config to import
# "Only in DB" — needs export or was deleted intentionally
# "Different" — conflict to resolve
```

## Config Split setup

### Installation
```bash
ssh web composer require drupal/config_split
ssh web drush en config_split -y
```

### Directory structure
```
config/
├── sync/          # Base config (shared across all environments)
├── splits/
│   ├── dev/       # Dev-only config (devel, kint, etc.)
│   ├── stage/     # Stage-specific overrides
│   └── prod/      # Production overrides
```

### settings.php activation
```php
// settings.local.php (dev)
$config['config_split.config_split.dev']['status'] = TRUE;
$config['config_split.config_split.stage']['status'] = FALSE;
$config['config_split.config_split.prod']['status'] = FALSE;

// settings.php (prod)
$config['config_split.config_split.dev']['status'] = FALSE;
$config['config_split.config_split.prod']['status'] = TRUE;
```

### Common splits

| Split | Modules | Purpose |
|-------|---------|---------|
| dev | devel, kint, webprofiler, field_ui, views_ui | Development tools |
| stage | stage_file_proxy | Asset proxying |
| prod | redis, cdn, advagg | Performance modules |

## Config schema (REQUIRED for all config)

Every module with configuration MUST have `config/schema/{module}.schema.yml`.

### Schema types reference

```yaml
{module_name}.settings:
  type: config_object
  label: '{Module Name} settings'
  mapping:
    enabled:
      type: boolean
      label: 'Enabled'
    api_key:
      type: string
      label: 'API Key'
    max_items:
      type: integer
      label: 'Maximum items'
    allowed_types:
      type: sequence
      label: 'Allowed content types'
      sequence:
        type: string
        label: 'Content type'
```

## Settings.php overrides

```php
// Environment-specific overrides (not exported to config)
$config['system.performance']['css']['preprocess'] = TRUE;
$config['system.performance']['js']['preprocess'] = TRUE;
$config['system.logging']['error_level'] = 'hide';

// Sensitive values (never in config/sync/)
$settings['hash_salt'] = getenv('HASH_SALT');
$config['smtp.settings']['smtp_password'] = getenv('SMTP_PASSWORD');
```

## Verification

```bash
# Check config sync status
ssh web drush config:status

# Validate config schema (check for missing schemas)
ssh web drush config:inspect

# Verify config split is active
ssh web drush config:get config_split.config_split.dev status
```
