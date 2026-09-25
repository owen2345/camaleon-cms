# post-editor-draft-autosave Specification

## Purpose
The admin post editor autosaves a draft buffer every minute while the form differs from its saved
state, so an editor's unpublished work survives a crash or a closed tab and Preview can show it. This
capability states what the minute timer sends and when, how the load baseline and the comparison read
the form without rewriting it, the asynchronous one-at-a-time draft save and its public contract for
plugins (`window.save_draft`), the Preview link and window, and what happens to a post submitted while a
draft save is running. The server side of the same endpoint is `draft-authorization`.

## Requirements

### Requirement: The minute autosave sends only a form changed since its last successful save

The post editor's minute timer SHALL send a draft save only when the form differs from the state the last successful draft save sent, read after the editors were written into their textareas, and SHALL send nothing before the load baseline has been taken. A save the user asks for (Save Draft, Preview, a plugin's call) SHALL always be sent. The draft id field SHALL NOT count as a change.

#### Scenario: An unchanged form is not re-sent

- **WHEN** the title is edited and an autosave tick runs, then a second tick runs with no further edit
- **THEN** one draft request is sent, and a third tick after another edit sends a second

#### Scenario: A field written by an editor's change handler is recorded as sent

- **WHEN** a change handler on the content textarea writes a derived hidden field, the editor content is changed and an autosave tick runs
- **THEN** one request is sent, and the next tick sends nothing

#### Scenario: A second language of a translated field is autosaved

- **WHEN** the site has two languages and only the second language's title and content are edited
- **THEN** the next tick sends the draft with both values encoded, and the tick after it sends nothing

### Requirement: The load baseline is taken once the form's editors are ready, and the comparison reads them

The baseline the leave-page prompt compares against SHALL be taken once every TinyMCE editor inside the post form has initialized, re-checked on each editor's `init` event, and taken as the form stands after ten seconds if an editor never comes up. The comparison SHALL read each editor's content from the editor, SHALL NOT write into its textarea, SHALL ignore an editor outside the form, and SHALL leave out the draft id field and the hidden original of a translated field. Fields SHALL be matched to editors by their own id, so a field whose id is an inherited object property name is still compared.

#### Scenario: An untouched post with a late editor stays unchanged

- **WHEN** the content editor initializes three seconds after the page loaded and the post is not edited
- **THEN** an autosave tick sends nothing and the leave-page prompt returns nothing

#### Scenario: The comparison leaves a plugin's textarea export alone

- **WHEN** a plugin writes content with `rgb()` colors into the content textarea and the leave-page prompt runs
- **THEN** the textarea still holds the content as written

#### Scenario: An editor outside the form is not the post's content

- **WHEN** a plugin creates an editor outside the post form and types into it
- **THEN** an autosave tick sends nothing and the leave-page prompt returns nothing

#### Scenario: A field named after an inherited property is compared

- **WHEN** a hidden field with id `constructor` is added, saved once, then edited
- **THEN** the next tick sends a draft

#### Scenario: A baseline wait that outlives its form leaves the next form alone

- **WHEN** the script is set up on another form before the first form's editor comes up
- **THEN** neither form gets a baseline from the first wait, and the prompt does not fail on a page without a post form

### Requirement: Draft saves are asynchronous and run one at a time

A draft save SHALL NOT block the page. One save SHALL run at a time: a save requested while one runs SHALL wait for it and reuse the draft id it returns, so a new post never gets a second buffer; a queued timer call with nothing to send SHALL NOT hold up the saves behind it; a queued call SHALL be run by the editor's own function, so a wrapper a plugin installed on `App_post.save_draft_ajax` runs once per call. The lock SHALL be taken before the editors are synced into their textareas, so a save a change handler asks for queues behind the one being prepared. The lock SHALL be released whatever the outcome, including a success callback that throws and a save that throws before it is sent (a change handler, `$.ajax`), in which case the caller's failure handler SHALL run. A save that has not returned after `App_post.save_timeout_ms` SHALL be taken as failed. A refused save SHALL show its messages as text, run no success callback, and drop the timer calls queued behind it; a user's queued call still runs. The draft id and Preview links SHALL be written into the form the save was sent from. A queued call run after the page loaded another form in place SHALL be dropped, its failure handler run, and never sent for that form.

