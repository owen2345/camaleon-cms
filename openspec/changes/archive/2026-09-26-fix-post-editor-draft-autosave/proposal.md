## Why

The post editor saves a draft buffer every minute while the form has changed. The user reported an empty `draft_id` on the Preview link and draft traffic that never stopped. Four defects (PR #1310):

- **The Preview link named no draft.** The permalink widget writes `?draft_id=` into the link before a new post has a draft; the autosave created the draft without updating the link, so Preview opened in a new tab showed nothing.
- **The unchanged form was re-sent every minute.** The timer compared with the page-load snapshot, which was never refreshed.
- **The snapshot ran on a two-second timer.** A TinyMCE editor loading later normalized its textarea, so an untouched post read as edited: it was autosaved, and leaving the page asked to confirm changes never made. The comparison also wrote every editor back into its textarea, rewriting content a plugin had put there.
- **Each save blocked the page** (`async: false`).

Making the save asynchronous exposed what the blocking save had hidden: overlapping saves (a second buffer for a new post), a submit during a save (the buffer never discarded), and a throwing callback holding the lock forever.

## What Changes

- **The Preview link is pointed at the draft after every successful save**, into the form the save was sent from. The Preview click opens its window inside the click and sends it to the draft once the save returns, closing it if the save fails.
- **The timer compares against what the last successful save sent**, read after the editors were written into their textareas, and sends nothing before the load baseline exists. The baseline, which the leave-page prompt reads, stays, so an autosaved but never-created post still warns.
- **The baseline is taken once every editor on the form has initialized** (re-checked on each `init`, ten seconds at most), on its own timer. The comparison reads the editors without writing their textareas, ignores editors elsewhere on the page, and leaves out the draft id and a translated field's hidden original.
- **Saves are asynchronous and run one at a time.** A save requested during one waits for its draft id; a queued timer call with nothing to send is skipped; queued calls run through the script's own function, so a plugin wrapper runs once per call. A save fails after `App_post.save_timeout_ms`. The lock is released when a callback throws or `$.ajax` throws, and the failure handler runs.
- **A refused save** shows its messages as text, runs no callback, drops a held submit and the timer calls behind it. **A failed request** is reported when the user asked for the save, retried silently when the timer did.
- **A post submitted while a save runs is held** under the overlay, before validation or any other listener sees it, until the save and its queued saves finish or `App_post.submit_wait_ms` passes (the save is aborted then); the submit is then dispatched again in full. A refused save keeps the post on the form; a failed request lets it go; a form that left the page is not sent.
- **`window.save_draft` / `App_post.save_draft_ajax`** run their callback when the response arrives and take a third `on_failure` argument. `App_post.submit_wait_ms` and `App_post.save_timeout_ms` are defaulted only when unset.
- **Save Draft** holds the form under the overlay while it saves and gives it back when the save is refused or fails. Clicked on a post form loaded in place before the editor was set up on it, it waits for that setup, five seconds at most, and saves that form. A Save Draft or Preview call a wrapper on `App_post.save_draft_ajax` never passes on fails, at once when the wrapper throws and otherwise after `App_post.save_timeout_ms`, so the overlay comes down and Preview's window closes.
- **A save belongs to the form it was sent from.** Pages load in place, so a save can return, or wait in the queue, after its form left the page for another post form or for a page without one. Its answer is written into the form it was sent from; a call made or still queued for the form that left is dropped, its failure handler run; Save Draft returning for it leaves the page alone; a refusal or failure is shown prefixed with the post's title; and only the overlay that form put up is taken down.

## Capabilities

### New Capabilities

- `post-editor-draft-autosave`: what the timer sends and when, the baseline and the comparison, the asynchronous one-at-a-time save and its public contract, the Preview link and window, and the held submit.

### Modified Capabilities

_None._ `draft-authorization` (the server side of the same endpoint) is unchanged.

## Impact

- **Code:** `app/assets/javascripts/camaleon_cms/admin/_post.js`; a `msg.draft_save_failed` key in every admin JS locale.
- **Specs:** `spec/features/admin/post_draft_autosave_spec.rb` (`:js`), one example per requirement scenario.
- **Ecosystem:** `docs/ai/ecosystem.md` lists no consumer of `window.save_draft`, `App_post.save_draft_ajax` or `App_post.save_draft`, so the change goes ahead on the engine's merits. Code that reads the draft right after `window.save_draft` must read it in the callback. A submit listener a plugin delegates from an ancestor (camaleon_admin_ajax) still runs, once, when a held submit is dispatched again.
- **Docs:** `docs/upgrading-to-2.9.5.md` (the asynchronous save section), `CHANGELOG.md`.
- **Out of scope:** parentless buffers are still never pruned (abandoned new posts; a first save that timed out client-side, or was aborted by the fallback wait, but completed on the server); no saved indicator. Left as they are by decision (design.md, Risks): a `$.ajax` wrapper that returns no jqXHR cannot be aborted; an editor outside the form naming it with `form=` is compared through its textarea.
