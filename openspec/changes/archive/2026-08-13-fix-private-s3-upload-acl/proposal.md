## Why

The S3 uploader (`camaleon_cms_aws_uploader.rb`) stored every upload with `acl: 'public-read'` — even
in private mode, where only the key prefix (`private/`) changed. So a private upload was world-readable
at a guessable `s3://bucket/private/<name>` URL, bypassing the `download_private_file` access gate
entirely: the application checked permissions, but the object storage did not. Distinct from
CVE-2026-1776 (the path traversal, already fixed). Audit finding M5.

### Triage verdict: legit

`add_file` passes `{ acl: 'public-read' }` unconditionally (`:103`); `is_private_uploader?` gates only
the key prefix and the returned URL, never the ACL. Reproduced in `spec/uploaders/aws_uploader_spec.rb`:
a private-mode `add_file` uploads with `acl: 'public-read'`, failing without the fix (stash-verified).

## What Changes

- `add_file` derives the canned ACL from the upload mode: a private-mode upload is stored `'private'`
  (owner-only); a public upload keeps `'public-read'`.
- Legitimate private serving is unaffected: `download_private_file` fetches through the authenticated S3
  API (`fetch_file` → `download_file`), not a public object URL, so an owner-only ACL still downloads.
- The `aws_file_upload_settings` hook still receives the settings hash and can override the ACL.

## Notes for upgraders

- New private uploads are stored owner-only. Objects **already** uploaded under `private/` keep their
  `public-read` ACL until re-uploaded — an operator storing sensitive media privately should repair the
  ACL of existing objects under the `private/` prefix (e.g. a one-off `aws s3api put-object-acl` sweep).

## Out of scope

- The local filesystem uploader: its private files live outside the web-served path and are streamed by
  `download_private_file`, so they were never world-readable this way.
- Retroactive ACL repair of already-stored objects (operator action, above).