#### Scenario: Two overlapping autosaves create one buffer

- **WHEN** a second autosave tick starts while the first save of a new post is in flight
- **THEN** one buffer exists, holding the second tick's values

#### Scenario: The saves queued behind an idle timer call run

- **WHEN** a user's save, a timer call and another user's save with a callback are queued in that order
- **THEN** the callback runs

#### Scenario: A throwing callback does not hold the lock

- **WHEN** a save's success callback throws
- **THEN** a later save runs and its callback runs

#### Scenario: A send that throws runs the failure handler and frees the lock

- **WHEN** `$.ajax` throws before sending a draft request
- **THEN** the error reaches the caller, the failure handler runs, and a later save runs

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

#### Scenario: A timer call queued behind a refused save is dropped

- **WHEN** a save is refused while a timer call waits behind it
- **THEN** the refusal is shown and no second request is sent

#### Scenario: A late response writes into its own form

- **WHEN** the form is replaced by another post form while a save is in flight
- **THEN** the draft id and Preview link of the form the save was sent from name the draft, and the new form's stay empty

#### Scenario: A queued save whose form was replaced is dropped

- **WHEN** a save is queued behind a running one and the form is replaced by another form before it runs
- **THEN** the queued save is not sent, its failure handler runs, and the first save's draft keeps its content

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

A post form submitted while a draft save is running SHALL be held under the loading overlay before validation or any other submit listener sees it, until that save and the saves queued behind it finish (the overlay kept while they run) or `App_post.submit_wait_ms` passes. The submit SHALL then be dispatched again in full to the form it was held on, so validation, every listener, delegated ones included, and the form's default action run once, with the draft id in the form. A refused save SHALL release the hold and keep the post on the form, consuming a validator skip (`cancelSubmit`) the held submit carried, so the next submit is validated; a failed request SHALL let the submit go; a held form that left the page SHALL NOT be sent.

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

#### Scenario: The overlay stays while a queued save runs

- **WHEN** the submit was held behind a save whose caller takes the overlay down, with another save queued
- **THEN** the overlay is up while the queued save runs, and the post is created after it

#### Scenario: A queued save that throws lets the held submit go

- **WHEN** a submit is held behind a save while a queued save waits, and the queued save throws before it is sent
- **THEN** the post is saved well before `App_post.submit_wait_ms` has passed

#### Scenario: A replaced form is not sent

- **WHEN** the held form is replaced by another form before the hold ends
- **THEN** the replacement is neither submitted nor marked submitted

### Requirement: The draft save is a public asynchronous contract

`window.save_draft(callback, called_from_interval, on_failure)`, the same function as `App_post.save_draft_ajax`, SHALL return at once and run `callback(response)` when the save succeeds; `on_failure` SHALL run when the save is refused, the request fails, times out or could not be sent. A failed request the user asked for SHALL be reported with the translated `msg.draft_save_failed` message; the timer's SHALL be retried silently a minute later. `App_post.submit_wait_ms` (15 s) and `App_post.save_timeout_ms` (30 s) SHALL be defaulted only when unset, so a value a plugin or theme set before the editor came up, `0` included, is kept. Save Draft SHALL hold the form under the overlay while its save runs, leave to the post list on success, and give the form back with the refusal shown when the save is refused or fails.

#### Scenario: A failed save the user asked for is reported

- **WHEN** a save with a failure handler times out
- **THEN** the handler runs and the alert shows the translated failure message

#### Scenario: Save Draft returns to the list

- **WHEN** Save Draft is clicked on a new post with a title
- **THEN** the post list opens and the buffer holds the title

#### Scenario: A refused Save Draft gives the editor back

- **WHEN** Save Draft's save is refused
- **THEN** the overlay was shown, the refusal is shown, the overlay is gone and the editor stays on the form
