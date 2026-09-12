## 1. Branch

- [x] 1.1 Create `security/guard-post-decorator-class` from `master` per `docs/ai/workflows.md` Phase 1 (verify: `git branch --show-current`)

## 2. Reproduce (each spec fails on master before section 3)

- [x] 2.1 Request spec `spec/requests/security/post_decorator_class_option_spec.rb`: a settings manager's post type save with an anonymous `updated_post_type` hook writing `Object` into the option ends in a flash error, the option stays unset and the type's posts decorate with `CamaleonCms::PostDecorator` (verify: `bin/rspec spec/requests/security/post_decorator_class_option_spec.rb` fails on master, passes after 3.1 to 3.3)
- [x] 2.2 Model spec `spec/models/camaleon_cms/post_type_decorator_class_spec.rb`: `set_option`, `set_options` and `set_multiple_options` refuse a non-decorator class and an unknown name with an error naming the option and value while the stored options survive; a subclass and a blank value are accepted; other options are unaffected; a stored non-decorator value resolves to the default decorator with a warning and is not rewritten; a post without a post type decorates with the default (verify: the spec fails on master, passes after 3.1 and 3.2)
- [x] 2.3 Extend `spec/lib/tasks/unsafe_stored_content_rake_spec.rb`: a post type with a stored non-decorator value is reported, one with a subclass or blank value is not (verify: fails on master, passes after 3.4)

## 3. Implement

- [x] 3.1 `PostType.decorator_class_for(value)`, `PostType#post_decorator_class` and the `set_meta` override that refuses with `ActiveRecord::RecordInvalid` (verify: 2.2 passes)
- [x] 3.2 `Post#decorator_class` delegates to `post_type.post_decorator_class`, keeping the default for a post without a post type (verify: 2.2's read examples pass)
- [x] 3.3 `CamaleonCms::AdminController` rescues `RecordInvalid` for `PostType` records with the flash-and-redirect path, comment updated (verify: 2.1 passes)
- [x] 3.4 `lib/tasks/unsafe_stored_content.rake` lists post types whose stored option would be refused (verify: 2.3 passes)

## 4. Documentation

- [x] 4.1 `docs/security/permissions.md`: a section for the option under the existing security sections (verify: section present, cites this capability)
- [x] 4.2 `docs/upgrading-to-2.9.5.md`: a note for theme and plugin developers and the operator scan step (verify: sections present, anchors resolve)
- [x] 4.3 `docs/ai/ecosystem.md`: refresh the camaleon-cms-seo row for its PR #53 binding (verify: row text)
- [x] 4.4 `CHANGELOG.md` entry under Unreleased after the PR exists, under 500 characters, linking the upgrade notes (verify: `docs/ai/workflows.md` Phase 4.3)

## 5. Verify and close out

- [x] 5.1 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
- [x] 5.2 Run `/opsx:verify` and address its findings
- [x] 5.3 Run `/opsx:archive` on the branch and commit the archive in the PR (verify: `openspec/specs/post-decorator-class-integrity/spec.md` exists, change moved under `openspec/changes/archive/`)
