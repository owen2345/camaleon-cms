# Tasks

## 1. Refuse a file with a fatal XML error

- [x] 1.1 Add `spec/requests/security/upload_malformed_xml_scan_spec.rb` and the "a file that is
  not well-formed XML" examples of `spec/lib/svg_content_checker_spec.rb`. Move the uploader of the
  request specs to `spec/support/media_only_uploader.rb`. Verify: the examples for a refusal fail on
  the current code
- [x] 1.2 Parse an XML file in strict mode in `CamaleonCms::SvgContentChecker` (design D1). Verify:
  the specs of 1.1 pass, and the adjacent upload specs pass
- [x] 1.3 Add a section to `docs/upgrading-to-2.9.5.md`, and name the rule in
  `docs/security/permissions.md`. Verify: the anchor of the at-a-glance row resolves, and the
  Markdown gate prints no line

## Workflow follow-up

- Archive the change on the branch before the merge.
