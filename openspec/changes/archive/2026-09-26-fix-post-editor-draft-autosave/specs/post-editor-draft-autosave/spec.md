## ADDED Requirements

### Requirement: The minute autosave sends only a form changed since its last successful save

The post editor's minute timer SHALL send a draft save only when the form differs from the state the last successful draft save sent and from the state the last refused save sent (a refusal is decided by the content it names), both read after the editors were written into their textareas, and SHALL send nothing before the load baseline has been taken or once the form has been submitted (the post save removes the drafts). A save the user asks for (Save Draft, Preview, a plugin's call) SHALL always be sent. The draft id field SHALL NOT count as a change.

#### Scenario: An unchanged form is not re-sent

- **WHEN** the title is edited and an autosave tick runs, then a second tick runs with no further edit
- **THEN** one draft request is sent, and a third tick after another edit sends a second

#### Scenario: A submitted form is not sent by the timer

- **WHEN** the post form is submitted, a listener keeps the page, the title is edited and an autosave tick runs
- **THEN** no draft request is sent

#### Scenario: A field written by an editor's change handler is recorded as sent

- **WHEN** a change handler on the content textarea writes a derived hidden field, the editor content is changed and an autosave tick runs
- **THEN** one request is sent, and the next tick sends nothing

#### Scenario: A second language of a translated field is autosaved

- **WHEN** the site has two languages and only the second language's title and content are edited
- **THEN** the next tick sends the draft with both values encoded, and the tick after it sends nothing

#### Scenario: A translated copy still being typed in is sent as typed

- **WHEN** the site has two languages and a tick lands while the second language's title is typed in, before the field has lost focus
- **THEN** the draft is sent with the typed value encoded in the title

### Requirement: The load baseline is taken once the form's editors are ready, and the comparison reads them

The baseline the leave-page prompt compares against SHALL be taken once every TinyMCE editor inside the post form has initialized, re-checked on each editor's `init` event, and taken as the form stands after ten seconds if an editor never comes up. The comparison SHALL read each editor's content from the editor, SHALL NOT write into its textarea, SHALL ignore an editor outside the form, and SHALL leave out the draft id field and the hidden original of a translated field. The fields SHALL be the form's controls as the browser sends them (`form.elements`), a control elsewhere on the page that names the form included. Fields SHALL be matched to editors by their own id, so a field whose id is an inherited object property name is still compared. Until the baseline is taken, the leave-page prompt SHALL NOT compare the form: it SHALL fire only when the user has typed or clicked in the form (a native `input` or `change` event; a value a script writes fires none) or an editor of the form has fired its `change` event (the user's typing, pasting or formatting; a script's `setContent` fires none). The editor's dirty flag SHALL NOT be read for this: TinyMCE clears it whenever the editor's content is saved into its textarea, which its blur handler does. A baseline taken after such an edit SHALL keep the form edited until it is submitted, and the first timer tick after it SHALL send the form.

#### Scenario: An untouched post with a late editor stays unchanged

- **WHEN** the content editor initializes three seconds after the page loaded and the post is not edited
- **THEN** an autosave tick sends nothing and the leave-page prompt returns nothing

#### Scenario: An untouched post does not prompt before the baseline

- **WHEN** the content editor initializes three seconds after the page loaded and the prompt runs before the baseline is taken
- **THEN** it returns nothing, before the baseline and after it

#### Scenario: An edit typed before the baseline keeps prompting and is autosaved

- **WHEN** the title is typed while the baseline still waits for the content editor
- **THEN** the prompt returns a message before the baseline and after it, and the first tick after the baseline sends the typed title

#### Scenario: An editor typed in before the baseline prompts

- **WHEN** the content editor is typed in while the baseline waits for another editor of the form
- **THEN** the prompt returns a message, before the baseline and after it

#### Scenario: An editor typed in and then left before the baseline prompts

- **WHEN** the content editor is typed in and then loses focus while the baseline waits for another editor of the form
- **THEN** the prompt returns a message before the baseline and after it, and the first tick after the baseline sends the typed content

#### Scenario: The comparison leaves a plugin's textarea export alone

- **WHEN** a plugin writes content with `rgb()` colors into the content textarea and the leave-page prompt runs
- **THEN** the textarea still holds the content as written

#### Scenario: An editor outside the form is not the post's content

- **WHEN** a plugin creates an editor outside the post form and types into it
- **THEN** an autosave tick sends nothing and the leave-page prompt returns nothing

#### Scenario: A field named after an inherited property is compared

- **WHEN** a hidden field with id `constructor` is added, saved once, then edited
- **THEN** the next tick sends a draft

#### Scenario: A control outside the form that names it is compared

