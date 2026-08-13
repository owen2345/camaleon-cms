# Design

## D1. The ACL is the storage-level gate

Private media has two independent gates: the application (`download_private_file`, which checks the
request) and the object storage (the S3 ACL). The app gate is meaningless if the object is
`public-read` at a guessable key — anyone can skip the app and fetch `s3://bucket/private/<name>`
directly. Private mode changed only the key prefix and the URL the media browser renders; the ACL
stayed `public-read`, so the storage gate was effectively open. The fix closes it at the point of
upload.

## D2. Owner-only ACL, no serving regression

The canned ACL becomes `is_private_uploader? ? 'private' : 'public-read'`. `'private'` is S3's
owner-only ACL, so the object is retrievable only with the account credentials. That does not break
legitimate downloads: `download_private_file` calls `fetch_file`, which pulls the object through the
authenticated SDK (`bucket.object(key).download_file`) and streams it with `send_file` — it never
relies on a public object URL. So the private-file path works identically before and after; only the
anonymous, gate-bypassing path is removed.

## D3. Scope

- Only `add_file` sets an ACL. `add_folder` writes a zero-byte marker with `put(body: nil)` and no ACL
  (it inherits the bucket default), so it needs no change.
- Thumbnails are uploaded through the same `add_file` (with `is_thumb: true`), so in private mode a
  thumbnail is now stored `'private'` too — correct, since a private image's thumbnail must not be
  world-readable either.
- The `aws_file_upload_settings` hook still receives `{ acl: … }` and can override, so an operator with
  a bespoke ACL policy keeps the seam.

## D4. What the fix does not do

It does not retroactively repair objects already stored `public-read` under `private/` — those keep
their ACL until re-uploaded. That is called out for upgraders as an operator action; rewriting existing
object ACLs is a data migration outside this behavioral fix.

## D5. Testing

`spec/uploaders/aws_uploader_spec.rb` already pins the public case (`acl: 'public-read'`). The change
adds the private-mode counterpart: a private uploader's `add_file` must call `upload_file` with
`acl: 'private'`. It fails against master (which sends `public-read`), verified by stashing the fix.
