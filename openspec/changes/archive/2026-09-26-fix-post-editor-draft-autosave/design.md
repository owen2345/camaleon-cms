## Context

See proposal.md for the defects. On `master`:

- **`cama_init_post`** (`admin/_post.js`) runs once per post form, 100 ms after DOM ready, and closes over the post id, the draft id and the drafts path. Admin pages load in place (camaleon_admin_ajax replaces `#admin_content`), so the script can be set up again on another form while a request from the previous one is in flight; `App_post` and `$form` are globals the newest setup owns.
- **The save** serialized the form, posted it with `async: false`, wrote the draft id into `#post_draft_id` and ran the caller's callback before returning. The minute timer, Save Draft, Preview and `window.save_draft` (plugins) all went through it.
- **The comparison** (`get_hash_form`) wrote each TinyMCE editor's content into its textarea, triggered `change`, and serialized the form; it ran on every tick and in the leave-page prompt. The load snapshot was taken on a two-second timer.
- **The submit handler** (bound a second after setup, after jQuery validate's) marked the form submitted so the leave-page prompt stays quiet; the server discards the new post's buffer named by `post[draft_id]` on create.
- **TinyMCE 4** keys `tinymce.editors` by index and by id, fires `AddEditor` when an editor is created and `init` once it is usable, normalizes the textarea when it comes up, and patches the form's `submit` to save its editors.

## Goals / Non-Goals

**Goals:**
- The Preview link names the draft however it is opened; an unchanged form is not re-sent; an untouched post neither autosaves nor prompts on leave; the editor never freezes for a save.
- Every path the blocking save serialized by accident (a second save, a submit, a throwing callback) has a stated outcome, and none can leave the editor unable to save, preview or submit.
- Plugin content in a textarea, plugin editors elsewhere on the page and plugin wrappers around the save keep working.

**Non-Goals:**
- Pruning parentless draft buffers (abandoned new posts, a first save that timed out client-side but completed on the server): server-side, a follow-up.
- A saved indicator in the editor.
- Any server-side change: the drafts endpoint and `draft-authorization` are untouched.

## Decisions

### D1. One asynchronous save at a time, with a queue

A lock (`saving`) admits one request; a call made meanwhile is queued with its arguments. The queue drains when a save finishes, whatever the outcome. A queued timer call re-checks the form and returns without a request when nothing changed, so it cannot hold up the saves behind it. Queued calls run through the script's own function, not `App_post.save_draft_ajax`, so a plugin's wrapper runs once per call. A save the script's own callers make under the overlay (Save Draft, Preview) is flagged in the queue and gets the overlay back when it is drained, since the finished save's caller took it down; a plugin's call is not flagged, as nothing of its would take the overlay down. The lock is released in each response handler's `finally` (jQuery skips `complete` when a success handler throws) and when `$.ajax` throws before sending, where the caller's failure handler runs too, since it takes down the overlay or window the caller opened.

**Rejected:** concurrent saves. On a new post the second `POST` creates a second buffer, and the responses race for the draft id.

### D2. Two states: the load baseline and the last save's state

The leave-page prompt compares against the load baseline (`data("hash")`), so a post that was autosaved but never created still warns. The timer compares against what the last successful save sent (`saved_hash`), read after the editors were written into their textareas, since a textarea's change handler may write a derived field that would otherwise read as an edit on the next tick. Before the baseline exists the timer sends nothing; a user's save always sends. A save that ran before the baseline keeps its own saved state.

### D3. The comparison is a read of the form's own editors

`get_hash_form` reads each initialized editor's content from TinyMCE and serializes the other fields, taken from `form.elements` so a control elsewhere on the page that names the form counts, keyed by element id. The textarea is written only when a save is sent (`sync_editors`), through its change handlers, which also recompose a translated field's hidden original from its copies. Only editors inside the form count. The draft id field and the hidden original are left out. Fields are matched to editors with an own-property check, since `in` would match an inherited name such as `constructor`.

**Rejected:** keeping the write-back and excluding known plugin fields. camaleon_editor exports its grid into the content textarea with `rgb()` colors, which TinyMCE's serialization rewrote whenever the snapshot landed after the export, and the list of such plugins is open.

### D4. The load baseline waits for the editors

The baseline is taken a second after setup if every editor on the form is initialized, otherwise on each editor's `init` (editors created later are watched through `AddEditor`), and after ten seconds regardless. It runs on its own timer, so a failure in the rest of the page setup does not skip it. A wait that outlives its form leaves the next form to its own baseline.

Until then the form is still being set up (an editor normalizes its textarea, a widget writes its value), so the prompt does not compare: the form counts as edited when the user typed or clicked in a control of the form, inside it or elsewhere on the page naming it (a native `input` or `change` event; a script's write or jQuery's trigger fires none) or an editor fired its `change` event (an undo level added: typing, pasting, formatting; not `setContent`). The editor's `isDirty` is not read: TinyMCE clears it whenever the content is saved into the textarea, which the blur handler does. A baseline taken after such an edit has absorbed it: the form stays edited until submitted, and the saved state is set to match no form, so the first tick sends the edit.

**Rejected:** silencing the prompt until the baseline, which would hide an edit typed in that window; and a snapshot of the non-editor fields at setup, which the widgets that come up in the first second (the tag editor, custom-field pickers) would turn into an edit by writing their values.

### D5. A held submit is stopped first and dispatched again in full

The hold handler is bound before jQuery validate's. A submit made while a save runs is stopped with `preventDefault` and `stopImmediatePropagation` before validation or any other listener sees it, the overlay goes up, and the submit waits until the save and the saves queued behind it finish (the overlay put back while they run) or `App_post.submit_wait_ms` passes. Then the overlay comes down and the submit is dispatched again on the form it was held on with `requestSubmit`, the button that made it as the submitter: validation, every listener (jQuery's, delegated and native alike) and the default action run once, and the browser sends the button's name, value and formaction. Safari before 16 has no `requestSubmit` and gets jQuery's trigger, which reaches jQuery's listeners and the default action but does not know the button.

