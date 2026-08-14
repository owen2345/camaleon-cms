# Require a CSRF token on media#upload (M7)

## Why

`MediaController` carried `skip_before_action :verify_authenticity_token, only: :upload`, so the file
upload endpoint accepted a cross-site POST with no CSRF token. A page the victim visits could drive
their authenticated admin session to upload attacker-chosen files (and, through the avatar/crop
flows the uploader feeds, write model state). Rails' `protect_from_forgery with: :exception` covers
every other admin write; this one action opted out. Audit finding M7. (The companion URL-string
SSRF half was already closed via `cama_upload_url_error` → `UserUrlValidator`; the non-http string
branch is confined to the public/tmp roots by `cama_canonical_upload_path`.)

### Triage verdict: legit

The skip is present at `media_controller.rb:6`; a token-less `POST /admin/media/upload` is accepted.
Reproduced in `spec/requests/security/media_upload_csrf_spec.rb` (forgery protection is disabled
globally in the test env, so the example enables it): before the fix the POST is accepted, after it
raises `ActionController::InvalidAuthenticityToken`.

## What Changes

- Remove the `verify_authenticity_token` skip so `upload` is CSRF-protected like every other admin
  write.
- The multipart uploader (jQuery `uploadFile`) posts outside jquery_ujs' ajax prefilter, so it now
  sends the token as an `authenticity_token` form field via the plugin's `dynamicFormData` hook. The
  url-upload path (`$.fn.upload_url`) already posts through `media#actions` — a separate,
  never-skipped action — with the header jquery_ujs attaches, so it is unaffected.

## Ecosystem consumers (surveyed clones + `docs/ai/ecosystem.md`)

Per `ecosystem-plugin-bindings`: no surveyed repository POSTs to core's `media#upload` with its own
transport. `camaleon_editor` reaches uploads through core's own `input_upload_field` →
`upload_filemanager` → the same `uploadFile` instance, so the token fix covers it. The `file_upload`
matches in `camaleon_website`'s store plugin and `florsan` are their own upload flows, not core's
endpoint.

## Notes for upgraders

- Any external script that POSTed to `/admin/media/upload` without a CSRF token stops working; send
  the `authenticity_token` form field (or the `X-CSRF-Token` header). First-party uploaders are
  updated.
