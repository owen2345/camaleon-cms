# Tasks: permission-gated-upload-scanning

## 1. The permission

- [ ] 1.1 Add `media_unfiltered_upload` to `UserRole::ROLES[:manager]` with a `danger` colour and
      an i18n label/description carrying inline defaults, matching `contact_form_unfiltered_html`.
- [ ] 1.2 Spec that the role editor offers it, that a granted role satisfies
      `can?(:manage, :media_unfiltered_upload)`, and that the default Editor and Contributor roles
      do not.

## 2. Gate the scan on the permission

- [ ] 2.1 Add `cama_trusted_for_unfiltered_upload?` to `CamaleonCms::UploaderContentSecurity`,
      mirroring `Post#trusted_for_unfiltered_html?`: `CurrentRequest` user + site, fail closed on
      blank or on error.
- [ ] 2.2 Gate all three scan sites in `UploaderPipeline` on it — `upload_file`, `cama_tmp_upload`
      and `cama_stage_data_uri` — checking the permission before reading the file.
- [ ] 2.3 Remove the `source_already_public` locals and `cama_source_already_public?`.
- [ ] 2.4 Spec the bypass end to end: an SVG the SVG ruleset accepts, re-cropped as `.html`, is
      rejected for an untrusted user and accepted for a permitted one.
- [ ] 2.5 Spec that a private-media source and a remote source are still scanned, and that a
      permitted user's matching content is accepted.

## 3. Align the SVG ruleset

- [ ] 3.1 Add `form meta base style link` to `SvgContentChecker::BANNED_TAGS`.
- [ ] 3.2 Spec each of the five as rejected, and re-confirm `animate`/`set` still accepted.

## 4. Ship

- [ ] 4.1 `bin/rubocop -A` on touched files, `bin/brakeman --no-pager`,
      `(cd spec/dummy && bin/rails zeitwerk:check)`, `bin/rspec`.
- [ ] 4.2 Open the PR, then add the changelog entry referencing it.
- [ ] 4.3 Archive this change on the branch, before merge.
