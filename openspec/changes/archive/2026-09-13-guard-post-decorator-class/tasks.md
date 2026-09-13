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
- [x] 4.3 `CHANGELOG.md` entry under Unreleased after the PR exists, under 500 characters, linking the upgrade notes (verify: `docs/ai/workflows.md` Phase 4.3)

## 5. Verify and close out

- [x] 5.1 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
- [x] 5.2 Run `/opsx:verify` and address its findings
- [x] 5.3 Run `/opsx:archive` on the branch and commit the archive in the PR (verify: `openspec/specs/post-decorator-class-integrity/spec.md` exists, change moved under `openspec/changes/archive/`)

## 6. Review fixes (each spec fails before its fix)

- [x] 6.1 `PostType.decorator_class_for` answers no class for a name that cannot be loaded and the default decorator for a blank value (verify: model and scan specs for `ENV::X`, a decorator that fails to load and a blank option)
- [x] 6.2 The check refuses a value only when it differs from the stored one (verify: model specs for a stored refused value; the request spec saving such a post type)
- [x] 6.3 The check reads the option from the options as `set_meta` stores them (verify: model specs for parameters, JSON and both key forms)
- [x] 6.4 The refusal quotes the value only when it is a class name, cut short, from an en.yml key (verify: request specs for markup and an overlong name)
- [x] 6.5 A decorator option in `data_options` is checked as a validation (verify: model specs for `update`, `update!` and `create` inside a transaction)
- [x] 6.6 The ignored-value warning is logged once per request and quotes the value with `inspect`, and `Post#decorator_class` logs a failed lookup (verify: model and request specs)
- [x] 6.7 `scan_content` preloads metas and lists a post type whose options cannot be read without ending (verify: scan spec)
- [x] 6.8 A refusal also resets a loaded metas association (verify: model spec keeping earlier writes)
- [x] 6.9 `docs/security/permissions.md`, `docs/upgrading-to-2.9.5.md` and the changelog entry match the behavior (verify: entry under 500 characters)
- [x] 6.10 A refusal that comes while the admin panel serves a GET or HEAD request is raised, not redirected (verify: request spec for an `admin_before_load` hook)
- [x] 6.11 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
