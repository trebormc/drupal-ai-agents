---
name: drupal-render-pipeline
description: >-
  Expert reference for Drupal's render pipeline: render arrays vs Response objects,
  cache metadata semantics (minimum-wins max-age bubbling, cache keys), CacheableMetadata,
  cases where bubbling does NOT happen (AccessResult, #access booleans, config overrides),
  lazy builder constraints, two-phase tag invalidation, #markup vs #plain_text escaping,
  and rendering outside HTTP requests. These are the caching bugs that work in development
  and break in production.
  Examples:
  - user: "my block shows another user's content" -> cache context/lazy builder diagnosis
  - user: "the whole page stopped being cached" -> max-age 0 bubbling, lazy builder fix
  - user: "build a JSON endpoint" -> CacheableJsonResponse guidance
  - user: "content is stale after saving" -> tag bubbling / bypassed render system
  Never use for generic performance measurement (use performance-audit) or Twig-level
  issues (use twig-audit).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Render Pipeline — Expert Rules

Basics (tags/contexts/max-age snippets, N+1) live in the **performance-audit** skill and
the **drupal-coding-standards** rule. This skill covers the semantics that AI-generated
code most often gets wrong — bugs that are invisible in development (cache disabled)
and surface only in production.

## Render arrays, not HTML strings or Response objects

An HTML page controller must return a render array. Returning `new Response($html)` or a
concatenated string detaches the output from the render system: cache metadata from
children is silently lost and the page becomes uncacheable or caches wrong.

- Return a `Response` only when intentionally bypassing rendering (file downloads).
- JSON endpoints: use `CacheableJsonResponse` and add cacheable dependencies —
  a plain `JsonResponse` carries no cache metadata.

## Max-age bubbles minimum-wins — the reason lazy builders exist

Cache metadata propagates UP the render tree, and `max-age` takes the MINIMUM along the
way: a single child with `max-age: 0` forces the entire page to be uncacheable. So never
place personalized content (username, cart count, per-user messages) directly in a render
array — isolate it in a lazy builder so the rest of the page stays cached:

```php
$build['greeting'] = [
  '#lazy_builder' => ['mymodule.greeting_builder:build', [$account_id]],
  '#create_placeholder' => TRUE,
];
```

**Lazy builder arguments must be scalars** (string, int, float, bool, NULL). They are
serialized into placeholder markup — passing an entity or array throws. Pass the entity
ID, load inside the builder. This is one of the most frequent AI-generated bugs.

BigPipe consumes these placeholders in production (streams the page, fills placeholders
via chunked transfer). Rendering a placeholder to a string early defeats it.

## Cache keys vs bubbling

`#cache['tags'|'contexts'|'max-age']` describe the metadata that bubbles up. Only
`#cache['keys']` makes the render array ITSELF independently stored in the render cache.
Without keys, the array is re-built every time its parent is — its metadata still bubbles.

## Use CacheableMetadata for non-trivial merges

For merging cacheability across render arrays, `AccessResult` objects, or config
overrides, use the value object instead of hand-editing `#cache` keys — it implements
correct merge semantics (union of tags/contexts, minimum max-age):

```php
$meta = CacheableMetadata::createFromRenderArray($build);
$meta->addCacheableDependency($node);
$meta->addCacheContexts(['user.permissions']);
$meta->applyTo($build);
```

## Where bubbling does NOT happen (explicit attachment required)

- **`AccessResult`**: an access check that varies by permission must declare it —
  `AccessResult::allowedIfHasPermission($account, 'x')` handles it; a hand-built result
  needs `->cachePerPermissions()` / `->addCacheableDependency()`. Otherwise the access
  DECISION gets cached without its variation — a security-grade caching bug.
- **`#access` with a plain boolean** conveys no cacheability. If the decision came from
  something that varies (permission, entity state), pass the `AccessResult` object itself
  to `#access`, not `->isAllowed()`.
- **Config overrides** and **entity language negotiation** declare their own
  contexts/tags — they are outside the render tree.
- Anything that bypasses the render system (raw HTML, string concatenation) drops the
  whole subtree's metadata.

## Tag invalidation is two-phase — do not expect deletion

Invalidating a tag updates a checksum immediately; stale items are NOT physically deleted.
The next read sees a checksum mismatch and returns a miss. Never write code that expects
the cache backend to be empty after invalidation, and never "verify" invalidation by
inspecting the backend for the item's absence — verify by observing a fresh read.

## Escaping: #markup vs #plain_text vs Markup::create()

| Element | Behavior | Use for |
|---|---|---|
| `#plain_text` | Fully escaped | User-generated content — always |
| `#markup` | Filtered through `Xss::filterAdmin()` (allows many tags) | Trusted admin HTML only |
| `Markup::create()` / `t()` results | **Bypass the XSS filter entirely** (MarkupInterface) | Never on user input |
| `#type => 'inline_template'` | Twig autoescaping applies | Small dynamic HTML fragments |

Wrapping user input in `Markup::create()` to silence escaping is a real XSS vulnerability
that looks like a fix. Prefer Render API `#type` elements over raw HTML in `#markup`.

## Rendering outside an HTTP request

In queue workers, Drush commands, cron, and mails, use
`\Drupal::service('renderer')->renderInIsolation($build)` (D10.3+; formerly
`renderPlain()`) instead of `render()` — regular rendering tries to bubble metadata into
a request context that does not exist ("leaked metadata" errors).

## What not to do

- Do not return `Response`/strings from HTML controllers — metadata is lost.
- Do not put personalized content inline — one `max-age: 0` uncaches the whole page.
- Do not pass entities/arrays to lazy builders — scalars only.
- Do not pass `->isAllowed()` booleans to `#access` when the result varies — pass the
  `AccessResult`.
- Do not use `#markup` (or `Markup::create()`) for user input — `#plain_text`.
- Do not expect invalidated items to be physically gone — invalidation is lazy.
- Do not attach tags to arrays outside the rendered tree — they never bubble.

## Verification in this environment

```bash
# See cacheability of a page (headers require debug_cacheability_headers: true
# in development.services.yml — see drupal-debugging skill):
ssh web curl -s -o /dev/null -D - http://localhost/PATH | grep -i "x-drupal-cache\|cache-tags\|cache-contexts"

# Confirm a tag invalidation produces a fresh read:
ssh web drush php:eval "\Drupal::service('cache_tags.invalidator')->invalidateTags(['node:1']);"
```

## See also

- **performance-audit** skill — measurement, N+1 detection, caching checklist
- **twig-audit** skill — template-level cache bubbling
- Source knowledge adapted from the community `ai_best_practices` project
  (https://git.drupalcode.org/project/ai_best_practices) and Drupal Render API docs
