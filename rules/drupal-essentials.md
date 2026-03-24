# Drupal Development Essentials

## Non-Negotiable Standards

```php
<?php
declare(strict_types=1);  // ALWAYS first line after <?php
```

| Rule | Requirement |
|------|-------------|
| Indentation | 2 spaces |
| Type hints | ALL parameters and returns |
| DI | Constructor injection, never `\Drupal::service()` in classes |
| Cache | Metadata on ALL render arrays |
| Debug code | NEVER commit: `dpm()`, `kint()`, `dump()`, `console.log()` |

## Security Essentials

```php
// Input sanitization
Html::escape($userInput);           // Plain text
Xss::filter($userInput);            // Limited HTML
UrlHelper::filterBadProtocol($url); // URLs

// Database - ALWAYS placeholders
$db->query("SELECT * FROM {users} WHERE name = :name", [':name' => $input]);

// Translations
$this->t('Hello @name', ['@name' => $username]);  // @=escape, :=URL, %=em+escape
```

## Cache Metadata (Required on ALL render arrays)

```php
return [
  '#theme' => 'my_template',
  '#data' => $data,
  '#cache' => [
    'tags' => ['node:123', 'node_list'],      // WHAT data
    'contexts' => ['user.permissions'],        // WHEN to vary
    'max-age' => 3600,                         // HOW LONG (avoid 0!)
  ],
];
```

## Query Best Practices

```php
// GOOD - batch load
$nodes = Node::loadMultiple($nids);

// GOOD - with limits
$query = $storage->getQuery()
  ->accessCheck(TRUE)      // REQUIRED
  ->condition('status', 1)
  ->range(0, 50);          // ALWAYS limit

// BAD - N+1 queries
foreach ($nids as $nid) { $node = Node::load($nid); }
```

## Route Access

```yaml
# Permission-based
requirements:
  _permission: 'access content'

# Entity access
requirements:
  _entity_access: 'node.update'

# CSRF for state-changing
requirements:
  _csrf_token: 'TRUE'
```

## DDEV Commands (via docker exec)

**Use `$DDEV_DOCROOT` instead of hardcoding `web/`.** Detect with: `grep "^docroot:" .ddev/config.yaml`

```bash
# In OpenCode container, ALL commands via:
docker exec $WEB_CONTAINER ./vendor/bin/drush cr

# Code quality — ALWAYS check for Audit module first (MANDATORY)
# Step 0: docker exec $WEB_CONTAINER ./vendor/bin/drush pm:list --filter=audit --format=list
# If installed (PRIMARY — always use this):
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpcs --filter="module:mymodule" --format=json
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpstan --filter="module:mymodule" --format=json
docker exec $WEB_CONTAINER ./vendor/bin/drush audit:run phpunit --filter="module:mymodule" --format=json

# FALLBACK ONLY if Audit module not installed:
docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse $DDEV_DOCROOT/modules/custom --level=8
docker exec $WEB_CONTAINER ./vendor/bin/phpcs $DDEV_DOCROOT/modules/custom
docker exec $WEB_CONTAINER ./vendor/bin/phpunit $DDEV_DOCROOT/modules/custom/mymodule
```

## Quality Checklist

Before completing ANY task:
- [ ] `declare(strict_types=1)` present
- [ ] All type hints complete
- [ ] DI used (no static `\Drupal::` calls in classes)
- [ ] Cache metadata on render arrays
- [ ] No debug code
- [ ] PHPStan level 8 clean
- [ ] PHPCS clean
