## Why

The post editor saves a draft buffer every minute while the form differs from its saved state, and the user reported an empty `draft_id` on the Preview link and draft traffic that never stopped. Four things were wrong with the autosave (PR #1310):

- **The Preview link named no draft.** The permalink widget writes `?draft_id=` into the link as soon as the title yields a slug, which on a new post is before any draft exists. The autosave then created the draft without updating the link, so opening Preview in a new tab, by middle-click or copied link, rendered nothing. A plain click worked only because its handler saves first and rewrites the id.
- **The unchanged form was re-sent every minute.** The timer compared the form with the snapshot taken at page load, which was never refreshed, so after the first edit it sent a `PATCH` every minute with nothing new.
- **The page-load snapshot ran on a two-second timer.** A TinyMCE editor that loaded later rewrote its textarea in its normalized form, so an untouched post read as edited: the timer autosaved it and leaving the page asked to confirm discarding changes never made. The comparison also wrote every editor's content back into its textarea on every run, rewriting content a plugin had put there itself.
- **Each save blocked the page** (`async: false`), freezing the editor for the whole request every minute.

Making the save asynchronous exposed what the blocking save had hidden: a second save could start while the first was in flight (a new post got a second buffer), a post could be submitted while its draft save was in flight (the buffer was never discarded), and a callback could leave a lock held forever.

## What Changes

- **The Preview link is pointed at the draft after every successful save**, into the form the save was sent from; the Preview click opens its window inside the click and sends it to the draft once the save returns, closing it when the save fails.
- **The minute timer compares against the state the last successful save sent**, read after the editors were written into their textareas, and sends nothing before the load baseline exists. The load baseline, which the leave-page prompt reads, is untouched, so an autosaved but never-created post still warns.
- **The load baseline is taken once every TinyMCE editor on the form has initialized** (re-checked on each editor's `init`, given up after ten seconds), on its own timer. The comparison is a read of the form's own editors: textareas are left alone, editors elsewhere on the page are neither compared nor sent, and the draft id field and a translated field's hidden original are left out.
- **Saves are asynchronous and run one at a time.** A save requested while one runs waits for the draft id it returns; a queued timer call with nothing to send is skipped; a queued call runs through the script's own function, so a plugin wrapper runs once per call. A save that has not returned after `App_post.save_timeout_ms` fails. The lock is released when a callback throws or `$.ajax` throws before sending, and the caller's failure handler runs.
- **A refused save** shows its messages as text, runs no success callback, drops a held submit and any timer call queued behind it. **A failed request** (transport error, timeout, non-JSON answer) is reported when the user asked for the save and retried silently when the timer did.
- **A post submitted while a save runs is held** under the loading overlay, before validation or any other listener sees it, until the save and the saves queued behind it finish or `App_post.submit_wait_ms` passes; then the submit is dispatched again in full, to the form it was held on. A refused save keeps the post on the form; a failed request lets it go; a form that left the page is not sent.
- **`window.save_draft` / `App_post.save_draft_ajax`** run their callback when the response arrives, after the call returns, and take a third `on_failure` argument. `App_post.submit_wait_ms` and `App_post.save_timeout_ms` are defaulted only when unset.
- **Save Draft** holds the form under the overlay while its save runs and gives it back when the save is refused or fails.

## Capabilities

### New Capabilities

- `post-editor-draft-autosave`: what the minute autosave sends and when, how the load baseline and the comparison read the form, the asynchronous one-at-a-time save and its public contract, the Preview link and window, and the held submit.

### Modified Capabilities

_None._ `draft-authorization` (the server side of the same endpoint) is unchanged.

## Impact

- **Code:** `app/assets/javascripts/camaleon_cms/admin/_post.js`; a `msg.draft_save_failed` key in every admin JS locale.
- **Specs:** `spec/features/admin/post_draft_autosave_spec.rb` (`:js`), one example per requirement scenario.
- **Ecosystem:** plugin or theme code that calls `window.save_draft` and reads the draft right after the call must read it in the callback. A submit that a plugin delegates from an ancestor (camaleon_admin_ajax submits the post form in place from one on the body) still runs, once, when a held submit is dispatched again.
- **Docs:** `docs/upgrading-to-2.9.5.md` (the asynchronous save section), `CHANGELOG.md`.
- **Out of scope:** parentless buffers from abandoned new posts are still never pruned; a new post's first save that times out client-side but completes on the server leaves one the editor cannot name; the editor still shows no saved indicator.
