# Roll back a refused draft save

## Why

The post editor saves a draft buffer by XHR: each minute, and for Save Draft and Preview. A draft
buffer is a post row with the status `draft_child`. `CamaleonCms::Admin::Posts::DraftsController`
stored the draft row, its metas, its categories and its tags first. Then it stored the custom-field
values and the options, with no transaction.

Camaleon refuses a custom-field value with unsafe content, and custom-field `values` in a shape
that the shared permit cannot read. The draft save then answered with a 422 and no draft id, but
the draft row, its metas, its categories and its tags stayed.

The editor of a new post got no draft id. So each later save of that editor created one more draft
row, and the Drafts list of the post type showed each of them. A refused update of a draft stored
the new attributes, metas, categories and tags beside the old options and custom-field values.

## What Changes

- The draft create and the draft update write in one transaction, as the post save does. The
  transaction holds the draft row, its metas, its categories, its tags, its custom-field values and
  its options.
- A refused draft save stores nothing. A draft create stores no draft row. A draft update, and a
  draft create on a buffer that exists, keep the buffer as stored.
- The answer does not change: the refusal as text with a 422. The post editor shows it in its alert.
- `docs/upgrading-to-2.9.5.md` says what a refused draft save stores now, and where the draft rows
  of the earlier refusals show.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: the requirement "A refused value rolls the save back and surfaces
  as an error" now holds for the draft save too.

## Impact

- `app/controllers/camaleon_cms/admin/posts/drafts_controller.rb`: the transaction.
- `app/controllers/camaleon_cms/admin_controller.rb`: the comment of
  `rescue_from ActiveRecord::RecordInvalid`.
- Specs: a new request spec, and three specs that expected the draft row to stay.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- Ecosystem: the four draft hooks run at the same points of a save that passes (design D3). No
  surveyed plugin or theme uses them.
