# Confine draft custom-field options to registered slugs (M8)

## Why

`Posts::DraftsController#create` and `#update` passed `params[:field_options]` straight to
`set_field_values`, so a caller could write `custom_field_values` rows with attacker-chosen slugs,
custom-field ids and group numbers — keys never registered on the post type. #1235 already confined
drafts to the caller's own per-user buffer, so this is a same-user data-integrity deviation rather
than cross-user escalation, but the draft path is the last of M8's four sites still bypassing the
allow-list that `settings_controller` and `posts_controller` already enforce via
`cama_permitted_field_options`. Audit finding M8 (2/4 → 4/4).

### Triage verdict: legit

Both draft actions pass the raw param. Reproduced in
`spec/requests/security/draft_field_options_scope_spec.rb`: a draft save carrying a registered slug
and an unregistered one persists both before the fix; after it, only the registered slug survives.

## What Changes

- `Posts::DraftsController#create` and `#update` now filter `field_options` through
  `cama_permitted_field_options('PostType_Post')` — the same allow-list, object class and helper the
  main post save uses — before handing them to `set_field_values`. Unregistered slugs are dropped;
  registered ones are unchanged.

## Notes for upgraders

- None. The admin draft editor only ever submits registered fields; this rejects hand-crafted
  payloads that named foreign slugs.
