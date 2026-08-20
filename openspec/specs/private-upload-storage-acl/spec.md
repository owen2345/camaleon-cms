# private-upload-storage-acl Specification

## Purpose
Ensure a private-mode upload to cloud object storage is stored so it is not publicly retrievable. The
application-level private-file gate (`download_private_file`) is only meaningful if the stored object is
not world-readable at its own — guessable — key. This capability pins the storage-level ACL that makes
private media actually private.
## Requirements
### Requirement: Private-mode uploads are stored with an owner-only ACL

The cloud (S3) uploader SHALL store a private-mode upload with an owner-only canned ACL (`private`), and
a public-mode upload with a `public-read` ACL. The ACL SHALL be derived from the uploader's private
mode, independent of the object key or folder prefix, and SHALL apply to both content files and their
thumbnails. Serving a private file SHALL use the authenticated storage API rather than a public object
URL, so the owner-only ACL does not prevent an authorized download through the private-file gate.

#### Scenario: A private upload is not world-readable

- **WHEN** the uploader is in private mode and stores a file
- **THEN** the object is written with an owner-only (`private`) ACL, not `public-read`

#### Scenario: A public upload stays publicly readable

- **WHEN** the uploader is in public (default) mode and stores a file
- **THEN** the object is written with a `public-read` ACL

### Requirement: Pre-existing private objects can be swept back to owner-only

The gem SHALL provide a repair task (`camaleon_cms:repair_private_upload_acls`) that re-applies the
owner-only ACL to every object already stored under a site's private prefix — including a configured
`inner_folder` root (`<inner_folder>/private/...`) — for uploads that predate write-time ACL
enforcement.

#### Scenario: The repair task re-ACLs stored private objects

- **WHEN** the repair task runs for an AWS-backed site with objects under its private prefix
- **THEN** each object under that prefix is set to the owner-only (`private`) ACL

