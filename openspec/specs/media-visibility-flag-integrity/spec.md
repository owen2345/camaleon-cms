# media-visibility-flag-integrity Specification

## Purpose
`media.is_public` is a public column with obvious semantics, and `Site#public_media` /
`Site#private_media` are public associations named for what they contain. The stored flag and the
association a row lands in MUST reflect the file's real visibility, so that any direct consumer of
the column or the associations — reports, exports, migrations, ecosystem plugins, future
visibility features — reads the truth rather than its inverse.

## Requirements

### Requirement: Stored is_public reflects real visibility

The media collection a file is written to and read from SHALL be the one whose `is_public` value
matches the file's real visibility: the private uploader mode maps to the `is_public: false`
collection and the public uploader mode to the `is_public: true` collection. A file uploaded
privately SHALL persist `is_public: false`; a file uploaded publicly SHALL persist
`is_public: true`.

#### Scenario: A privately uploaded file stores is_public false

- **WHEN** a file is cached through an uploader in private mode
- **THEN** its media row persists `is_public: false`
- **AND** the uploader's media collection is the site's `private_media`

#### Scenario: A publicly uploaded file stores is_public true

- **WHEN** a file is cached through an uploader in public mode
- **THEN** its media row persists `is_public: true`
- **AND** the uploader's media collection is the site's `public_media`

### Requirement: Visibility associations return the collection their name denotes

`Site#public_media` SHALL return exactly the site's genuinely public media (files uploaded in
public mode) and `Site#private_media` SHALL return exactly its genuinely private media. A direct
read of either association SHALL NOT return files of the opposite visibility.

#### Scenario: public_media excludes privately uploaded files

- **WHEN** a site has both a publicly uploaded file and a privately uploaded file
- **THEN** `site.public_media` includes the public file and excludes the private file
- **AND** `site.private_media` includes the private file and excludes the public file

### Requirement: A one-time back-fill corrects existing rows exactly once

The system SHALL provide a rake task `camaleon_cms:backfill_media_is_public` that inverts
`is_public` on every existing non-NULL media row so pre-fix data matches the corrected semantics,
within a single transaction, guarded so that a second invocation makes no change.

#### Scenario: Back-fill inverts pre-fix rows

- **WHEN** the back-fill runs against media rows persisted with the pre-fix (inverted) flag
- **THEN** each non-NULL row's `is_public` is inverted so it matches the file's real visibility

#### Scenario: Re-running the back-fill is a no-op

- **WHEN** the back-fill has already completed and is invoked again
- **THEN** no media row's `is_public` changes
- **AND** the task reports that the back-fill already ran

#### Scenario: A NULL is_public row is left unchanged

- **WHEN** the back-fill encounters a row whose `is_public` is NULL
- **THEN** that row's `is_public` remains NULL