A refused save drops the hold instead: the post save would refuse the same content, and the alert names what to fix. Dropping it also resets a `cancelSubmit` the validator's click handler set for the held submit (a Cancel or formnovalidate button), since validate's own handler, which resets it, never saw that submit. A failed request lets the submit go. A held form that left the page is not sent. When the wait runs out with the save still running, the request is aborted (`jqXHR.abort`) before the submit goes out: the post save reports for itself from then on, so the failure handler runs with no alert, the queued saves are dropped, and a submit made afterwards is not held. A `$.ajax` wrapper must return the jqXHR for the abort to reach the request.

**Rejected (shipped, then replaced):** letting the save run on and tracking its late answer through a flag: it silenced the failure or refusal, ran the failure handler in place of the callback, dropped the queued saves and sent a submit held since. The abort makes the late answer impossible instead of handling each kind of it.

**Rejected (shipped first):** sending the held submit as the form element's own `submit()`. It fires no submit event, so a listener delegated from an ancestor never saw it; with camaleon_admin_ajax, which submits the post form in place from one on the body, a held submit became a full-page load.

**Rejected (shipped second):** re-triggering the submit through jQuery with the button's name and value as a hidden field. A listener bound with `addEventListener` saw the held submit once and the dispatch never, and the button's `formaction` and `formmethod` were lost.

### D6. Preview opens its window in the click

A popup blocker refuses a window opened from the save's asynchronous callback, so the click opens a blank window at once, prevents the link's default action (a save that throws must not let the browser follow a link naming no draft), asks for the save, and sends the window to the link once the save has pointed it at the draft. A refused or failed save closes the window and takes the overlay down.

### D7. A save fails after a timeout; the timing values are defaulted only when unset

A request that has not returned after `App_post.save_timeout_ms` (30 s) is taken as failed, so a stalled server cannot keep Preview and Save Draft dead. A held submit waits at most `App_post.submit_wait_ms` (15 s): on a new post the save's buffer may be left behind, the lesser loss against a post that cannot be saved. Both are defaulted only when `null`, so a theme or plugin that set them first keeps its value, `0` included.

### D8. A response writes into the form it was sent for

With pages loading in place, a save can return after the script was set up on another post's form. The draft id and the Preview links are written into the form the save was sent from, captured when the request was made. A refusal or failure that returns then is still shown (the user asked for that save), prefixed with the post's title so it reads right over another page. A save still queued when that happens is dropped, its failure handler run: `$form` is the other form by then, and serializing it would send that post's content to this post's draft.

## Risks / Trade-offs

- **A plugin reads the draft right after `window.save_draft`** → It reads it too early; the upgrade guide says to read it in the callback.
- **A listener bound on the form before the editor came up** → It runs when the submit is held and again when it is dispatched; only listeners bound before `cama_init_post` (DOM ready + 100 ms) are affected, and none surveyed is.
- **A new post's first save times out client-side but completes on the server** → The editor cannot name that buffer, so its next save creates another; out of scope, with buffer pruning.
- **A widget writes a value before the baseline** → Not a touch: the baseline absorbs it like any setup write. Only the user's input and the editors' change events count.
- **An editor a plugin creates after the baseline** → Its normalized content reads as an edit, as before this change.
- **jQuery validate runs twice per submit** → The hold handler calls `valid()` and validate's own handler validates again, as before; the cost is unchanged.
