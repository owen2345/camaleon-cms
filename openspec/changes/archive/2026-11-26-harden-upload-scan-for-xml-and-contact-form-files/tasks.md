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

## 2. Refuse a stylesheet instruction and the XSLT namespace

- [x] 2.1 Add `spec/requests/security/upload_stylesheet_scan_spec.rb` and the "stylesheets"
  examples of `spec/lib/svg_content_checker_spec.rb`. Verify: the examples for a refusal fail on
  the code of group 1
- [x] 2.2 In `CamaleonCms::SvgContentChecker`, refuse an `xml-stylesheet` processing instruction
  and a declaration of the XSLT namespace (design D2, D3). Verify: the specs of 2.1 pass, and the
  adjacent upload specs pass
- [x] 2.3 Add a section to `docs/upgrading-to-2.9.5.md`, and name the rule in
  `docs/security/permissions.md`. Verify: the Markdown gate prints no line for the new text

## 3. List the contact form files in the stored-upload task

- [x] 3.1 Add the "with a file that a contact form stored" examples to
  `spec/lib/tasks/unsafe_stored_uploads_rake_spec.rb`, with one example for the folder of a site
  that does not exist. Verify: the examples fail on the current task
- [x] 3.2 Scan the whole `public/contact_form` folder in
  `lib/tasks/unsafe_stored_uploads.rake` (design D4). Verify: the spec of the task passes
- [x] 3.3 Name the folder in `docs/upgrading-to-2.9.5.md` and `docs/security/permissions.md`.
  Verify: the Markdown gate prints no line for the new text

## 4. Decode the named references of a scheme

- [x] 4.1 Add `spec/requests/security/upload_named_reference_scheme_spec.rb`, and the examples for
  a named reference to `spec/lib/camaleon_cms/uploader_content_security_spec.rb`. Verify: the
  examples for a refusal fail on the current code
- [x] 4.2 Decode the eight named references in `CamaleonCms::ContentSecurity.normalize`, and remove
  the control characters before the decode (design D5). Verify: the specs of 4.1 pass, and the
  adjacent specs pass
- [x] 4.3 Add a section to `docs/upgrading-to-2.9.5.md`, and name the rule in
  `docs/security/permissions.md`. Verify: the anchor of the at-a-glance row resolves, and the
  Markdown gate prints no line for the new text

## 5. Refuse a dropped scheme reference in a file with entities

- [x] 5.1 Add the examples for a file that declares an entity to
  `spec/requests/security/upload_named_reference_scheme_spec.rb` and to
  `spec/lib/svg_content_checker_spec.rb`. Verify: the examples for a refusal fail on the current code
- [x] 5.2 In `CamaleonCms::SvgContentChecker`, refuse a file that declares an entity when the
  expanded parse reports one of the eight names (design D6). Refuse it also at the report limit.
  Verify: the specs of 5.1 pass, and the adjacent upload specs pass
- [x] 5.3 Name the rule in `docs/upgrading-to-2.9.5.md` and in `docs/security/permissions.md`.
  Verify: the Markdown gate prints no line for the new text

## 6. Refuse the XSLT namespace with a dropped reference

- [x] 6.1 Add the examples for a namespace with a named reference to
  `spec/requests/security/upload_stylesheet_scan_spec.rb` and to
  `spec/lib/svg_content_checker_spec.rb`. Verify: the examples for a refusal fail on the current code
- [x] 6.2 In `CamaleonCms::SvgContentChecker`, compare each namespace and the XSLT namespace
  without the characters of the eight names (design D7). Verify: the specs of 6.1 pass, and the
  adjacent upload specs pass
- [x] 6.3 Name the rule in `docs/upgrading-to-2.9.5.md`. Verify: the Markdown gate prints no line
  for the new text

## 7. Read an HTML file with the HTML5 parser too

- [x] 7.1 Add `spec/requests/security/upload_html_parser_scan_spec.rb`, and the examples for an HTML
  file that a browser parses in another way to `spec/lib/svg_content_checker_spec.rb`. Verify: the
  examples for a refusal fail on the current code
- [x] 7.2 In `CamaleonCms::SvgContentChecker`, parse an HTML file with `Nokogiri::HTML5` too, and
  run each check on both trees (design D8). Verify: the specs of 7.1 pass, and the adjacent upload
  specs pass
- [x] 7.3 Add a section to `docs/upgrading-to-2.9.5.md`, and name the rule in
  `docs/security/permissions.md`. Verify: the anchor of the at-a-glance row resolves, and the
  Markdown gate prints no line for the new text

## 8. Verify

- [x] 8.1 Run the checks of `AGENTS.md` "Verify before pushing", and `openspec validate --all
  --strict`. Verify: each check passes

## Workflow follow-up

- Archive the change on the branch before the merge.
