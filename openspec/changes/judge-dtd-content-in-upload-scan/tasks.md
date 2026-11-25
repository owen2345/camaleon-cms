# Tasks

## 1. Reproduce the gap

- [x] 1.1 Add `spec/requests/security/upload_dtd_entity_scan_spec.rb`. A user with the `media`
  permission, and without `media_unfiltered_upload`, sends each file to the media endpoint. Verify:
  the examples for a refusal fail on the current code, and the examples for a harmless file pass.
  The example for one large entity does not return on the current code, because ImageMagick reads
  the accepted file
- [x] 1.2 Add the "DTD entities" examples to `spec/lib/svg_content_checker_spec.rb`. Verify: the
  examples for a refusal fail on the current code

## 2. Read the expanded document

- [x] 2.1 In `CamaleonCms::SvgContentChecker`, refuse a file that declares an entity of another
  resource (design D2). Parse a file that declares an entity again with entity expansion, and give
  that tree to the checks (design D1, D3, D4). Verify: the specs of 1.1 and 1.2 pass, and the
  adjacent upload specs pass
- [x] 2.2 Add a section and an at-a-glance row to `docs/upgrading-to-2.9.5.md`, and name the rule in
  `docs/security/permissions.md`. Verify: the anchor of the row resolves to the heading of the
  section, and the Markdown gate prints no line

## 3. Judge the attribute defaults of the DTD

- [x] 3.1 Add the "an attribute default of the DTD" examples to
  `spec/requests/security/upload_dtd_entity_scan_spec.rb`, and the "DTD attribute defaults" examples
  to `spec/lib/svg_content_checker_spec.rb`. Verify: the examples for a refusal fail on the code of
  group 2
- [x] 3.2 In `CamaleonCms::SvgContentChecker`, apply the handler rule and the scheme rule to each
  attribute default of the DTD (design D5). Verify: the specs of 3.1 pass
- [x] 3.3 Name the rule in the section of `docs/upgrading-to-2.9.5.md` and in
  `docs/security/permissions.md`. Verify: the Markdown gate prints no line

## 4. Verify

- [x] 4.1 Run the checks of `AGENTS.md` "Verify before pushing". Verify: each of the four checks
  passes
- [x] 4.2 Run `openspec validate --all --strict`. Verify: no error and no warning

## Workflow follow-up

- Add the changelog entry after the PR exists.
- Archive the change on the branch before the merge.
