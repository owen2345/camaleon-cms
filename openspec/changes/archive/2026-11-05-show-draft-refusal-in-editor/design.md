# Design

## Context

`draft_request` in `_post.js` has two answers for a refusal and a failure. A 200 with `error`
messages (the meta, option and status refusals of `DraftsController`) is a refusal: the alert shows
the messages, the held submit is dropped and the timer waits for a change. Any error status is a
failed request: a generic alert, and the timer retries a minute later. `AdminController` answers a
refused custom-field value with the message as text and a 422, which went to the failed-request path.

## Decisions

**D1. The script reads a plain-text 422 with a message as a refusal.** The `error` handler of
`draft_request` takes `xhr.responseText` of a `text/plain` 422 as the refusal and runs the same
`refused` function as the 200 path. A 422 of another type is an error page, for example the JSON or
HTML of a CSRF failure, and is a failed request. The shared answer of `AdminController` does not change. Rejected: a rescue in
`DraftsController` that answers `{ error: [...] }` with a 200. It would give the draft save an answer
of its own, apart from the requirement that every other XHR gets a 422, and a plugin that answers a
plain-text 422 with a message of its own would still show the generic alert.

**D2. A 422 with no message is a failed request.** The script has nothing to show, so the generic
alert stays, and the timer retries.

**D3. The buffer keeps what the save stored before the custom-field values.** `DraftsController`
saves the buffer and then writes the values, and `AdminController` records that each save other
than the post save keeps what it stored before the values. The script does not learn the id of a
buffer that a refused create made, as before. The next save of a new post creates another buffer.
Left as is: the buffer of a post with a parent is found again by the parent.
