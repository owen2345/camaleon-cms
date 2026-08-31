# media-visibility-flag-integrity Delta

## Purpose

`media.is_public` is a public column with obvious semantics, and `Site#public_media` /
`Site#private_media` are public associations named for what they contain. The stored flag and the
association a row lands in MUST reflect the file's real visibility, so that any direct consumer of
the column or the associations — reports, exports, migrations, ecosystem plugins, future
visibility features — reads the truth rather than its inverse.

## ADDED Requirements

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

### Requirement: A convergent repair derives stored flags from storage

The system SHALL provide a rake task `camaleon_cms:repair_media_visibility` that purges cached
media rows and rebuilds the cache from storage through the corrected routing, so every rebuilt
row's `is_public` derives from where the file actually lives. The repair SHALL be convergent:
it SHALL NOT transform any row in place, SHALL NOT rely on a run-once guard, and re-running it —
including on an already-correct database — SHALL reproduce the same correct state and never turn
a correct flag into a wrong one.

#### Scenario: Pre-fix rows are replaced by storage-derived rows

- **WHEN** the repair runs against media rows persisted with the pre-fix (inverted) flag
- **THEN** the cached rows are purged and the rebuilt rows carry the `is_public` value matching
  each file's real storage location

#### Scenario: Re-running the repair converges

- **WHEN** the repair has already completed and is invoked again
- **THEN** the resulting rows are identical to the first run's, with no duplicates
- **AND** no correct flag is inverted

#### Scenario: A phantom row is removed

- **WHEN** the repair encounters a cached row whose file no longer exists in storage
- **THEN** the row is purged and not recreated by the rebuild
