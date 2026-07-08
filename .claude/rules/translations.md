---
description: Translation (i18n) contract — English source strings ALWAYS, wrapped in Drupal translation functions (t/$this->t, |t/trans, Drupal.t) in PHP, Twig, and JavaScript; literal strings and placeholders only
---

# Translations (i18n)

**The contract: source strings are ALWAYS English.** Drupal's translation layer renders
every other language. The English string is the lookup key for `.po` files,
localize.drupal.org, and interface translation — a non-English source string breaks that
chain and mixes languages in the UI forever.

## The leak this rule exists to stop

The conversation language is NOT the code language. When the user (talking in Spanish)
asks for a button labeled "Gestión de usuarios":

```php
// WRONG — conversation language leaked into the source string:
'#title' => $this->t('Gestión de usuarios'),

// RIGHT — English source; the Spanish label arrives via translation:
'#title' => $this->t('User management'),
```

Translate the requested text to English for the source string, and tell the user their
original wording is the TRANSLATION — offer to register it (interface translation UI at
`/admin/config/regional/translate`, or a `.po` file / config translation for shipped
config). Never silently drop the user's wording; never put it in the source.

## PHP

- Classes: `$this->t()` (via `StringTranslationTrait` or injected `string_translation`).
  Procedural code (`.module`, `.install`): global `t()`. Plugin annotations:
  `@Translation("...")`. No DI available (rare): `new TranslatableMarkup()`.
- **Literal strings only** inside `t()` — never variables, never concatenation, never
  interpolation. Extraction tools and translators need the complete literal:

```php
// WRONG — untranslatable and unextractable:
$this->t('Delete ' . $type);
$this->t($message);

// RIGHT — placeholders:
$this->t('Delete @type', ['@type' => $type]);
```

- Placeholders: `@var` (escaped), `%var` (escaped + emphasized), `:var` (URLs). The D7
  `!var` does not exist in D10/11.
- Counts: `$this->formatPlural($count, '1 item', '@count items')` — never an `if` on
  the number.
- **Do NOT translate**: exception messages, logger/watchdog messages (pass the English
  string with placeholders straight to the logger — dblog translates at display time),
  machine names, CSS classes, array keys, config keys.
- YAML (`.info.yml`, `.routing.yml` titles, `.permissions.yml`, `.links.menu.yml`):
  plain English strings, NO `t()` — Drupal translates these keys automatically.

## Twig

```twig
{{ 'User management'|t }}
{{ 'Delete @type'|t({'@type': type}) }}
{% trans %}1 item{% plural count %}@count items{% endtrans %}
```

- `|t` on every user-facing literal. NEVER `|t` on a variable (`{{ title|t }}`) — the
  content is not a literal key; if the value needs translating it must be translated
  where it is defined.

## JavaScript

```javascript
const label = Drupal.t('User management');
const msg = Drupal.t('Delete @type', {'@type': type});
const items = Drupal.formatPlural(count, '1 item', '@count items');
```

Same rules: English literals, placeholders, no concatenation. Requires the library to
depend on `core/drupal`.

## Config

- Shipped config (`config/install/`): English values; translations go in
  `config/optional/language/` or via config translation.
- Schema: human-readable strings use type `label` (translatable), not `string` — see
  the **config-management** skill.

## Detection — audit generated or existing code

```bash
# Non-English (accented/ñ/¿¡) source strings inside t()/Drupal.t() — PHP and JS:
grep -rnP "(->t\(|[^a-zA-Z]t\(|Drupal\.t\()\s*['\"][^'\"]*[áéíóúñüç¿¡àèìòù]" \
  $DDEV_DOCROOT/modules/custom/ $DDEV_DOCROOT/themes/custom/ 2>/dev/null

# Same, for Twig (the literal comes BEFORE the |t filter):
grep -rnP "['\"][^'\"]*[áéíóúñüç¿¡àèìòù][^'\"]*['\"]\s*\|\s*t" \
  $DDEV_DOCROOT/modules/custom/ $DDEV_DOCROOT/themes/custom/ 2>/dev/null

# Variables or concatenation inside t():
grep -rnP "(->t|[^a-zA-Z]t|Drupal\.t)\(\s*(\\\$|['\"][^'\"]*['\"]\s*\.)" \
  $DDEV_DOCROOT/modules/custom/ 2>/dev/null
```

These greps are heuristics (they catch accented characters, not all languages) — a hit
on YOUR changed code must be fixed before presenting the work; a clean run does not
replace reading your strings.
