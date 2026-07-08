---
name: drupal-accessibility
description: >-
  Drupal-specific accessibility guidance (WCAG 2.2 AA): Form API auto-generated ARIA,
  #states vs #access semantics, core hiding utilities (visually-hidden, hidden),
  Drupal.announce() and tabbingManager instead of hand-rolled ARIA/live regions/focus
  traps, and the tools-first detection order. Generic web-accessibility advice often
  contradicts Drupal idioms — this skill encodes the Drupal way.
  Examples:
  - user: "make this form accessible" -> Form API idioms, no redundant ARIA
  - user: "accessibility audit of the theme" -> tools-first detection, WCAG 2.2 mapping
  - user: "add a modal/toggle that announces changes" -> Drupal.announce, tabbingManager
  - user: "hide this label visually" -> core hiding utilities decision table
  Never hand-write ARIA that a Drupal API already produces.
allowed-tools: Bash Read Grep Glob
metadata:
  drupal-version: "10.x/11.x"
  environment: "ddev"
---

# Drupal Accessibility

**Baseline: WCAG 2.2 AA.** New in 2.2 and most often missed by generated UI: SC 2.5.8
Target Size — every pointer/touch target at least 24×24 CSS pixels (44px remains the
comfortable standard for primary touch targets).

## Core principle: Drupal idioms over hand-rolled ARIA

Drupal's APIs already emit correct, tested accessibility output. Hand-written ARIA on
top of them is at best redundant and at worst conflicts with what core generates:

| Instead of hand-writing | Use |
|---|---|
| `aria-describedby`/`aria-labelledby` on form fields | Form API `#title`, `#description` — associations are generated |
| `role="navigation"` on `<nav>`, `role="button"` on `<button>`, `role="list"` on `<ul>` | Nothing — native semantics already provide it |
| Custom `aria-live` region | `Drupal.announce('Message', 'polite'|'assertive')` |
| Manual Tab-key trapping in modals | `Drupal.tabbingManager` (`Drupal.tabbingManager.constrain(...)`) |
| Ad-hoc `.sr-only` / custom hiding CSS | Core utilities: see hiding table below |
| Raw HTML strings in `#markup` | Render API `#type` elements (semantic markup for free) |

Semantic HTML5 first; ARIA only fills genuine gaps.

## `#states` is NOT `#access`

`#states` shows/hides via CSS (`display: none`) — the element stays in the DOM and in
form processing. `#access => FALSE` removes it entirely.

- User-driven progressive disclosure (show field B when checkbox A is on) → `#states`.
- Permission-based or unconditional hiding → `#access`. Using `#states` here leaves the
  "hidden" field submittable and processable — an accessibility AND security defect.

## Hiding content correctly

| Utility | Effect | Use for |
|---|---|---|
| `.visually-hidden` | Hidden visually, read by screen readers | Labels/headings that give SR users context |
| `.visually-hidden.focusable` | Appears on keyboard focus | Skip links |
| `.hidden` / `[hidden]` | Hidden from everyone | Content genuinely not available yet |
| `#access => FALSE` | Not rendered at all | Permission-based removal |

Never invent custom hiding CSS — each utility has distinct semantics.

## Frontend checklist (per component)

- Semantic elements and heading hierarchy (h1 → h2 → h3, no skips)
- Alt text on images (`alt=""` only when purely decorative)
- Visible focus styles; logical tab order; no positive `tabindex`
- Color contrast ≥ 4.5:1 (text), ≥ 3:1 (large text, UI components)
- Targets ≥ 24×24 px (WCAG 2.2)
- Dynamic changes announced (`Drupal.announce()`) — not silent DOM swaps
- Forms usable with keyboard only; errors associated with their fields

## Detection order: tools first, eyeballing last

1. **Automated scan first** — reproducible findings with rule IDs beat inspection. In
   this environment, drive the page via the **visual-test** agent (Playwright MCP) and
   check the rendered DOM/snapshot; if the project has `@axe-core/playwright` or
   Lighthouse CI, run those via `ssh web npx ...`.
2. **Manual keyboard/zoom pass** — tab through the flow, 200% zoom, focus visibility.
3. **Code review last** — supplements tool output; never report an accessibility finding
   from reading markup alone when a tool could confirm it (see the epistemic-discipline
   rule: evidence over plausibility).

**Zero automated violations ≠ accessible.** Axe-class tools catch roughly a third of
WCAG issues; keyboard and screen-reader checks remain mandatory for non-trivial UI.

## Testing direction

New browser-level accessibility tests go in **Playwright** (matches this ecosystem's
tooling; Drupal core is moving there and removing Nightwatch — do not extend Nightwatch
coverage). See **drupal-playwright-test** skill.

## What not to do

- Do not add redundant ARIA roles to semantic elements.
- Do not use `#states` for permission-based hiding — `#access`.
- Do not write custom live regions or focus traps — `Drupal.announce()`, `tabbingManager`.
- Do not invent hiding CSS — core utilities only.
- Do not claim "accessible" from a clean automated scan alone — label it: VERIFIED for
  the automated subset, NOT VERIFIED for keyboard/screen-reader behavior unless tested.

## See also

- **drupal-theme** agent — component workflow; **visual-test** agent — browser runs
- [Drupal Accessibility Coding Standards](https://www.drupal.org/docs/getting-started/accessibility/accessibility-coding-standards)
- [Hiding Content Properly](https://www.drupal.org/docs/getting-started/accessibility/hide-content-properly)
- Source knowledge adapted from the community `ai_best_practices` project
  (https://git.drupalcode.org/project/ai_best_practices), based on material by the
  Drupal Core Accessibility Maintainer
