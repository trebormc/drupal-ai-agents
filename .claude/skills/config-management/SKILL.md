---
name: config-management
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

## Config vs State vs Settings — decide BEFORE storing anything

Drupal has three storage mechanisms; picking the wrong one causes deploy bugs, security
leaks, or data loss. Decide with this table:

| Question | Use | API |
|---|---|---|
| Site-building decision, same across environments? | **Config** | `config.factory` (inject) |
| Runtime data that changes frequently (timestamps, counters, flags)? | **State** | `\Drupal::state()` |
| Environment-specific or secret (API keys, credentials, salts)? | **Settings** | `Settings::get()` + settings.php |
| Admin manages multiple named instances via UI, or needs dependency tracking? | **Config entity** | — |
| A few key-value module settings? | **Simple config** | — |

The two classic mistakes:
- **A secret in config** → exported to YAML, committed to git. Security leak. Store in
  `$settings[...]` (settings.php / env var) instead.
- **Runtime data in config** (last sync time, counters) → `drush cex` shows permanent
  diffs and the next deploy overwrites production state. Use State.

Config CAN differ per environment via overrides (`$config[...]` in settings.php) — the
stored default stays shared, the override layers on top at runtime.

### Reading vs writing config

```php
$value = $config_factory->get('system.site')->get('name');          // active value (overrides applied)
$raw = $config_factory->get('system.site')->getOriginal('name', FALSE); // stored value, no overrides
$config_factory->getEditable('system.site')->set('name', 'X')->save();  // write (ignores overrides)
```

Do not use `getEditable()` just to read, and never save a config object obtained with
overrides applied — overrides are read-only.

### Modifying config you do not own

Never write directly into another module's config keys. Use third-party settings — they
are namespaced and cleaned up on uninstall:

```php
$content_type->setThirdPartySetting('my_module', 'custom_flag', TRUE)->save();
```

They need schema too, under the `*.third_party.my_module` pattern.

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

### Verify after export/import (ALWAYS)

```bash
# After cex or cim, this should report "No differences":
ssh web drush config:status
```

### Resolving import conflicts
```bash
# Check current config status
ssh web drush config:status

# "Only in sync dir" — new config to import
# "Only in DB" — needs export or was deleted intentionally
# "Different" — conflict to resolve
```

### If cex/cim fails

| Error | Cause | Fix |
|-------|-------|-----|
| "Site UUID ... does not match" on cim | Sync dir from a different site | Only if intentional: `ssh web drush config:set system.site uuid <uuid-from-sync-dir> -y`, then retry |
| Unmet dependency / unknown module on cim | Config references a missing module | `ssh web composer require drupal/<module>` + `ssh web drush en <module> -y`, then retry |
| Validation/schema error on cim | Invalid config in sync dir | Read the named file in `config/sync/`, fix it (or re-export from a working env), retry |
| cex writes nothing | No changes to export | Confirm with `ssh web drush config:status` — that is normal |

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
    api_endpoint:
      type: uri
      label: 'API endpoint'
    display_title:
      type: label
      label: 'Display title'
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

Type gotchas (strict validation is enforced incrementally since Drupal 10.3 — wrong
schema now FAILS config import, it is not cosmetic):

- Human-readable, translatable strings → type `label`, not `string` (the most common
  generated-schema error; `string` values are untranslatable).
- URIs → `uri`; internal paths → `path`; lists → `sequence` (not a `string`).
- The declared type must match the YAML value type exactly (no `string` for integers).
- API keys/secrets do NOT belong in config at all — see the decision table above.
- Config in `config/install/` must declare its `dependencies:` (module/config/theme) —
  missing dependencies do not fail at install time but break config import later.

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
