---
name: drupal-debugging
description: >-
  Provides Drupal debugging commands for inspecting services, entities, cache,
  configuration, watchdog logs, database queries, and PHP evaluation via drush.
  Use when diagnosing issues, inspecting Drupal state, or troubleshooting errors.
  Examples:
  - user: "check watchdog logs" -> show recent log entries
  - user: "debug this service" -> inspect service container and definitions
  - user: "que errores hay en el log" -> show watchdog errors
  - user: "inspeccionar la cache" -> cache debugging commands
  Never use for destructive operations (use drush-commands skill instead).
---

## Environment

All commands via `docker exec $WEB_CONTAINER`.
For Xdebug tracing/profiling (function call trees, execution timing), use the **xdebug-profiling** skill.

## Core Debugging & Information

| Command | Purpose |
|---------|---------|
| `docker exec $WEB_CONTAINER ./vendor/bin/drush status` | Drupal root, site path, DB connection |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush core-status` | Detailed system status |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush watchdog:show` | Recent log messages |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush watchdog:show --severity=Error` | Only errors |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush watchdog:show --count=50` | Last 50 entries |

## Cache Debugging

| Command | Purpose |
|---------|---------|
| `docker exec $WEB_CONTAINER ./vendor/bin/drush cache:get config:core.extension` | Get specific cache item |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush cache:clear render` | Clear only render cache |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush cache:clear page` | Clear only page cache |

## Configuration Debugging

| Command | Purpose |
|---------|---------|
| `docker exec $WEB_CONTAINER ./vendor/bin/drush config:get system.site` | Show config value |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush config:set system.site name "New"` | Set config value |
| `docker exec $WEB_CONTAINER ./vendor/bin/drush config:status` | Show config sync status |

## PHP Evaluation (drush php:eval)

```bash
# Inspect state values
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "var_dump(\Drupal::state()->get('system.cron_last'));"

# Check if function exists
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "var_dump(function_exists('my_custom_function'));"

# List enabled modules
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(array_keys(\Drupal::moduleHandler()->getModuleList()));"

# Pending entity definition updates
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(\Drupal::entityDefinitionUpdateManager()->getChangeSummary());"

# List available services
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(\Drupal::getContainer()->getServiceIds());"

# Check specific service exists
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "var_dump(\Drupal::hasService('mymodule.my_service'));"

# Inspect entity field definitions
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(array_keys(\Drupal::service('entity_field.manager')->getFieldDefinitions('node', 'article')));"
```

## Database Debugging

```bash
# Direct SQL query
docker exec $WEB_CONTAINER ./vendor/bin/drush sql:query "SELECT * FROM users_field_data LIMIT 5"

# Recent watchdog entries via SQL
docker exec $WEB_CONTAINER ./vendor/bin/drush sql:query "SELECT * FROM watchdog ORDER BY wid DESC LIMIT 20"

# Entity type info
docker exec $WEB_CONTAINER ./vendor/bin/drush entity:info

# Check route definitions
docker exec $WEB_CONTAINER ./vendor/bin/drush route:list | grep mymodule
```

## Container & Log Debugging

```bash
# Web container error logs
docker exec $WEB_CONTAINER tail -f /var/log/apache2/error.log

# Database container logs
docker exec $DB_CONTAINER tail -f /var/log/mysql/error.log

# Test database connection
docker exec $WEB_CONTAINER ./vendor/bin/drush sql:connect
```

## Common Troubleshooting Patterns

| Problem | Debug command |
|---------|-------------|
| Class not found | `docker exec $WEB_CONTAINER composer dump-autoload && docker exec $WEB_CONTAINER ./vendor/bin/drush cr` |
| Service not found | Check services.yml syntax, then `docker exec $WEB_CONTAINER ./vendor/bin/drush cr` |
| Plugin not discovered | `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(array_keys(\Drupal::service('plugin.manager.block')->getDefinitions()));"` |
| Route not working | `docker exec $WEB_CONTAINER ./vendor/bin/drush route:list \| grep mymodule` |
| Entity field missing | `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(\Drupal::entityDefinitionUpdateManager()->getChangeSummary());"` |

## Verification

```bash
# Quick health check
docker exec $WEB_CONTAINER ./vendor/bin/drush status --field=drupal-version
docker exec $WEB_CONTAINER ./vendor/bin/drush core:requirements --severity=2
```
