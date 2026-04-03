---
name: drupal-debugging
description: >-
  Provides Drupal debugging commands for inspecting services, entities, cache,
  configuration, watchdog logs, database queries, and PHP evaluation via drush.
  Use when diagnosing issues, inspecting Drupal state, or troubleshooting errors.
  Examples:
  - user: "check watchdog logs" -> show recent log entries
  - user: "debug this service" -> inspect service container and definitions
  - user: "what errors are in the log" -> show watchdog errors
  - user: "inspect the cache" -> cache debugging commands
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

## Twig Debugging

```bash
# Enable Twig debugging via Drush
docker exec $WEB_CONTAINER ./vendor/bin/drush twig:debug

# Check theme registry
docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(array_keys(\Drupal::service('theme.registry')->get()));"
```

Manual setup for persistent Twig debugging:

**In `settings.local.php`:**
```php
$settings['container_yamls'][] = DRUPAL_ROOT . '/sites/development.services.yml';
```

**In `sites/development.services.yml`:**
```yaml
parameters:
  twig.config:
    debug: true
    auto_reload: true
    cache: false
```

With Twig debugging enabled, HTML comments show template suggestions and the active template path.

## Theme Troubleshooting

| Problem | Fix |
|---------|-----|
| Template not being used | Check filename matches Drupal suggestion exactly. Enable Twig debug, check HTML comments, `drush cr` |
| Tailwind classes not working | Recompile: `npm run build --prefix $DDEV_DOCROOT/themes/custom/THEME`, `drush cr`, hard refresh (Ctrl+Shift+R) |
| JavaScript not executing | Verify library attached (`{{ attach_library() }}`), check console for errors, verify `mytheme.libraries.yml` syntax, `drush cr` |
| Cache issues | Disable render/page/dynamic_page caches in `settings.local.php` using `cache.backend.null` |
| Template suggestions not appearing | `docker exec $WEB_CONTAINER ./vendor/bin/drush twig:debug`, `drush cr` |
| Preprocess variables unavailable | Check hook name (`mytheme_preprocess_node`), verify theme is active, `drush cr`. Debug with `kint($variables)` |
| CSS/JS libraries not loading | `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(array_keys(\Drupal::service('library.discovery')->getLibrariesByExtension('mytheme')));"` |
| Field not rendering correctly | `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "print_r(\Drupal::service('entity_field.manager')->getFieldDefinitions('node', 'article')['field_name']->getSettings());"` |
| Images not displaying | `docker exec $WEB_CONTAINER ./vendor/bin/drush image:flush --all` and check file permissions |
| Translations not appearing | `docker exec $WEB_CONTAINER ./vendor/bin/drush locale:clear-status && docker exec $WEB_CONTAINER ./vendor/bin/drush locale:update` |

## Test Troubleshooting

| Problem | Fix |
|---------|-----|
| "Class not found" in tests | `docker exec $WEB_CONTAINER composer dump-autoload`. Verify namespace matches directory path |
| Kernel: "Entity type not found" | Add module to `$modules`, call `$this->installEntitySchema('entity_type')` in `setUp()` |
| Functional: "Route not found" | Verify module in `$modules`, try `$this->rebuildContainer()`, check `drush route:list \| grep module` |
| "SQLSTATE no such table" | Call `$this->installEntitySchema('user')`, `$this->installSchema('node', ['node_access'])` in `setUp()` |
| "Service not found" | Ensure module with service is in `$modules`. Get via `$this->container->get('service.id')` |
| Tests pass locally, fail in CI | Check hardcoded paths/URLs, timezone settings, race conditions, use transactions |
| "Test was not supposed to have output" | Don't use print/echo. Capture with `$this->expectOutputString('expected')` |
| "Maximum function nesting level" | `docker exec $WEB_CONTAINER php -d xdebug.max_nesting_level=500 ./vendor/bin/phpunit ...` |
| Functional: "Failed to connect localhost:80" | Ensure `SIMPLETEST_BASE_URL` set in phpunit.xml or use `$this->setBaseUrl('http://web')` |
| "Could not connect to database" | `docker exec $WEB_CONTAINER ./vendor/bin/drush sql:query "CREATE DATABASE IF NOT EXISTS test;"`. SIMPLETEST_DB: `mysql://db:db@db/test` |
| Browser screenshots not saving | `docker exec $WEB_CONTAINER mkdir -p /var/www/html/sites/simpletest/browser_output && docker exec $WEB_CONTAINER chmod 777 /var/www/html/sites/simpletest/browser_output` |
| "Theme not found" in functional | Set `protected $defaultTheme = 'stark';` or install custom theme in `setUp()` |
| Test timeout issues | `--timeout=300` flag. Check for unnecessary modules in `$modules` |
| "Test site directory exists already" | `docker exec $WEB_CONTAINER rm -rf /var/www/html/sites/simpletest/` then recreate browser_output dir |

## Performance Troubleshooting

| Problem | Fix |
|---------|-----|
| Page not caching | Check for `max-age: 0` in any render array. Look for session-dependent code. Enable `http.response.debug_cacheability_headers: true` in development.services.yml |
| Cache not invalidating | Verify cache tags are correct. Test: `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "\Drupal::service('cache_tags.invalidator')->invalidateTags(['node:123']);"` |
| Queries still slow | Check indexes: `docker exec $WEB_CONTAINER ./vendor/bin/drush sqlq "EXPLAIN SELECT ..."`. Add custom index in `hook_schema()` |
| Memory issues | `docker exec $WEB_CONTAINER ./vendor/bin/drush php:eval "echo 'Peak: ' . round(memory_get_peak_usage(true) / 1024 / 1024) . 'MB';"`. Use `resetCache()` in batch operations |
| Views performance | Enable query caching + rendered output caching. Configure pager (no unlimited). Use Search API for complex queries |

## Verification

```bash
# Quick health check
docker exec $WEB_CONTAINER ./vendor/bin/drush status --field=drupal-version
docker exec $WEB_CONTAINER ./vendor/bin/drush core:requirements --severity=2
```
