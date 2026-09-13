## 1. Reproduce first (red on master)

- [x] 1.1 Add `spec/requests/security/post_template_layout_choice_spec.rb`, driving the real posts and drafts endpoints. Cover the refusals (an editor's `meta[template]` naming an admin view and `meta[layout]` of `camaleon_cms/admin`, a contributor's unoffered `options[default_template]` with the post type's templates switched off, and a non-admin's draft save with an unoffered template) and the acceptances (an offered template, a blank layout, a hook-added template, an admin's unlisted template). Verify on master that every refusal example fails and every acceptance example passes.
- [x] 1.2 Add `spec/requests/security/post_engine_maintained_keys_spec.rb`. Cover the refusals (an admin's `meta[_default]` string, with the public page still rendering; a contributor's `options[status_default]`; `meta[visits]`, `meta[comments_count]` and `options[draft_status]`) and the acceptances (`options[seo_title]`, `options[hide_in_sitemap]` and `meta[product_specifications]` are stored; trashing stamps `status_default` and a visit bumps the counter). Verify on master that the refusal examples fail.
- [x] 1.3 Add `spec/requests/security/post_restore_status_spec.rb`. Cover: the contributor publish bypass (`options[status_default]=published` then `restore`); a publisher restoring a trashed published post (`published`); a restore on a `pending` post (unchanged, error reported); a missing or non-canonical stored status restoring as `pending`. Verify on master that the bypass, non-trashed and non-canonical examples fail.

## 2. Implement

- [x] 2.1 Add i18n messages under `camaleon_cms.admin.post.message` in `config/locales/camaleon_cms/admin/en.yml`: an unoffered template or layout (naming the field), a reserved meta or option key (naming the key), and restoring a post that is not in the trash. Resolve them with an English fallback, as `cama_content_rejection_message` does. Verify the new specs match the rendered messages.
- [x] 2.2 Add the private request check to `PostsController` (design D2–D4): offered lists computed once per request from `cama_get_list_template_files`/`cama_get_list_layouts_files`, the admin skip for the template and layout rule only, and reserved meta/option keys for everyone. Run it at the top of `save_post_with_fields`, adding each refusal to `post.errors` and returning false before the transaction. Verify the posts examples in 1.1 and 1.2 pass and the refused form re-renders with the errors.
- [x] 2.3 Run the same check in `DraftsController#create` and `#update` before `save(validate: false)`, answering `{ error: [...] }` without saving. Verify the draft example in 1.1 passes and `spec/requests` draft specs stay green.
- [x] 2.4 Change `PostsController#restore` per design D5: trash only, canonical statuses only, `published` only for a user who can `publish_post`. Verify 1.3 passes and `spec/requests/security/admin_destructive_get_verbs_spec.rb` stays green.
- [x] 2.5 Rework the `options[:status_default] -> trash -> update -> restore` example in `spec/requests/security/post_status_output_escaping_spec.rb` per design D6, planting the status payload with `update_column` and keeping the admin-listing escaping assertion. Verify the spec passes.

## 3. Documentation

- [x] 3.1 In `docs/security/permissions.md`, add the post editor's write rule to "The pieces that implement the rule": offered templates and layouts for non-admins, engine-maintained keys refused for everyone, and restore re-checking the publish right. Verify the section reads consistently with `security-capability-gating`.
- [x] 3.2 Add a hardening entry to `docs/ai/ecosystem.md` saying a plugin that submits a post template or layout must register it through `post_get_list_templates`/`post_get_list_layouts`, that engine-maintained keys can no longer be submitted, and that no surveyed consumer is affected. Verify every consumer named in the proposal is listed.
- [x] 3.3 Add a section to `docs/upgrading-to-2.9.5.md` with an at-a-glance row, the restore behavior change (non-publishers' posts return as `pending`), and a theme and plugin developer note about registering templates through the hooks. Verify the anchor resolves from the table.
- [x] 3.4 After the PR exists, add a `CHANGELOG.md` entry under `## Unreleased` (at most 500 characters) linking the PR and the upgrade-guide anchor, following `docs/ai/workflows.md` Phase 3 for the skip-ci decision. Verify the entry length.

## 4. Verification and wrap-up

- [x] 4.1 Run `bin/rubocop -A` on the touched files, then the full `bin/rubocop` with no offenses.
- [x] 4.2 Run the full `bin/rspec` and confirm it is green.
- [x] 4.3 Run `bin/brakeman --no-pager` and confirm it reports 0 warnings.
- [x] 4.4 Run `(cd spec/dummy && bin/rails zeitwerk:check)` and confirm "All is good".
- [x] 4.5 Run `openspec validate restrict-post-template-layout-and-reserved-metas --strict` and confirm it passes.
- [x] 4.6 Mark NEW-2 `✅ FIXED (#<PR>)` in the local `SECURITY-AUDIT-2026-08-11.md` after the PR exists. Verify the marker placement matches the NEW-1 heading convention.
- [ ] 4.7 Before merge, archive the change with `/opsx:archive` on the branch and commit the archived change and the synced `openspec/specs/post-editor-write-integrity/spec.md`. Verify `openspec list --json` shows no active change.