- **WHEN** a hidden control with `form="form-post"` is added outside the form, saved once, then edited
- **THEN** the next tick sends a draft, and leaving the page asks about the edit

#### Scenario: A baseline wait that outlives its form leaves the next form alone

- **WHEN** the script is set up on another form before the first form's editor comes up
- **THEN** neither form gets a baseline from the first wait, and the prompt does not fail on a page without a post form

### Requirement: Draft saves are asynchronous and run one at a time

A draft save SHALL NOT block the page. One save SHALL run at a time: a save requested while one runs SHALL wait for it and reuse the draft id it returns, so a new post never gets a second buffer; a queued timer call with nothing to send SHALL NOT hold up the saves behind it; one timer call SHALL wait at a time, a tick landing while one waits being dropped; a queued call SHALL be run by the editor's own function, so a wrapper a plugin installed on `App_post.save_draft_ajax` runs once per call. The lock SHALL be taken before the editors are synced into their textareas, so a save a change handler asks for queues behind the one being prepared. The lock SHALL be released whatever the outcome, including a success callback that throws and a save that throws before it is sent (a change handler, `$.ajax`), in which case the caller's failure handler SHALL run and the send's error SHALL still reach the caller, a failure handler that throws, or a queued save that throws when it is run from that error path, being reported on its own. A save that has not returned after `App_post.save_timeout_ms`, and a response that names no draft (a decorated action answering `{}` or `null`), SHALL be taken as failed. A refused save SHALL show its messages as text, whether the response carries a list of them or one message, and run no success callback; the timer calls queued behind it SHALL send nothing, as the form is unchanged since the refusal, while a user's queued call still runs. The draft id and Preview links SHALL be written into the form the save was sent from. A call made, or a queued call run, after the page loaded another form in place SHALL be dropped at once, its failure handler run, never queued behind a running save and never sent for that form. The saves queued behind a save the fallback wait outran (a held submit sent while it ran) SHALL be dropped when it returns, their failure handlers run: the form is submitted, and a buffer written after the post save removed it would be offered for recovery on the next edit.

#### Scenario: Two overlapping autosaves create one buffer

- **WHEN** a second autosave tick starts while the first save of a new post is in flight
- **THEN** one buffer exists, holding the second tick's values

#### Scenario: The saves queued behind an idle timer call run

- **WHEN** a user's save, a timer call and another user's save with a callback are queued in that order
- **THEN** the callback runs

#### Scenario: One timer call waits behind a running save

- **WHEN** two timer ticks land while a save runs, the form is edited before it returns, and edited again while the save the first tick then sends runs
- **THEN** no third request is sent when that save returns; the next tick sends the last edit

#### Scenario: A throwing callback does not hold the lock

- **WHEN** a save's success callback throws
- **THEN** a later save runs and its callback runs

#### Scenario: A send that throws runs the failure handler and frees the lock

- **WHEN** `$.ajax` throws before sending a draft request
- **THEN** the error reaches the caller, the failure handler runs, and a later save runs

#### Scenario: A failure handler that throws does not hide the send's error

- **WHEN** `$.ajax` throws before sending a draft request and the caller's failure handler throws too
- **THEN** the send's error is the one that reaches the caller, and a later save runs

#### Scenario: A queued save that throws does not hide the send's error

- **WHEN** `$.ajax` throws before sending a draft request, and throws again for the save a change handler queued behind it, which is run from the first save's error path
- **THEN** the first save's error is the one that reaches its caller, the queued save's failure handler runs, and a later save runs

#### Scenario: A save asked for by a change handler queues behind the one being prepared

- **WHEN** a change handler on an editor's textarea asks for a save while a save of a new post is syncing the editors
- **THEN** two requests are sent one after the other and one buffer exists

#### Scenario: A change handler that throws before the send frees the lock

- **WHEN** a change handler on an editor's textarea throws while a save syncs the editors
- **THEN** the error reaches the caller, the failure handler runs, and a later save runs

#### Scenario: A plugin wrapper runs once for a queued save

- **WHEN** `App_post.save_draft_ajax` is wrapped and two saves are made back to back
- **THEN** the wrapper has run twice when the second save's callback runs

#### Scenario: A stalled save fails after the timeout

- **WHEN** the server does not answer within `App_post.save_timeout_ms`
- **THEN** the failure handler runs, the failure is reported, and a later save succeeds

#### Scenario: A response without a draft fails the save

- **WHEN** the drafts action answers with neither an error nor a draft, or with a draft that names no id
- **THEN** the failure is reported, the overlay is gone, the form stays and a later save succeeds

#### Scenario: A refusal that names no message fails the save

- **WHEN** the drafts action answers with `error` set to an empty list
- **THEN** it is not shown as a refusal: the failure is reported, the overlay is gone, the form stays and a later save succeeds

