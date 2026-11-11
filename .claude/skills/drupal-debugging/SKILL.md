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
  Never use for routine operations such as cache clears, updb or enabling
  modules (use drush-commands), or for timing and call-tree profiling (use
  xdebug-profiling).
---

## Environment

All commands via `ssh web`.
For Xdebug tracing/profiling (function call trees, execution timing), use the **xdebug-profiling** skill.

## Core Debugging & Information

| Command | Purpose |
|---------|---------|
| `ssh web drush status` | Drupal root, site path, DB connection |
| `ssh web drush core-status` | Detailed system status |
| `ssh web drush watchdog:show` | Recent log messages |
| `ssh web drush watchdog:show --severity=Error` | Only errors |
| `ssh web drush watchdog:show --count=50` | Last 50 entries |

## Cache Debugging

| Command | Purpose |
|---------|---------|
| `ssh web drush cache:clear render` | Clear only render cache |
| `ssh web drush cache:clear router` | Rebuild routing cache |
| `ssh web drush cache:clear css-js` | Clear CSS/JS aggregation cache |
| `ssh web drush cr` | Full cache rebuild (when in doubt, use this) |

## Configuration Debugging

| Command | Purpose |
|---------|---------|
| `ssh web drush config:get system.site` | Show config value |
| `ssh web drush config:set system.site name "New"` | Set config value |
| `ssh web drush config:status` | Show config sync status |

## PHP Evaluation (drush php:eval)

```bash
# Inspect state values
ssh web 'drush php:eval "var_dump(\Drupal::state()->get(\"system.cron_last\"));"'

# Check if function exists
ssh web 'drush php:eval "var_dump(function_exists(\"my_custom_function\"));"'

# List enabled modules
ssh web 'drush php:eval "print_r(array_keys(\Drupal::moduleHandler()->getModuleList()));"'

# Pending entity definition updates
ssh web 'drush php:eval "print_r(\Drupal::entityDefinitionUpdateManager()->getChangeSummary());"'

# List available services
ssh web 'drush php:eval "print_r(\Drupal::getContainer()->getServiceIds());"'

# Check specific service exists
ssh web 'drush php:eval "var_dump(\Drupal::hasService(\"mymodule.my_service\"));"'

# Inspect entity field definitions
ssh web 'drush php:eval "print_r(array_keys(\Drupal::service(\"entity_field.manager\")->getFieldDefinitions(\"node\", \"article\")));"'
```

## Database Debugging

```bash
# Direct SQL query
ssh web 'drush sql:query "SELECT * FROM users_field_data LIMIT 5"'

# Recent watchdog entries via SQL
ssh web 'drush sql:query "SELECT * FROM watchdog ORDER BY wid DESC LIMIT 20"'

# List all entity types
ssh web 'drush php:eval "print_r(array_keys(\Drupal::entityTypeManager()->getDefinitions()));"'

# Check route definitions (grep runs in YOUR container — this works)
ssh web drush route | grep mymodule
```

## Container & Log Debugging

```bash
# PHP errors Drupal logged (the first place to look)
ssh web drush watchdog:show --severity=Error --count=20

# Test database connection
ssh web drush sql:connect
```

Web server and database logs are not files you can read from here: DDEV's web
container runs nginx by default and logs to the container output, and the
database runs in another container with no SSH access. When watchdog is not
enough, ask the user for `ddev logs -s web` or `ddev logs -s db` from the host.

## Common Troubleshooting Patterns

| Problem | Debug command |
|---------|-------------|
| Class not found | `ssh web composer dump-autoload && ssh web drush cr` |
| Service not found | Check services.yml syntax, then `ssh web drush cr` |
| Plugin not discovered | `ssh web 'drush php:eval "print_r(array_keys(\Drupal::service(\"plugin.manager.block\")->getDefinitions()));"'` |
| Route not working | Run `ssh web drush route` and search the output for your route; if missing, `ssh web drush cr` |
| Entity field missing | `ssh web 'drush php:eval "print_r(\Drupal::entityDefinitionUpdateManager()->getChangeSummary());"'` |

## Twig Debugging

