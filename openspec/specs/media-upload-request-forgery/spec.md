# media-upload-request-forgery Specification

## Purpose
The admin media upload endpoint writes files (and feeds the avatar/crop flows that write model
state), so it must be protected by the same CSRF check as every other admin write. A forged
cross-site POST must not be able to upload on a signed-in admin's behalf, and the first-party
uploader must carry the CSRF token even though its multipart transport bypasses jquery_ujs' ajax
prefilter.
## Requirements
### Requirement: The media upload endpoint verifies the CSRF token

`MediaController#upload` SHALL NOT skip `verify_authenticity_token`. A `POST /admin/media/upload`
that carries no valid CSRF token SHALL be rejected without uploading, exactly as any other admin
write. The first-party multipart uploader SHALL carry the token as an `authenticity_token` form
field (its transport posts outside jquery_ujs' ajax prefilter); the url-upload path posts through
the separately CSRF-protected `media#actions` action and is unaffected.

#### Scenario: A token-less upload POST is refused

- **WHEN** a signed-in admin's browser is made to POST `/admin/media/upload` with no CSRF token
- **THEN** the request is rejected and no file is uploaded

#### Scenario: The first-party uploader carries the token

- **WHEN** the admin media manager uploads a file through its multipart uploader
- **THEN** the request carries the CSRF token as a form field and the upload succeeds as before