#### Scenario: A timer call queued behind a refused save is dropped

- **WHEN** a save is refused while a timer call waits behind it
- **THEN** the refusal is shown and no second request is sent

#### Scenario: A refused form is not re-sent until it changes

- **WHEN** a tick sends a form the server refuses, and a second tick runs with the form left as it was
- **THEN** the refusal is shown once and the second tick sends nothing; a tick after the form is changed sends it

#### Scenario: A refusal sent as one message is shown

- **WHEN** the drafts action answers with `error` set to one message rather than a list
- **THEN** the message is shown, the overlay is taken down and the form stays

#### Scenario: A refusal sent as messages keyed by field is shown

- **WHEN** the drafts action answers with `error` set to an object of messages keyed by field, as a model's errors serialize
- **THEN** each message is shown with its field, the overlay is taken down and the form stays

#### Scenario: A late response writes into its own form

- **WHEN** the form is replaced by another post form while a save is in flight
- **THEN** the draft id and Preview link of the form the save was sent from name the draft, and the new form's stay empty

#### Scenario: A queued save whose form was replaced is dropped

- **WHEN** a save is queued behind a running one and the form is replaced by another form before it runs
- **THEN** the queued save is not sent, its failure handler runs, and the first save's draft keeps its content

#### Scenario: The saves queued behind a save the fallback wait outran are dropped

- **WHEN** a save is queued behind a running one, a held submit is sent by the fallback wait while the running save still runs, and that save then returns
- **THEN** the queued save is not sent, its failure handler runs, and the post has one buffer

#### Scenario: A call for a replaced form is dropped at once

- **WHEN** a save is running and the form is replaced by another form, then a save with a failure handler is asked for
- **THEN** the failure handler has run when the call returns

### Requirement: The Preview link and window name the draft the save created

After every successful draft save, each Preview link on the form SHALL name that draft, so it opens the draft however it is opened. The Preview click SHALL open its window inside the click, prevent the link's default action first, save the draft, then send the window to the link; when the save is refused, fails or could not be sent, the window SHALL be closed and the overlay taken down.

#### Scenario: The Preview link is pointed at an autosaved draft

- **WHEN** a new post's title is entered and an autosave tick runs
- **THEN** the Preview link ends in that buffer's draft id

#### Scenario: Preview shows the saved draft

- **WHEN** Preview is clicked, also while an autosave is in flight
- **THEN** the window opened by the click shows the draft with the current title, and a new post has one buffer

#### Scenario: A refused or unsent preview save opens nothing

- **WHEN** the preview's draft save is refused, or throws before sending
- **THEN** the window is closed (or never opened), the overlay is gone and the editor stays on the form

### Requirement: A post submitted while a draft save runs is held and dispatched again in full

A post form submitted while a draft save is running SHALL be held under the loading overlay before validation or a submit listener bound after the editor's own sees it, until that save and the saves queued behind it finish (the overlay kept while they run) or `App_post.submit_wait_ms` passes. The submit SHALL then be dispatched again to the form it was held on as the submit event the browser fires (`requestSubmit`, with the button that submitted it as the submitter; jQuery's trigger in a browser without `requestSubmit`), so validation, those listeners, delegated ones and ones bound outside jQuery included, and the form's default action run once, with the draft id in the form and the button's name, value and formaction sent by the browser as they would have been. A refused save SHALL release the hold and keep the post on the form, consuming a validator skip (`cancelSubmit`) the held submit carried, so the next submit is validated; a failed request SHALL let the submit go; a held form that left the page SHALL NOT be sent, but the overlay SHALL come down.

#### Scenario: A submit during an autosave discards the new post's buffer

- **WHEN** a new post is submitted while its first draft save is in flight
- **THEN** the post is created and no parentless buffer remains

#### Scenario: A stalled save does not keep the post from being saved

- **WHEN** the draft save never returns and `App_post.submit_wait_ms` passes
- **THEN** the overlay was shown and the post is created

#### Scenario: A failed draft request lets the submit go

- **WHEN** the draft request the submit waited for reports an error
- **THEN** the post is created before the fallback wait

#### Scenario: A refused draft save keeps the post on the form

- **WHEN** the draft save the submit waited for is refused
- **THEN** the refusal is shown, the overlay is gone, the form is not submitted after the fallback wait, and it is not marked submitted

#### Scenario: The submit after a dropped skip-validation hold is validated

- **WHEN** a submit the validator was told to skip is held and the hold is dropped on a refused save
- **THEN** the next submit is validated as usual, and an invalid form is neither submitted nor marked submitted

#### Scenario: Listeners run once, delegated ones included

