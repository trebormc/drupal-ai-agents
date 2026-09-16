# Feature map example

Shape for `features/README.md` and one feature file. Replace every value with what the
interviewed repo actually contains. This example is for a fictional site "Agenda".

## `features/README.md`

```markdown
# Agenda verification map

This directory is the maintained source for verifying Agenda's user-facing behavior.
Read this index before driving the site, then use the matching feature file as the
recipe.

## Baseline preconditions

- DDEV is up; `ssh web drush status --fields=bootstrap` prints `Successful`.
- Navigate with Playwright MCP over `$DDEV_HTTP_URL` (HTTP, never HTTPS).
- Admin session: `ssh web drush uli --uri=$DDEV_HTTP_URL`, replace `https://` with
  `http://`, `browser_navigate` the result.
- Editor test user `verify_editor` (role `editor`) exists; create with
  `ssh web drush user:create verify_editor --password=verify && ssh web drush
  user:role:add editor verify_editor` if missing.
- Seed content: an Event node titled `Verify: Concert` published, one unpublished
  `Verify: Draft`.
- Never run two mutating drives at once; one shared site.

## Driving conventions

- Prefer ARIA roles and accessible names (`browser_snapshot` output) over CSS.
- Drupal admin forms: use `data-drupal-selector` when the label is ambiguous.
- Read side effects back with drush, not by trusting the confirmation message.
- Restore seeded data after a mutation. Never delete `screenshots/`.

## Proof and skip reporting

- Capture the action and the resulting state: snapshot after the click, then screenshot
  named `screenshots/<feature-id>-<step>.png`.
- Mutation proof includes a second read-only view of the stored value (`drush php:eval`).
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Features

- [Create an event](./create-event.md) — editor creates, previews, publishes an Event.
- [Event listing](./event-listing.md) — front-page view, filters, pagination, empty state.
- [Site search](./search.md) — header search, results, no-results state.
```

## `features/create-event.md`

```markdown
# Create an event

An editor creates an Event node from the admin UI, sees it in the listing when
published, and does not see it when unpublished.

## Sub-features

- `event-create-form` — /node/add/event renders title, date, venue, body fields.
- `event-validation` — saving without a date shows the field error, no node created.
- `event-publish` — a published event appears on the front-page listing.
- `event-unpublished-hidden` — an unpublished event is absent for anonymous users.

## How to get to it (user POV)

- Admin toolbar → Content → Add content → Event.
- Direct URL `/node/add/event` as `verify_editor`.
- drush: `ssh web drush php:eval` creating a node of type `event` (state only, not UI).

## Driving it with Playwright MCP and drush

Preconditions:

- Logged in as `verify_editor` (`drush uli --name=verify_editor --uri=$DDEV_HTTP_URL`).
- Doctor passed.

- **Open the form.** `browser_navigate $DDEV_HTTP_URL/node/add/event`, then
  `browser_snapshot`. A form with textbox `Title`, group `Date`, textbox `Venue`.
- **Validation.** `browser_type` textbox `Title` = `Verify: No date`, `browser_click`
  button `Save`. Snapshot shows alert containing `Date field is required`;
  `ssh web drush php:eval "var_dump((bool) \Drupal::entityQuery('node')->accessCheck(FALSE)->condition('title','Verify: No date')->count()->execute());"` prints `bool(false)`.
- **Publish.** Fill `Date` with `2030-01-15 20:00`, `Venue` with `Verify Hall`, check
  `Published`, click `Save`. Snapshot shows status `Event Verify: No date has been created`.
  Read back: the same entityQuery prints `bool(true)`; `screenshots/event-create-published.png`.
- **Listing.** Log out (`browser_navigate $DDEV_HTTP_URL/user/logout`), navigate `/`.
  Snapshot lists link `Verify: No date`. `screenshots/event-create-listing.png`.
- **Unpublished hidden.** As editor, edit the node, uncheck `Published`, save; as
  anonymous, `/` no longer lists it.
- **Cleanup.** `ssh web drush php:eval "foreach (\Drupal::entityTypeManager()->getStorage('node')->loadByProperties(['title' => 'Verify: No date']) as \$n) \$n->delete();"`
  then `ssh web drush cr`.

## Gotchas

- The listing is a cached view: after publishing, if the front page does not show the
  node, check `drush cr` was NOT needed — the `node_list` tag must invalidate it; a
  needed `drush cr` is a bug, not a flake.
- Date widget: type the date in the `Date` textbox and the time in `Time`, they are
  two inputs.
- Spanish UI: labels are translations; the accessible names above are the English
  source strings — switch the test user's language to English or use the Spanish
  label observed in the snapshot.
- Anonymous check requires a fresh session; BigPipe may render placeholders — wait for
  the list region, not a fixed sleep.
```
