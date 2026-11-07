---
description: Twig template patterns — cache bubbling, attributes, escaping, no business logic
paths:
  - "**/templates/**/*.twig"
  - "**/themes/custom/**/*.twig"
  - "**/modules/custom/**/*.twig"
---

# Twig Patterns

## Core Rules

- **Twig is for presentation ONLY** — logic goes in preprocess functions
- **Render full fields** — never drill into render arrays (breaks cache)
- **Use `content|without()`** — render remaining fields for cache bubbling
- **Use `|t`** for ALL user-facing strings
- **No inline CSS/JS** — use the libraries system

## Correct Patterns

```twig
{# GOOD: Render full field for cache metadata #}
{{ content.field_image }}

{# GOOD: Exclude already-rendered fields #}
{{ content|without('field_image', 'body') }}

{# GOOD: Attributes object #}
{% set classes = ['node', 'node--' ~ node.bundle|clean_class] %}
<article{{ attributes.addClass(classes) }}>
```

## Anti-Patterns

```twig
{# BAD: Drilling into render arrays — BREAKS CACHE #}
{{ content.field_image[0]['#markup'] }}

{# BAD: Business logic in Twig #}
{% if user.field_role.value == 'premium' %}

{# BAD: Unsafe raw usage #}
{{ node.field_user_content.value|raw }}

{# BAD: Attributes as strings #}
<article class="node node--{{ node.bundle }}">
```

Whitespace: Twig removes the single newline right after a `%}` or `#}`, so a tag that ends a
line joins the next line (for example a `{% endfor %}` before an `<input>` in an
`inline_template`). When the markup must stay byte-identical, compare rendered output.

## Component Isolation

```twig
{# GOOD: Isolated context #}
{% embed 'mytheme:card' with {heading: title} only %}
  {% block media %}{{ content.field_image }}{% endblock %}
{% endembed %}
{{ content|without('field_image') }}
```
