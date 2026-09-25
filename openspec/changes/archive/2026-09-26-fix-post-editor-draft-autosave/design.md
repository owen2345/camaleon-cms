## Context

See proposal.md for the defects. The pieces this change touches, as they stood on `master`:

- **`cama_init_post`** (`admin/_post.js`) runs once per post form, 100 ms after the page's DOM is ready, and closes over the post id, the draft id and the drafts path. Admin pages load in place (camaleon_admin_ajax replaces `#admin_content`), so the script can be set up again on another form while a request from the previous one is in flight; `App_post` and `$form` are globals the newest setup owns.
- **The save** serialized the form, posted it with `async: false`, wrote the draft id into `#post_draft_id` and ran the caller's callback before returning. The minute timer, Save Draft, Preview and `window.save_draft` (plugins) all went through it.
- **The comparison** (`get_hash_form`) wrote each TinyMCE editor's content into its textarea, triggered `change`, and serialized the form; it ran on every timer tick and in the leave-page prompt. The load snapshot was taken on a two-second timer.
- **The submit handler** (bound one second after setup, after jQuery validate's) marked the form submitted so the leave-page prompt stays quiet; the server discards the new post's buffer named by `post[draft_id]` on create.
- **TinyMCE 4** keys `tinymce.editors` by index and by id, fires `AddEditor` when an editor is created and `init` on the editor once it is usable, normalizes the textarea's content when it comes up, and patches the form element's `submit` to save its editors.

## Goals / Non-Goals

**Goals:**
- The Preview link names the draft however it is opened; an unchanged form is not re-sent; an untouched post neither autosaves nor prompts on leave; the editor never freezes for a save.
- Every path the blocking save serialized by accident (a second save, a submit, a callback that throws) has a stated outcome, and none can leave the editor unable to save, preview or submit.
- Plugin content in an editor's textarea, plugin editors elsewhere on the page and plugin wrappers around the save are left as they are.

**Non-Goals:**
- **Pruning parentless draft buffers** (abandoned new posts, a first save that timed out client-side and completed on the server): a server-side concern, listed as a follow-up.
- **A saved indicator** in the editor.
- **A server-side change:** the drafts endpoint and `draft-authorization` are untouched.

## Decisions

### D1. One asynchronous save at a time, with a queue

The save is asynchronous; a lock (`saving`) admits one request at a time and a call made meanwhile is queued with its arguments. The queue is drained when a save finishes, whatever its outcome: a queued timer call re-checks the form and returns without a request when nothing changed, so it cannot hold up the saves behind it, and a queued call is run by the script's own function, not through `App_post.save_draft_ajax`, so a wrapper a plugin installed there runs once per call, when the call was made. The lock is released in each response handler's `finally` (jQuery skips `complete` when a success handler throws) and when `$.ajax` throws before sending, where the caller's failure handler runs too, since it is what takes down the overlay or window the caller opened.

**Alternative rejected:** letting concurrent saves run. On a new post the second `POST` creates a second buffer, and the responses race for the draft id.

### D2. Two states: the load baseline and the last save's state

The leave-page prompt keeps comparing against the load baseline (`data("hash")`), so a post that was autosaved but never created still warns: the buffer is not the post. The timer compares against what the last successful save sent (`saved_hash`), read after the editors were written into their textareas, because a textarea's change handler may write a derived field (a word count, an auto excerpt) that would otherwise read as an edit on the next tick. Before the baseline exists the timer sends nothing; a user's save always sends. A save that ran before the baseline keeps its sent state as the saved state, so edits made in between are still autosaved.

### D3. The comparison is a read of the form's own editors

`get_hash_form` takes each initialized editor's content from the editor and serializes the other fields, keyed by the element id; the textarea is written only when a save is sent (`sync_editors`), through its change handlers, so the hidden original of a translated field is composed from the per-language copies then. Only editors inside the form count: one a plugin puts elsewhere on the page (a modal) is neither compared nor sent. The draft id field and the hidden original of a translated field are left out. Fields are matched to editors with an own-property check, since `in` would match a field whose id is an inherited name such as `constructor`.

**Alternative rejected:** keeping the write-back and excluding known plugin fields. camaleon_editor exports its grid into the content textarea itself, with colors as `rgb()`; TinyMCE's serialization rewrote it whenever the snapshot landed after the export, and the list of such plugins is open.

### D4. The load baseline waits for the editors

The baseline is taken one second after setup if every editor on the form is initialized, otherwise on each editor's `init` event (editors created later are watched through `AddEditor`), and after ten seconds regardless, so an editor that never comes up cannot leave the form without a baseline. It runs on its own timer, so a failure in the rest of the page setup does not skip it. A wait that outlives its form (the page loaded another form in place) leaves the next form to its own baseline.

### D5. A held submit is stopped first and dispatched again in full

The hold handler is bound before jQuery validate's. A submit made while a save runs is stopped with `preventDefault` and `stopImmediatePropagation` before validation or any other listener sees it, the overlay goes up, and the submit is held until the save and the saves queued behind it finish (the overlay is put back while they run, since the finished save's caller may have taken it down) or `App_post.submit_wait_ms` passes. Then the overlay comes down and the submit is triggered again on the form it was held on, so validation, every listener and the form's default action run once, then. A refused save drops the hold instead: the post save would refuse the same content, and the alert names what to fix. A failed request lets the submit go: the post save reports for itself. A held form that left the page is not sent.

