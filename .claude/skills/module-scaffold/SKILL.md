---
name: drupal-module-scaffold
description: >-
  Scaffolds a new Drupal 10/11 custom module with proper PSR-4 structure,
  services.yml, routing.yml, info.yml, permissions.yml, and config schema.
  Use when creating a new custom module or when user says "create module",
  "new module", "scaffold module".
  Examples:
  - user: "Create a module called event_manager" -> scaffold complete module
  - user: "I need a module to handle webhooks" -> scaffold module
  - user: "Scaffold a new custom module" -> scaffold complete module structure
  Never use this for theme scaffolding, contrib module patching, or subthemes.
---

## Environment

All commands run via `docker exec $WEB_CONTAINER`. All modules go in
`$DDEV_DOCROOT/modules/custom/`. **Never hardcode `web/`** — use `$DDEV_DOCROOT`
(detect with `grep "^docroot:" .ddev/config.yaml`).

## Module structure

```
$DDEV_DOCROOT/modules/custom/{module_name}/
├── {module_name}.info.yml
├── {module_name}.module
├── {module_name}.services.yml
├── {module_name}.routing.yml
├── {module_name}.permissions.yml
├── {module_name}.links.menu.yml        # If admin UI needed
├── config/
│   ├── install/                        # Default config
│   └── schema/
│       └── {module_name}.schema.yml    # REQUIRED for all config
├── src/
│   ├── Controller/                     # Route controllers
│   ├── Form/                           # Config and custom forms
│   ├── Service/                        # Business logic services
│   └── Plugin/                         # Block, Field, etc.
└── tests/
    └── src/
        ├── Unit/                       # Pure logic tests
        ├── Kernel/                     # Service integration tests
        └── Functional/                 # Full browser tests
```

## info.yml template

```yaml
name: '{Module Name}'
type: module
description: '{Brief description}'
package: Custom
core_version_requirement: ^10.3 || ^11
php: 8.3
dependencies: []
```

## services.yml template

```yaml
services:
  {module_name}.{service_name}:
    class: Drupal\{module_name}\Service\{ServiceName}
    arguments:
      - '@entity_type.manager'
      - '@logger.factory'
      - '@cache.default'
```

## Controller template

```php
<?php

declare(strict_types=1);

namespace Drupal\{module_name}\Controller;

use Drupal\Core\Controller\ControllerBase;
use Symfony\Component\DependencyInjection\ContainerInterface;

final class {ControllerName} extends ControllerBase {

  public static function create(ContainerInterface $container): static {
    return new static(
      // Inject services here
    );
  }

  public function __construct(
    // Type-hinted constructor parameters
  ) {}

}
```

## Config schema template

```yaml
{module_name}.settings:
  type: config_object
  label: '{Module Name} settings'
  mapping:
    enabled:
      type: boolean
      label: 'Enabled'
```

## Non-negotiable rules

- `declare(strict_types=1)` on every PHP file
- Constructor dependency injection (never `\Drupal::service()`)
- Type hints on ALL parameters and returns
- Config schema for ALL configuration
- 2-space indentation
- Cache metadata on render arrays
- `accessCheck(TRUE)` on all entity queries

## Verification

After scaffolding, enable the module and validate code quality.
**Prefer `drush audit:run`** if the Audit module is installed (see **drupal-audit** skill):

```bash
docker exec $WEB_CONTAINER ./vendor/bin/drush en {module_name} -y

# ALWAYS check for Audit module first (MANDATORY)
docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list

# If installed (PRIMARY — always use this):
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --filter="module:{module_name}" --format=json
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpstan --filter="module:{module_name}" --format=json

# FALLBACK ONLY if Audit module not installed:
docker exec $WEB_CONTAINER ./vendor/bin/phpcs --standard=Drupal,DrupalPractice $DDEV_DOCROOT/modules/custom/{module_name}
docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom/{module_name} --level=8
```

All checks must pass with zero errors before presenting the module to the user.
