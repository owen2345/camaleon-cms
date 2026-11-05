# Show a refused custom-field value in the draft save of the post editor

## Why

The change `answer-xhr-refusal-with-422` made a refused admin save answer an XHR with the message as
text and a 422. The draft save of the post editor is such an XHR. Its script read a 422 as a failed
request and showed "The draft could not be saved", as it did for the redirected page before. The
author did not learn which value was refused, and why.

## What Changes

- The draft script reads a 422 with a message as a refusal of the draft's content, as it reads a
  200 with `error` messages: the alert shows the message as text, the post stays on the form, a
  held submit is dropped, and the timer sends nothing until the form changes.
- A 422 with no message stays a failed request.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: the post editor shows the refusal of a draft save.

## Impact

- `app/assets/javascripts/camaleon_cms/admin/_post.js` (`draft_request`).
- Specs: a new `spec/features/admin/post_draft_refused_value_spec.rb`.
- `docs/upgrading-to-2.9.5.md` names the new message.