- **WHEN** a submit listener on the form and one delegated from the body are bound, and the form is submitted during a save
- **THEN** neither runs while the submit is held, and each runs once when it is dispatched, the delegated one seeing the draft id in the form

#### Scenario: The button that made a held submit goes with it

- **WHEN** a submit button with a name, a value and a formaction submits the form during a save
- **THEN** the browser's own submission of the dispatched submit carries that name and value to that formaction

#### Scenario: A listener bound outside jQuery sees the dispatched submit

- **WHEN** a listener registered with `addEventListener` on the form is bound after the editor's handler, and a button submits the form during a save
- **THEN** it does not run while the submit is held, and runs once when it is dispatched, with that button as the event's submitter

#### Scenario: A browser without requestSubmit still sends the held submit

- **WHEN** the browser has no `requestSubmit` and the form is submitted during a save
- **THEN** the held submit is sent through jQuery's trigger when the save returns, and the post is saved

#### Scenario: The overlay stays while a queued save runs

- **WHEN** the submit was held behind a save whose caller takes the overlay down, with another save queued
- **THEN** the overlay is up while the queued save runs, and the post is created after it

#### Scenario: A queued save that throws lets the held submit go

- **WHEN** a submit is held behind a save while a queued save waits, and the queued save throws before it is sent
- **THEN** the post is saved well before `App_post.submit_wait_ms` has passed

#### Scenario: A replaced form is not sent

- **WHEN** the held form is replaced by another form before the hold ends
- **THEN** the replacement is neither submitted nor marked submitted, and the overlay is gone

### Requirement: The draft save is a public asynchronous contract

`window.save_draft(callback, called_from_interval, on_failure)`, the same function as `App_post.save_draft_ajax`, SHALL return at once and run `callback(response)` when the save succeeds; `on_failure` SHALL run when the save is refused, the request fails, times out, answers without a draft (or with a draft that names no id) or with a refusal that names no message (a failed request, not a refusal) or could not be sent. A failed request the user asked for SHALL be reported with the translated `msg.draft_save_failed` message, unless a submit is held on it or the fallback wait sent one while it ran (the post save reports for itself), and a refusal that returns after the fallback wait sent the held submit SHALL NOT be shown either, nor drop a submit held since, which is left to its own wait as it is when the save fails or succeeds; a save that succeeds after the fallback wait sent its held submit SHALL run `on_failure` in place of its callback, so Save Draft does not leave the page the post save has; the timer's SHALL be retried silently a minute later. `App_post.submit_wait_ms` (15 s) and `App_post.save_timeout_ms` (30 s) SHALL be defaulted only when unset, so a value a plugin or theme set before the editor came up, `0` included, is kept. Save Draft SHALL hold the form under the overlay while its save runs, leave to the post list on success, and give the form back with the refusal shown when the save is refused or fails. When the page has loaded another form in place by the time the save returns, Save Draft SHALL leave that form and its leave prompt alone: the draft is saved, the overlay comes down and the page stays.

#### Scenario: A failed save the user asked for is reported

- **WHEN** a save with a failure handler times out
- **THEN** the handler runs and the alert shows the translated failure message

#### Scenario: A save that fails after the fallback wait sent its held submit is not reported

- **WHEN** the fallback wait sends a held submit while the draft save still runs, and that save then fails
- **THEN** no failure alert is shown

#### Scenario: A save that is refused after the fallback wait sent its held submit is not reported

- **WHEN** the fallback wait sends a held submit while the draft save still runs, and that save is then refused
- **THEN** no refusal alert is shown

#### Scenario: A submit held after the fallback wait sent one keeps its own wait when the save is refused

- **WHEN** the fallback wait sends a held submit that a listener keeps on the page, the form is submitted again while the draft save still runs, and that save is then refused
- **THEN** no refusal alert is shown, the second submit is sent when its own wait ends and the overlay comes down

#### Scenario: A save that succeeds after the fallback wait sent its held submit runs the failure handler

- **WHEN** the fallback wait sends a held submit while Save Draft's save still runs, and that save then succeeds
- **THEN** the draft is saved, the overlay comes down and the page stays where the post save left it

#### Scenario: Save Draft returns to the list

- **WHEN** Save Draft is clicked on a new post with a title
- **THEN** the post list opens and the buffer holds the title

#### Scenario: Save Draft returning for a replaced form stays on the page

- **WHEN** the form is replaced by another form while Save Draft's save runs
- **THEN** the buffer holds the title, the overlay is gone, the page stays and the new form is not marked submitted

#### Scenario: A refused Save Draft gives the editor back

- **WHEN** Save Draft's save is refused
- **THEN** the overlay was shown, the refusal is shown, the overlay is gone and the editor stays on the form
