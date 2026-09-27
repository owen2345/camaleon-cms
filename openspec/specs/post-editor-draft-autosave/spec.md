# post-editor-draft-autosave Specification

## Purpose
The admin post editor autosaves a draft buffer every minute while the form has changed, so unpublished
work survives a crash or a closed tab and Preview can show it. This capability covers what the timer
sends and when, how the form is compared, the asynchronous one-at-a-time save and its contract for
plugins (`window.save_draft`), the Preview link and window, and a post submitted while a save runs. The
server side of the endpoint is `draft-authorization`.

## Requirements

### Requirement: The minute timer sends only a changed form

The timer SHALL send a draft save only when the form differs from what the last successful save sent and from what the last refused save sent, both read after the editors were written into their textareas. It SHALL send nothing before the load baseline exists or after the form was submitted (a buffer written then outlives the post save and shows up under Drafts). A save the user asks for (Save Draft, Preview, a plugin's call) SHALL always be sent. The draft id field SHALL NOT count as a change.

#### Scenario: An unchanged form is not re-sent

- **WHEN** the title is edited and a tick runs, then a second tick runs with no further edit
- **THEN** one draft request is sent, and a third tick after another edit sends a second

#### Scenario: A submitted form is not sent by the timer

- **WHEN** the form is submitted, a listener keeps the page, the title is edited and a tick runs
- **THEN** no draft request is sent

#### Scenario: A field written by an editor's change handler is recorded as sent

- **WHEN** a change handler on the content textarea writes a derived hidden field, the content is changed and a tick runs
- **THEN** one request is sent, and the next tick sends nothing

#### Scenario: A second language of a translated field is autosaved

- **WHEN** the site has two languages and only the second language's title and content are edited
- **THEN** the next tick sends both values encoded, and the tick after it sends nothing

#### Scenario: A translated copy still being typed in is sent as typed

- **WHEN** a tick lands while the second language's title is being typed, before the field loses focus
- **THEN** the draft is sent with the typed value encoded in the title

### Requirement: The load baseline waits for the form's editors

The baseline the leave-page prompt compares against SHALL be taken once every TinyMCE editor inside the form has initialized (re-checked on each editor's `init`), or after ten seconds if one never comes up. Until then the prompt SHALL NOT compare the form: it SHALL fire only if the user typed or clicked in a control of the form, inside it or elsewhere on the page naming it (a native `input` or `change` event) or an editor fired its `change` event (typing, pasting, formatting; not a script's `setContent`). The editor's dirty flag SHALL NOT be used, since TinyMCE clears it when the editor saves into its textarea on blur. A baseline taken after such an edit SHALL keep the form edited until it is submitted, and the first tick after it SHALL send the form.

#### Scenario: An untouched post with a late editor stays unchanged

- **WHEN** the content editor initializes three seconds after the page loaded and the post is not edited
- **THEN** a tick sends nothing and the prompt returns nothing

#### Scenario: An untouched post with an editor custom field stays unchanged

- **WHEN** a post has a custom field of type editor, whose editor the field's own script creates, and the post is not edited
- **THEN** a tick sends nothing and the prompt returns nothing

#### Scenario: An untouched post does not prompt before the baseline

- **WHEN** the content editor initializes three seconds after the page loaded and the prompt runs before the baseline
- **THEN** it returns nothing, before the baseline and after it

#### Scenario: An edit typed before the baseline keeps prompting and is autosaved

- **WHEN** the title is typed while the baseline still waits for the content editor
- **THEN** the prompt returns a message before and after the baseline, and the first tick after it sends the title

#### Scenario: An edit typed before the baseline into a control that names the form keeps prompting

- **WHEN** a control elsewhere on the page with `form="form-post"` is typed in while the baseline still waits for the content editor
- **THEN** the prompt returns a message before and after the baseline, and the first tick after it sends the form

#### Scenario: An editor typed in before the baseline prompts

- **WHEN** the content editor is typed in while the baseline waits for another editor
- **THEN** the prompt returns a message, before the baseline and after it

#### Scenario: An editor typed in and then left before the baseline prompts

- **WHEN** the content editor is typed in and then loses focus while the baseline waits for another editor
- **THEN** the prompt returns a message before and after the baseline, and the first tick after it sends the content

#### Scenario: A baseline wait that outlives its form leaves the next form alone

- **WHEN** another post form is loaded in place of the first before the first form's editor comes up
- **THEN** neither form gets a baseline from the first wait, and the prompt does not fail on a page without a post form

### Requirement: The comparison reads the form without writing it

The comparison SHALL read each editor's content from the editor and leave its textarea alone, ignore an editor outside the form, and leave out the draft id field and the hidden original of a translated field. The fields SHALL be the form's controls as the browser sends them (`form.elements`), so a control elsewhere on the page that names the form counts. Fields SHALL be matched to editors by their own id, so a field whose id is an inherited object property name is still compared.

#### Scenario: The comparison leaves a plugin's textarea export alone

- **WHEN** a plugin writes content with `rgb()` colors into the content textarea and the prompt runs
- **THEN** the textarea still holds the content as written

#### Scenario: An editor outside the form is not the post's content

- **WHEN** a plugin creates an editor outside the form and types into it
- **THEN** a tick sends nothing and the prompt returns nothing

#### Scenario: A field named after an inherited property is compared

- **WHEN** a hidden field with id `constructor` is added, saved once, then edited
- **THEN** the next tick sends a draft

#### Scenario: A control outside the form that names it is compared

- **WHEN** a hidden control with `form="form-post"` is added outside the form, saved once, then edited
- **THEN** the next tick sends a draft, and leaving the page asks about the edit

#### Scenario: An editor inside a fieldset is read from the editor alone

- **WHEN** the content textarea sits inside a fieldset and the editor's blur handler saves into it
- **THEN** an untouched post reads as unchanged: the next tick sends nothing and leaving asks nothing

### Requirement: One asynchronous save runs at a time

A draft save SHALL NOT block the page. A save requested while one runs SHALL queue and reuse the draft id it returns, so a new post never gets a second buffer. A queued timer call with nothing to send SHALL NOT hold up the saves behind it; one timer call SHALL wait at a time. Queued calls SHALL run through the editor's own function, so a wrapper on `App_post.save_draft_ajax` runs once per call. The lock SHALL be taken before the editors are synced, so a save a change handler asks for queues.

#### Scenario: Two overlapping autosaves create one buffer

- **WHEN** a second tick starts while the first save of a new post is in flight
- **THEN** one buffer exists, holding the second tick's values

#### Scenario: The saves queued behind an idle timer call run

- **WHEN** a user's save, a timer call and another user's save with a callback are queued in that order
- **THEN** the callback runs

#### Scenario: One timer call waits behind a running save

- **WHEN** two ticks land while a save runs, the form is edited before it returns, and edited again while the save the first tick sends runs
- **THEN** no third request is sent when that save returns; the next tick sends the last edit

#### Scenario: A save asked for by a change handler queues behind the one being prepared

- **WHEN** a change handler on an editor's textarea asks for a save while a new post's save syncs the editors
- **THEN** two requests are sent one after the other and one buffer exists

#### Scenario: A plugin wrapper runs once for a queued save

- **WHEN** `App_post.save_draft_ajax` is wrapped and two saves are made back to back
- **THEN** the wrapper has run twice when the second save's callback runs

### Requirement: The lock is released whatever the outcome

The lock SHALL be released when a success callback throws and when a save throws before it is sent (a change handler, `$.ajax`); the failure handler SHALL run and the send's error SHALL reach the caller. A failure handler or queued save that throws on that path SHALL be reported on its own. A save that has not returned after `App_post.save_timeout_ms` SHALL fail, as SHALL a response with no draft to name or a refusal with no message, blank ones not counting.

#### Scenario: A throwing callback does not hold the lock

- **WHEN** a save's success callback throws
- **THEN** a later save runs and its callback runs

#### Scenario: A send that throws runs the failure handler and frees the lock

- **WHEN** `$.ajax` throws before sending a draft request
- **THEN** the error reaches the caller, the failure handler runs, and a later save runs

#### Scenario: A failure handler that throws does not hide the send's error

- **WHEN** `$.ajax` throws before sending and the caller's failure handler throws too
- **THEN** the send's error is the one that reaches the caller, and a later save runs

#### Scenario: A queued save that throws does not hide the send's error

- **WHEN** `$.ajax` throws before sending, and again for the save a change handler queued behind it
- **THEN** the first save's error reaches its caller, the queued save's failure handler runs, and a later save runs

#### Scenario: A change handler that throws before the send frees the lock

- **WHEN** a change handler on an editor's textarea throws while a save syncs the editors
- **THEN** the error reaches the caller, the failure handler runs, and a later save runs

#### Scenario: A stalled save fails after the timeout

- **WHEN** the server does not answer within `App_post.save_timeout_ms`
- **THEN** the failure handler runs, the failure is reported, and a later save succeeds

#### Scenario: A response without a draft fails the save

- **WHEN** the drafts action answers with neither an error nor a draft, or with a draft that names no id
- **THEN** the failure is reported, the overlay is gone, the form stays and a later save succeeds

#### Scenario: A refusal that names no message fails the save

- **WHEN** the drafts action answers with `error` set to an empty list, or to blank messages only
- **THEN** it is not shown as a refusal: the failure is reported, the overlay is gone, the form stays and a later save succeeds

### Requirement: A refused save shows its messages and is not re-sent

A refused save SHALL show its messages as text, whether the response carries a list, one message or messages keyed by field, and run no callback. A message sent as an object (a model's error details) SHALL be shown by what it names, and a blank message SHALL be left out. A falsy `error` (`false`, `0`) SHALL refuse nothing. The timer calls queued behind it SHALL send nothing, and the timer SHALL NOT re-send the form until it changes; a user's call is always sent.

#### Scenario: A timer call queued behind a refused save is dropped

- **WHEN** a save is refused while a timer call waits behind it
- **THEN** the refusal is shown and no second request is sent

#### Scenario: A refused form is not re-sent until it changes

- **WHEN** a tick sends a form the server refuses, and a second tick runs with the form unchanged
- **THEN** the refusal is shown once and the second tick sends nothing; a tick after the form changes sends it

#### Scenario: A refusal sent as one message is shown

- **WHEN** the drafts action answers with `error` set to one message rather than a list
- **THEN** the message is shown, the overlay is gone and the form stays

#### Scenario: A refusal sent as messages keyed by field is shown

- **WHEN** the drafts action answers with `error` set to messages keyed by field, as a model's errors serialize
- **THEN** each message is shown with its field, the overlay is gone and the form stays

#### Scenario: A refusal sent as error details is shown by what each names

- **WHEN** the drafts action answers with `error` keyed by field, each entry an object with an `error` or a `message`
- **THEN** each field is shown with what its entry names

#### Scenario: The blank messages of a refusal are left out

- **WHEN** the drafts action answers with `error` set to a list of one message among blank ones
- **THEN** that message alone is shown

#### Scenario: A false error refuses nothing

- **WHEN** the drafts action answers Save Draft with a saved draft and `error` set to `false`
- **THEN** the draft is saved and the post list opens

### Requirement: A save belongs to the form it was sent from

The draft id and Preview links SHALL be written into the form the save was sent from. Once the form left the page (another page loaded in place, with a post form of its own or none), a call made, or a queued call run, SHALL be dropped at once, its failure handler run, and a refusal or failure shown SHALL name the post it is about, by its title as text (a translated title by the first language copy typed in). A save returning for a form that left SHALL take down no overlay but its own form's: the overlay a post form loaded in its place put up SHALL stay while that form's save runs, behind a refusal or failure shown for the form that left included.

#### Scenario: A late response writes into its own form

- **WHEN** the form is replaced by another post form while a save is in flight
- **THEN** the draft id and Preview link of the form the save was sent from name the draft, and the new form's stay empty

#### Scenario: A refusal shown over a page loaded in place names the post

- **WHEN** Save Draft's save is refused after the form was replaced by another form
- **THEN** the refusal is shown prefixed with the post's title, HTML in the title rendered as text

#### Scenario: A failure shown over a page without a form names the post

- **WHEN** Save Draft's save fails after the post list was loaded in place of the form
- **THEN** the failure is shown prefixed with the post's title

#### Scenario: A translated post is named by the first title copy typed in

- **WHEN** the title of a two-language post was typed in the second language only and Save Draft's save is refused after the form left the page
- **THEN** the refusal is shown prefixed with that title

#### Scenario: A queued save whose form was replaced is dropped

- **WHEN** a save is queued behind a running one and the form is replaced before it runs
- **THEN** the queued save is not sent, its failure handler runs, and the first save's draft keeps its content; with the editor set up on the form in its place, that form's own edits are saved as its post's draft

#### Scenario: Preview returning for the form that left shows that form's draft

- **WHEN** Preview is clicked, another post form is loaded in place and set up, and Preview's save returns
- **THEN** the window shows the draft of the form that left, and the Preview link of the form in its place does not name that draft

#### Scenario: A call for a replaced form is dropped at once

- **WHEN** a save is running, the form is replaced, and a save with a failure handler is asked for
- **THEN** the failure handler has run when the call returns

#### Scenario: A queued save whose form left for a page without one is dropped

- **WHEN** a save is queued behind a running one and the post list is loaded in place of the form before it runs
- **THEN** the queued save is not sent and its failure handler runs

#### Scenario: A call for a form that left for a page without one is dropped at once

- **WHEN** the post list is loaded in place of the form and a save with a failure handler is asked for
- **THEN** no request is sent, and the failure handler has run when the call returns

#### Scenario: A save of the form that left leaves the next form's overlay up

- **WHEN** Save Draft's save of a form returns after another post form was loaded in its place and Save Draft was clicked on that one
- **THEN** the overlay stays up until the second form's save returns, and the post list opens after it

#### Scenario: A refusal for the form that left is shown over the next form's overlay

- **WHEN** Save Draft's save of a form is refused after another post form was loaded in its place and Save Draft was clicked on that one
- **THEN** the refusal is shown prefixed with the first post's title, and the overlay is up behind it

### Requirement: The Preview link and window name the saved draft

After every successful save, each Preview link on the form SHALL name that draft. The Preview click SHALL prevent the link's default action, open its window inside the click, save the draft, then send the window to the link; when the save is refused, fails or could not be sent, the window SHALL be closed and the overlay taken down.

#### Scenario: The Preview link is pointed at an autosaved draft

- **WHEN** a new post's title is entered and a tick runs
- **THEN** the Preview link ends in that buffer's draft id

#### Scenario: Preview shows the saved draft

- **WHEN** Preview is clicked, also while an autosave is in flight
- **THEN** the window opened by the click shows the draft with the current title, and a new post has one buffer

#### Scenario: A refused or unsent preview save opens nothing

- **WHEN** the preview's save is refused, or throws before sending
- **THEN** the window is closed (or never opened), the overlay is gone and the editor stays on the form

### Requirement: A submit during a save is held, then dispatched in full

A form submitted while a save runs SHALL be held under the loading overlay, before validation or a listener bound after the editor's own sees it, until the save and the saves queued behind it finish (the overlay kept while they run) or `App_post.submit_wait_ms` passes. The submit SHALL then be dispatched again to the form it was held on as the submit event the browser fires (`requestSubmit` with the submitting button as the submitter; jQuery's trigger in a browser without `requestSubmit`), so validation, every listener and the form's default action run once, with the draft id in the form and the button's name, value and formaction sent by the browser. A refused save SHALL drop the hold and keep the post on the form, resetting a `cancelSubmit` the held submit carried; a failed request SHALL let the submit go; a held form that left the page SHALL NOT be sent, but the overlay SHALL come down.

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
- **THEN** the next submit is validated, and an invalid form is neither submitted nor marked submitted

#### Scenario: Listeners run once, delegated ones included

- **WHEN** a submit listener on the form and one delegated from the body are bound, and the form is submitted during a save
- **THEN** neither runs while the submit is held, and each runs once when it is dispatched, the delegated one seeing the draft id

#### Scenario: The button that made a held submit goes with it

- **WHEN** a submit button with a name, a value and a formaction submits the form during a save
- **THEN** the browser's own submission of the dispatched submit carries that name and value to that formaction

#### Scenario: A listener bound outside jQuery sees the dispatched submit

- **WHEN** a listener registered with `addEventListener` after the editor's handler is bound, and a button submits the form during a save
- **THEN** it does not run while the submit is held, and runs once when it is dispatched, with that button as the submitter

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

#### Scenario: A held form that left for a page without one is not sent

- **WHEN** the post list is loaded in place of the held form and the save the submit waited for returns
- **THEN** no post is saved, the list stays and the overlay is gone

### Requirement: The fallback wait aborts the running save

When `App_post.submit_wait_ms` passes with the save still running, the save SHALL be aborted before the submit is sent: `on_failure` runs, no error is shown, and the saves queued behind it are dropped with their failure handlers run, one that throws not stopping the others. A submit made afterwards SHALL NOT be held, since no save runs.

#### Scenario: The fallback wait aborts the running save

- **WHEN** the fallback wait sends a held submit that a listener keeps on the page while Save Draft's save still runs
- **THEN** the request is aborted, its failure handler runs, no error is shown, the form is marked submitted and the page stays

#### Scenario: A save drained behind one answered inside $.ajax is aborted

- **WHEN** the timer's save is answered before `$.ajax` returns, the save a change handler queued behind it is drained inside that call, and the fallback wait sends a held submit while the drained save still runs
- **THEN** the drained save is aborted, its failure handler runs and no error is shown

#### Scenario: A submit made after the fallback wait sent one is not held

- **WHEN** the fallback wait sends a held submit that a listener keeps on the page, and the form is submitted again
- **THEN** the second submit goes through at once, with no overlay

#### Scenario: The saves queued behind the aborted save are dropped

- **WHEN** a save is queued behind a running one, and a held submit is sent by the fallback wait while the running save still runs
- **THEN** the running save is aborted, the queued save is not sent and its failure handler runs

#### Scenario: A dropped save's failure handler that throws does not stop the others

- **WHEN** two saves are queued behind the aborted save, and the first one's failure handler throws
- **THEN** the second one's failure handler runs, and neither save is sent

### Requirement: The draft save is a public asynchronous contract

`window.save_draft(callback, called_from_interval, on_failure)`, the same function as `App_post.save_draft_ajax`, SHALL return at once and run `callback(response)` when the save succeeds. `on_failure` SHALL run when the save is refused, fails, times out, answers with no draft or with a refusal that names no message, is aborted, is dropped or could not be sent. A failed request the user asked for SHALL show the translated `msg.draft_save_failed` message unless a submit is held on it; the timer's SHALL be retried silently a minute later. `App_post.submit_wait_ms` (15 s) and `App_post.save_timeout_ms` (30 s) SHALL be defaulted only when unset, so a value a plugin or theme set first is kept, `0` included.

#### Scenario: A failed save the user asked for is reported

- **WHEN** a save with a failure handler times out
- **THEN** the handler runs and the alert shows the translated failure message

#### Scenario: A failed save says nothing while a submit is held on it

- **WHEN** a save the user asked for fails while a submit is held on it, and a listener keeps the page when the submit goes out
- **THEN** the submit is dispatched once and no error is shown

#### Scenario: A failed timer save is retried silently

- **WHEN** the timer's save fails and the next tick runs with the form unchanged since
- **THEN** no error is shown and the form is sent again

### Requirement: Save Draft holds the form while it saves

Save Draft SHALL hold the form under the overlay while its save runs, leave to the post list on success, and give the form back with the refusal shown when the save is refused or fails. A Save Draft or Preview save that starts later than it was asked for (queued behind another save, or held back by a wrapper on `App_post.save_draft_ajax`) SHALL put the overlay back as it starts, the finished save's caller having taken it down; a plugin's queued save, one a change handler asks for while Save Draft's or Preview's save syncs the editors included, SHALL run as it was made, with no overlay put up for it. A Save Draft or Preview call such a wrapper does not pass on SHALL fail, taking the overlay down and closing Preview's window: at once when the wrapper throws before passing it on, otherwise once `App_post.save_timeout_ms` passed, after which the call SHALL be dropped if the wrapper still passes it on. A call passed on in time, or answered by the wrapper itself, SHALL NOT be failed by that timeout, however long it then waits in the queue. When another page was loaded in place by the time the save returns, with a post form of its own or none, Save Draft SHALL leave that page and its leave prompt alone: the draft is saved, the overlay comes down and the page stays. Save Draft clicked on a post form loaded in place before the editor was set up on it (the setup runs a moment after the form came), through a plugin's wrapper on `App_post.save_draft` or not, SHALL wait for that setup under the overlay, five seconds at most and while that form is on the page, and save that form.

#### Scenario: Save Draft returns to the list

- **WHEN** Save Draft is clicked on a new post with a title
- **THEN** the post list opens and the buffer holds the title

#### Scenario: Save Draft returning for a replaced form stays on the page

- **WHEN** the form is replaced by another form while Save Draft's save runs
- **THEN** the buffer holds the title, the overlay is gone, the page stays and the new form is not marked submitted

#### Scenario: Save Draft returning for a form that left for a page without one stays on the page

- **WHEN** the post list is loaded in place of the form while Save Draft's save runs
- **THEN** the buffer holds the title, the overlay is gone and the list stays

#### Scenario: Save Draft clicked before the form loaded in place was set up saves that form

- **WHEN** a new post's form is loaded in place of another post's, its title is typed and Save Draft is clicked before the editor was set up on it
- **THEN** the overlay is up and nothing is sent until the setup has run; then the new post's draft is saved, the post list opens and the first post has no draft

#### Scenario: Save Draft gives the page back when the setup does not come

- **WHEN** Save Draft is clicked on a post form loaded in place before the editor was set up on it, and the setup does not run within five seconds
- **THEN** the overlay comes down and nothing is sent, the setup running afterwards included

#### Scenario: Save Draft gives the page back when its form leaves before the setup

- **WHEN** Save Draft is clicked on a post form loaded in place before the editor was set up on it, and another post's form is loaded in its place and set up before that setup came
- **THEN** the overlay comes down, nothing is sent and the page stays

#### Scenario: Save Draft clicked through a wrapper before the setup is handed over

- **WHEN** a plugin wraps `App_post.save_draft` and Save Draft is clicked on a post form loaded in place before the editor was set up on it
- **THEN** the wrapper runs once and no error is raised; once the setup has run, that form's draft is saved and the post list opens

#### Scenario: A save of the form that left leaves the waiting click's overlay up

- **WHEN** Save Draft's save of a form returns while Save Draft, clicked on a post form loaded in its place, waits for that form's setup
- **THEN** the overlay stays up; once the setup has run, the second form's draft is saved and the post list opens

#### Scenario: Save Draft queued behind another save keeps the overlay

- **WHEN** Save Draft is clicked while a save whose callback takes the overlay down is running
- **THEN** the overlay is up while Save Draft's save runs, and the post list opens after it

#### Scenario: Preview queued behind another save keeps the overlay

- **WHEN** Preview is clicked while a save whose callback takes the overlay down is running
- **THEN** the overlay is up while Preview's save runs, and is gone once the window shows the draft

#### Scenario: Save Draft queued by a wrapper that defers the call keeps the overlay

- **WHEN** a wrapper on `App_post.save_draft_ajax` sends Save Draft's call a moment later, while a save whose callback takes the overlay down is still running
- **THEN** the overlay is up while Save Draft's save runs, and the post list opens after it

#### Scenario: Save Draft sent late by a wrapper puts the overlay back

- **WHEN** a wrapper on `App_post.save_draft_ajax` holds Save Draft's call back and sends it once the running save's callback took the overlay down
- **THEN** the overlay, down since that callback ran, goes up again as Save Draft's save starts, and the post list opens after it

#### Scenario: A Preview call a wrapper throws on fails at once

- **WHEN** a wrapper on `App_post.save_draft_ajax` throws before passing Preview's call on
- **THEN** no window stays open, the overlay is gone and the wrapper's error still reaches the page

#### Scenario: A Save Draft call a wrapper keeps fails once the save timeout passed

- **WHEN** a wrapper on `App_post.save_draft_ajax` keeps Save Draft's call past `App_post.save_timeout_ms`, then passes it on
- **THEN** the overlay comes down once the timeout passed, and the call passed on afterwards sends nothing

#### Scenario: A Save Draft call a wrapper passes on with its own callback keeps the overlay

- **WHEN** a wrapper on `App_post.save_draft_ajax` passes Save Draft's call on at once with a callback of its own, while a save whose callback takes the overlay down runs for longer than `App_post.save_timeout_ms`
- **THEN** the overlay stays up while the call waits and while its save runs, and the post list opens after it

#### Scenario: A Save Draft call a wrapper passed on in time is not failed while it waits

- **WHEN** a wrapper on `App_post.save_draft_ajax` passes Save Draft's call on a moment later, and the call waits in the queue for longer than `App_post.save_timeout_ms`
- **THEN** its save is sent once the running one returns, and the post list opens after it

#### Scenario: A Save Draft call the wrapper answered itself is not failed again

- **WHEN** a wrapper on `App_post.save_draft_ajax` runs the failure handler of Save Draft's call itself, and the next Save Draft is still saving once `App_post.save_timeout_ms` passed since the first
- **THEN** the overlay stays up while that save runs, and the post list opens after it

#### Scenario: A plugin's queued save gets no overlay

- **WHEN** `window.save_draft` is called while a save whose callback takes the overlay down is running
- **THEN** the overlay stays down while the queued save runs and after it

#### Scenario: A plugin save asked for during Save Draft's save gets no overlay

- **WHEN** a change handler calls `window.save_draft` while Save Draft's save syncs the editors, and Save Draft's save is refused
- **THEN** the refusal is shown, the plugin's save runs with the overlay down and the post has one buffer

#### Scenario: A refused Save Draft gives the editor back

- **WHEN** Save Draft's save is refused
- **THEN** the overlay was shown, the refusal is shown, the overlay is gone and the editor stays on the form