```bash
# Enable Twig debugging via Drush (Drush 12.5+; use manual setup below for older Drush)
ssh web drush twig:debug on

# Check theme registry
ssh web 'drush php:eval "print_r(array_keys(\Drupal::service(\"theme.registry\")->get()));"'
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
| Tailwind classes not working | Recompile: `ssh web npm run build --prefix $DDEV_DOCROOT/themes/custom/THEME`, `ssh web drush cr`, hard refresh (Ctrl+Shift+R) |
| JavaScript not executing | Verify library attached (`{{ attach_library() }}`), check console for errors, verify `mytheme.libraries.yml` syntax, `drush cr` |
| Cache issues | Disable render/page/dynamic_page caches in `settings.local.php` using `cache.backend.null` |
| Template suggestions not appearing | `ssh web drush twig:debug`, `drush cr` |
| Preprocess variables unavailable | Check hook name (`mytheme_preprocess_node`), verify theme is active, `drush cr`. Debug with `dump($variables)` in the preprocess function or `{{ dump() }}` in the template (Twig debug on); `kint()` exists only when the devel module is enabled. Remove the dump when done |
| CSS/JS libraries not loading | `ssh web 'drush php:eval "print_r(array_keys(\Drupal::service(\"library.discovery\")->getLibrariesByExtension(\"mytheme\")));"'` |
| Field not rendering correctly | `ssh web 'drush php:eval "print_r(\Drupal::service(\"entity_field.manager\")->getFieldDefinitions(\"node\", \"article\")[\"field_name\"]->getSettings());"'` |
| Images not displaying | `ssh web drush image:flush --all` and check file permissions |
| Translations not appearing | `ssh web drush locale:clear-status && ssh web drush locale:update` |

## Test Troubleshooting

| Problem | Fix |
|---------|-----|
| "Class not found" in tests | `ssh web composer dump-autoload`. Verify namespace matches directory path |
| Kernel: "Entity type not found" | Add module to `$modules`, call `$this->installEntitySchema('entity_type')` in `setUp()` |
| Functional: "Route not found" | Verify module in `$modules`, try `$this->rebuildContainer()`, check the route exists with `ssh web drush route` |
| "SQLSTATE no such table" | Call `$this->installEntitySchema('user')`, `$this->installSchema('node', ['node_access'])` in `setUp()` |
| "Service not found" | Ensure module with service is in `$modules`. Get via `$this->container->get('service.id')` |
| Tests pass locally, fail in CI | Check hardcoded paths/URLs, timezone settings, race conditions, use transactions |
| "Test was not supposed to have output" | Don't use print/echo. Capture with `$this->expectOutputString('expected')` |
| "Maximum function nesting level" | `ssh web php -d xdebug.max_nesting_level=500 ./vendor/bin/phpunit ...` |
| Functional: "Failed to connect localhost:80" | `SIMPLETEST_BASE_URL` is not set: define it in `phpunit.xml` or pass it inline (Form CORE in the **drupal-testing** skill) |
| "Could not connect to database" | `ssh web 'drush sql:query "CREATE DATABASE IF NOT EXISTS test;"'`. SIMPLETEST_DB: `mysql://db:db@db/test` |
| Browser screenshots not saving | `ssh web mkdir -p $DDEV_DOCROOT/sites/simpletest/browser_output`, and check `BROWSERTEST_OUTPUT_DIRECTORY` points at it |
| "Theme not found" in functional | Set `protected $defaultTheme = 'stark';` or install custom theme in `setUp()` |
| Test is very slow or times out | Remove unneeded modules from `$modules`; move logic assertions down to a Kernel test; in FunctionalJS replace fixed waits with condition waits |
| "Test site directory exists already" | `ssh web rm -rf $DDEV_DOCROOT/sites/simpletest/` (test artifacts only), then recreate the browser_output dir |

## Performance Troubleshooting

| Problem | Fix |
|---------|-----|
| Page not caching | Check for `max-age: 0` in any render array. Look for session-dependent code. Enable `http.response.debug_cacheability_headers: true` in development.services.yml |
| Cache not invalidating | Verify cache tags are correct. Test: `ssh web 'drush php:eval "\Drupal::service(\"cache_tags.invalidator\")->invalidateTags([\"node:123\"]);"'` |
| Queries still slow | Check indexes: `ssh web 'drush sqlq "EXPLAIN SELECT ..."'`. Add custom index in `hook_schema()` |
| Memory issues | `ssh web 'drush php:eval "echo \"Peak: \" . round(memory_get_peak_usage(true) / 1024 / 1024) . \"MB\";"'`. Use `resetCache()` in batch operations |
| Views performance | Enable query caching + rendered output caching. Configure pager (no unlimited). Use Search API for complex queries |

## Verification

```bash
# Quick health check
ssh web drush status --field=drupal-version
ssh web drush core:requirements --severity=2
```
