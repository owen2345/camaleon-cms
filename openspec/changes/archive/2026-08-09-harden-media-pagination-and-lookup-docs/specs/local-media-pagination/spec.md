## Purpose

Keep the admin media browser scalable: list a folder as a lazy database relation so pagination is
applied at the database, and repair legacy thumbnail URLs only for the page actually rendered —
not by materializing and stat-ing the whole folder on every view.

## ADDED Requirements

### Requirement: The local uploader lists media as a lazy relation

`CamaleonCmsLocalUploader#objects` SHALL return the media collection as a lazy query relation for
the normal (no custom-hook) case, not a materialized array, so a caller paginating the result
retrieves only the requested page from the database (`LIMIT`/`OFFSET`) rather than loading the
whole folder into memory.

#### Scenario: objects returns a paginable relation

- **WHEN** `objects` is called for a folder with no `uploader_list_objects` hook registered
- **THEN** the result is an `ActiveRecord::Relation` (it responds to `limit`/`offset`), not an
  Array

#### Scenario: Pagination retrieves only the requested page

- **WHEN** the media browser paginates the `objects` result to a page size
- **THEN** the database query is bounded by that page size rather than the folder's total count

### Requirement: Legacy thumbnail repair runs on the rendered page only

The legacy-thumbnail URL fixup (which stats the filesystem per image) SHALL be applied through a
polymorphic page seam that the media controller invokes on the paginated page, not inside
`objects` over the whole folder. The seam SHALL be a no-op for uploaders without legacy
thumbnails (the base and S3 uploaders) and SHALL repair thumbnails for the local uploader.

#### Scenario: The rendered page still gets repaired thumbnails

- **WHEN** the media browser renders a page containing an image whose cached thumb URL points at
  a missing computed thumbnail while a legacy `.png` sibling exists on disk
- **THEN** that item's thumb URL on the rendered page is rewritten to the legacy `.png`

#### Scenario: The seam is a no-op for a non-local uploader

- **WHEN** the page seam is invoked on the base (or S3) uploader
- **THEN** the items are returned unchanged

#### Scenario: The fixup does not run over the whole folder

- **WHEN** `objects` is called for a folder
- **THEN** the per-image legacy-thumbnail filesystem check is not performed inside `objects`