**Alternative rejected (shipped first, then replaced):** sending the held submit as the form element's own `submit()`. It fires no submit event, so a listener delegated from an ancestor never saw the submit; with camaleon_admin_ajax, whose handler on the body submits the post form in place, a held submit became a full-page load. Returning `false` from the hold also stopped the event reaching such a listener while letting the form's other listeners run, so they had run once and the delegated one not at all.

### D6. Preview opens its window in the click

A popup blocker refuses a window opened from the save's asynchronous callback, so the click opens a blank window at once, prevents the link's default first (a save that throws before sending must not let the browser follow a link that names no draft), asks for the save, and sends the window to the link once the save has pointed it at the draft. A refused or failed save closes the window and takes the overlay down.

### D7. A save fails after a timeout; the timing values are defaulted only when unset

A request that has not returned after `App_post.save_timeout_ms` (30 s) is taken as failed, so a stalled server cannot keep Preview and Save Draft dead until the browser gives up. A held submit waits at most `App_post.submit_wait_ms` (15 s): on a new post the save's buffer may be left behind, the lesser loss against a post that cannot be saved. Both are read from `App_post` and defaulted only when `null`, so a theme or plugin that set them before the editor came up keeps its value, `0` included (no timeout, no hold).

### D8. A response writes into the form it was sent for

With pages loading in place, a save can return after the script was set up on another post's form. The draft id and the Preview links are written into the form the save was sent from, captured when the request was made; the other form's draft id and links are its own. A save still queued when that happens is dropped when the queue drains, its failure handler run: `$form` is the other form by then, and serializing it would send that post's content to this post's draft.

## Risks / Trade-offs

- **[A plugin reads the draft right after `window.save_draft`]** → It now reads it too early; the upgrade guide says to read it in the callback, and a call made during a save waits for the running one, so the id it returns is reused.
- **[A listener bound on the form before the editor came up]** → It runs when the submit is held and again when it is dispatched; only listeners bound before `cama_init_post` (DOM ready + 100 ms) are affected, and none surveyed is.
- **[A new post's first save times out client-side but completes on the server]** → The editor cannot name that buffer, so its next save creates another; listed as out of scope, with buffer pruning.
- **[An editor a plugin creates after the baseline was taken]** → Its normalized content reads as an edit, as before this change for every editor; editors created within the first second, or before an already-watched editor initializes, are waited for.
- **[jQuery validate runs twice per submit]** → The hold handler calls `valid()` and validate's own handler validates again, as the previous handler did; the cost is unchanged.
