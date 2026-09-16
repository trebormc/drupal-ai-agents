---
name: drupal-blast-radius
description: >-
  Finds what a Drupal change could break OUTSIDE the diff (hook implementers, service
  decorators, template overrides, views and displays using a field, config
  dependencies, cache tag consumers, tests) and proves the one fact the change is safe
  because of by running real code, not by writing it up. Use before shipping a change
  to shared code, during refactoring, or when reviewing a small diff you do not trust.
  Examples:
  - user: "what could this change break?" -> map consumers, prove the safety fact
  - user: "¿qué más afecta si cambio este servicio?" -> consumer map + proof
  - user: "is it safe to rename this field?" -> views/displays/config/twig sweep + proof
  - user: "blast radius of this hook change" -> implementer/alter sweep + proof
  Never use to review code quality (code-review agent) or to locate code (code-explorer).
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Blast Radius

Listing the callers is not the job — `code-explorer` greps those in a second. The job
is the breakage grep will not show you, plus a proof. All PHP via `ssh web`.

## Step 1 — Read the change

The diff, the symbols it adds/changes/deletes, and what it now does differently,
including what the diff does not spell out (a changed return type, a cache tag no
longer added, a hook no longer invoked). One paragraph.

## Step 2 — Find the one fact it is safe because of

Most risky-looking changes are safe because of ONE fact ("no code outside this module
calls `getItems()` with a non-array", "this template is not overridden by any theme",
"the field is only displayed through the default view mode"). Name that fact. If it
holds, most risks clear at once; spend your effort there, not on a long list of
maybes.

## Step 3 — Sweep where grep stops (Drupal consumer map)

Run only the rows the change touches. Always state which rows you ran.

| Changed thing | Consumers that break silently | How to find them |
|---|---|---|
| Hook implementation / invocation | Other modules implementing the same hook or altering its output | `grep -rn "function [a-z_]*_HOOKNAME(" $DDEV_DOCROOT/modules $DDEV_DOCROOT/themes`; check `hook_module_implements_alter` ordering |
| Service | Decorators, `services.yml` aliases, `ServiceProvider` classes, event subscribers, other services with it as an argument | `grep -rn "'@SERVICE_ID'\|decorates: SERVICE_ID" $DDEV_DOCROOT/modules --include=*.yml`; `ssh web drush php:eval "print_r(get_class(\Drupal::service('SERVICE_ID')));"` (a decorator shows up here, grep does not) |
| Field or base field | Views, entity form/view displays, field formatters/widgets, config entities referencing it, Twig `content.field_x` | `grep -rln "FIELD_NAME" config/sync/` (views.view.*, core.entity_*_display.*), `grep -rn "field_x\|\.field_x" $DDEV_DOCROOT/themes --include=*.twig` |
| Config key or schema | `dependencies:` in other config, config_split overrides, `settings.php` overrides, `hook_update_N` that already migrated it | `grep -rln "CONFIG_NAME" config/`; `ssh web drush config:get CONFIG_NAME` (active DB value may differ from sync) |
| Template / theme hook | Theme overrides, suggestions (`hook_theme_suggestions_*`), preprocess functions, `#theme` usages in PHP | `find $DDEV_DOCROOT/themes -name "TEMPLATE*.html.twig"`; `grep -rn "'#theme' => 'HOOK'\|template_preprocess_HOOK\|_preprocess_HOOK" $DDEV_DOCROOT/modules $DDEV_DOCROOT/themes` |
| Route / permission | Menu links, local tasks/actions, access checks, tests asserting 403/200, `Url::fromRoute` callers | `grep -rn "ROUTE_NAME" $DDEV_DOCROOT/modules --include=*.yml --include=*.php`; `ssh web drush route --name=ROUTE_NAME` |
| Cache tags / contexts | Render arrays that relied on the tag for invalidation, `CacheableMetadata` merges, custom cache bins | `grep -rn "TAG_NAME" $DDEV_DOCROOT/modules`; then Step 4 proves invalidation live |
| Plugin ID / annotation | Config storing the plugin ID (blocks, field types, views plugins), `plugin.manager` alters | `grep -rln "PLUGIN_ID" config/sync/ $DDEV_DOCROOT/modules` |
| Entity API / return type | Callers in other modules, JSON:API/REST consumers, migrations, tests | `grep -rn "->METHOD(" $DDEV_DOCROOT/modules/custom` plus core/contrib if the class is theirs |
| Twig variable | Templates in ALL themes (admin theme too), `#attached` JS reading `drupalSettings` | `grep -rn "VARIABLE" $DDEV_DOCROOT/themes --include=*.twig --include=*.js` |
| Contrib patch / version | Other patches in `composer.json` targeting the same file, `hook_update_N` that assumed the old behavior | `grep -n "patches" -A 30 composer.json`; `ssh web composer show drupal/MODULE` |

Also check timing: a hook that runs at `hook_entity_presave` sees different state than
`hook_entity_insert`; a preprocess runs after access checks; a `#lazy_builder` runs
after the page cache decision. Say when the changed code runs.

## Step 4 — Prove the safety fact by running code

For each fact the change's safety depends on, get it as far down this ladder as is
cheap, and say where it stopped:

1. You said so — worthless alone.
2. You pointed at the line — `file:line` in project, core, or contrib source.
3. You walked the failure step by step and it cannot reach.
4. **You ran it** — a script or test that calls the real code and fails loud if you are
   wrong.
5. You reproduced the risky scenario in the running site.

Step 4 is usually one small check:

```bash
# Who really implements/alters the hook at runtime (includes contrib you did not grep)
ssh web drush php:eval "print_r(\Drupal::moduleHandler()->getImplementations('HOOK'));"
# Actual service class after decoration
ssh web drush php:eval "echo get_class(\Drupal::service('SERVICE_ID'));"
# Does any view use the field
ssh web drush php:eval "foreach (\Drupal::entityTypeManager()->getStorage('view')->loadMultiple() as \$v) { if (str_contains(json_encode(\$v->toArray()), 'FIELD_NAME')) echo \$v->id().PHP_EOL; }"
# Cache tag consumers still invalidate: change, then check the render cache entry is gone
ssh web drush php:eval "\Drupal::service('cache_tags.invalidator')->invalidateTags(['TAG']);"
# Config dependents
ssh web drush php:eval "print_r(\Drupal::service('config.manager')->findConfigEntityDependencies('config', ['CONFIG_NAME']));"
```

A fact you cannot get to step 4 stays labeled **UNPROVEN** in the report. Do not
write it up as settled.

## Step 5 — Report

```
## Blast radius: <change, one line>

**What it does** (including the non-obvious part)
**The one safety fact**: <fact> — proven at ladder step N: <command + output, or UNPROVEN>
**Risks (real ones only)**: each = how it breaks, file:line, likely/unlikely, cost, how to check
**Cleared**: what you checked and why it is fine (rows of the consumer map you ran)
**Before you ship**: the cheapest test or repro that catches the real bug — the script you wrote, kept in the summary
```

Cite real `file:line`; a search that finds nothing is still an answer (say where you
searched); never invent a caller. Label claims VERIFIED / INFERRED per the
**epistemic-discipline** rule.
