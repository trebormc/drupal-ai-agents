---
description: Drupal services.yml conventions — DI, service definitions, tagging
globs:
  - "**/*.services.yml"
---

# Services Conventions

## Service Definition

```yaml
services:
  mymodule.my_service:
    class: Drupal\mymodule\Service\MyService
    arguments:
      - '@entity_type.manager'
      - '@logger.factory'
      - '@cache.default'
```

## Rules

- **One service per class** — follow single responsibility principle
- **Use interfaces** for services that may have alternative implementations
- **Inject dependencies** — never use `\Drupal::service()` in service classes
- **Use factory pattern** for complex initialization
- **Tag services** when they need to be discovered (event subscribers, plugins)

## Event Subscribers

```yaml
  mymodule.event_subscriber:
    class: Drupal\mymodule\EventSubscriber\MySubscriber
    tags:
      - { name: event_subscriber }
```

## Access Checkers

```yaml
  mymodule.access_checker:
    class: Drupal\mymodule\Access\MyAccessCheck
    tags:
      - { name: access_check, applies_to: _my_access_check }
```
