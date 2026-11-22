# Design

## Context

See `proposal.md`, "Why". The archived change
`2026-11-20-refuse-field-values-that-the-permit-does-not-keep` recorded the old rule in its design
D4: a refused draft save keeps what it stored before the custom-field values. The review of that
change found the draft row that a refused draft create leaves. This change replaces that rule for
the draft save.

`PostsController#save_post_with_fields` stores a post, its metas, its custom-field values and its
options in one transaction. The draft save calls the same writer of the metas, values and options
(`PostsController#save_post_params`), but after a save of its own.

## Goals / Non-Goals

**Goals:**

- A refused draft create stores no draft row and no meta.
- A refused draft update keeps the draft as stored.
- The answer to the post editor does not change.

**Non-Goals:**

- The other admin saves that store their record before the custom-field values, such as the
  category save. They keep the rule of D4 of the archived change.
- The removal of the draft rows that earlier refusals left (D4).

## Decisions

**D1. The draft save writes in one transaction.** `DraftsController#save_draft_with_fields` opens
`ActiveRecord::Base.transaction`, saves the draft with `save(validate: false)` and calls
`save_post_params`. A refusal raises through the transaction, which rolls back. The `rescue_from` of
`AdminController` then answers as before. Both actions call the method.

- *Alternative: a keyword for `save(validate: false)` on `save_post_with_fields`.* Rejected: that
  method also takes the attributes of a post update, which the draft save assigns before its hook.

**D2. A refused draft update rolls back too.** The update has no draft row to lose. But without the
transaction it stored the new attributes, metas, categories and tags beside the old options and
custom-field values. A refused meta or option already stores nothing of a draft save, so the two
refusals now agree.

- *Alternative: keep the attributes of a refused update, so that the buffer holds the typed text.*
  Rejected: the editor keeps the post on the form with its text, and it shows the refusal. The
  buffer then holds the last save that passed, not a mix of two saves.

**D3. The hooks stay outside the transaction.** `create_post_draft` and `update_post_draft` run
before it. `created_post_draft` and `updated_post_draft` run after the commit. The post save orders
its hooks in the same way. A write that a handler of the first two hooks makes stays when the save
is refused, as it does for the post save.

A draft create on a buffer that exists stores the status of the buffer as the option
`draft_status`. That write moves into the transaction, so it now comes after `create_post_draft`. A
refused save then leaves no such option, as a refused meta or option leaves none. Camaleon reads
the option only in the sidebar of the post form. No sibling checkout uses the option or one of the
four hooks.

**D4. The draft rows of earlier refusals stay.** A row that a refusal left has the same columns as
the buffer of a new post that its author still writes. So no task can select only the rows of the
refusals. The Drafts list of the post type shows each of them. Their author, with the Delete
permission of the post type, can move them to the trash there and delete them in the Trash list
(`docs/upgrading-to-2.9.5.md`).

## Risks / Trade-offs

- A handler of `create_post_draft` can read the option `draft_status` of the buffer. It gets no
  value on the first save of that buffer → no surveyed plugin or theme has such a handler (D3).
- A refused update no longer stores the typed title and content → the form keeps them. The timer
  sends the form again after the next change (D2).
