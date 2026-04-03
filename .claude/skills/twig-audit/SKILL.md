---
name: twig-audit
description: >-
  Audit Twig templates for anti-patterns: render array drilling, business logic
  in templates, improper |raw usage, missing cache bubbling, component isolation
  issues, incorrect attribute handling. Use when reviewing templates, refactoring
  themes, or modernizing legacy Drupal templates.
allowed-tools: Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Twig Audit

**Principle: Twig is for presentation ONLY. Preprocess handles logic.**

## Anti-Patterns to Detect

### 1. Render Array Drilling (CRITICAL — Breaks Cache)
```twig
{# BAD — loses cache metadata, security risk #}
{{ content.field_image[0]['#markup'] }}
{{ content.field_body['#items'][0]['value'] }}

{# GOOD #}
{{ content.field_image }}
{{ content.body }}
```

### 2. Business Logic in Templates
```twig
{# BAD #}
{% if user.field_role.value == 'premium' and user.field_expiration.value|date('U') > 'now'|date('U') %}
  {% set discount = product.price.value * 0.2 %}

{# GOOD — variable from preprocess #}
{% if has_premium_discount %}
  {{ formatted_discounted_price }}
```

### 3. Unsafe |raw Usage
```twig
{# BAD — XSS vulnerability #}
{{ node.field_user_content.value|raw }}

{# GOOD — use processed field #}
{{ content.field_user_content }}
```

### 4. Missing Component Isolation
```twig
{# BAD — variable contamination #}
{{ include('mytheme:card', {heading: title}) }}

{# GOOD #}
{{ include('mytheme:card', {heading: title}, with_context = false) }}
{% embed 'mytheme:card' with {heading: title} only %}
```

### 5. Content Not Rendered (Loses Cache Metadata)
```twig
{# BAD — cache metadata lost #}
<h1>{{ label }}</h1>
{{ content.body }}

{# GOOD — render remaining with without #}
<h1>{{ label }}</h1>
{{ content.body }}
{{ content|without('body') }}
```

### 6. Direct Entity Access (Bypasses Render System)
```twig
{# BAD — bypasses formatters and cache #}
{{ file_url(node.field_image.entity.uri.value) }}

{# GOOD — render the field properly #}
{{ content.field_image }}

{# Or if you need just the URL, use preprocess #}
{{ image_url }}
```

### 7. Attributes as Strings
```twig
{# BAD #}
<article class="node node--{{ node.bundle }}">

{# GOOD #}
{% set classes = ['node', 'node--' ~ node.bundle|clean_class] %}
<article{{ attributes.addClass(classes) }}>
```

## Component Props vs Slots

| Props (simple values) | Slots (complex content) |
|----------------------|------------------------|
| Titles, labels | Formatted text fields |
| Numbers, booleans | Images, media |
| URLs | Entity references |
| CSS variants | Nested components |

## Correct Adapter Pattern
```twig
{# node--article--teaser.html.twig #}
{% embed 'mytheme:card' with {
  heading: label,
  url: url,
  variant: node.isPromoted ? 'featured' : 'default',
} only %}
  {% block media %}{{ content.field_image }}{% endblock %}
  {% block body %}{{ content.body }}{% endblock %}
{% endembed %}

{# CRITICAL: Render remaining for cache bubbling #}
{{ content|without('field_image', 'body') }}
```

## Move to Preprocess

Flag these as preprocess candidates:
- Entity queries
- Service calls
- Complex calculations
- Permission checks
- Date formatting beyond simple `|date`

## Audit Report Format

### Issues Detected
| Severity | Line | Issue | Risk |
|----------|------|-------|------|
| CRITICAL | 12 | Render array drilling | Broken cache |

### Refactored Code
Complete template with fixes and comments.

### Preprocess Changes
```php
function mytheme_preprocess_node(&$variables) {
  // Required PHP code for logic moved from template
}
```

### Final Checklist
- [ ] No render array drilling
- [ ] content rendered or `|without` used
- [ ] No business logic
- [ ] `|raw` only with trusted data
- [ ] Components isolated
- [ ] Attributes via object
