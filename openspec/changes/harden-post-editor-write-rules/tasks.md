## 1. Key names, statuses and the summary (post-editor-write-integrity, post-content-sanitization)

- [ ] 1.1 Add the ASCII-word key rule to the post save's request check (design D1) with a `reserved_key`-style message naming the key, correct the collation comment (accents, compatibility variants, NO PAD), and cover `meta[témplate]`, `meta[＿default]` and an admin's `meta[vísits]` in `post_meta_options_container_spec.rb`; verify the new examples fail before the change and pass after.
- [ ] 1.2 Move the status and engine-key vocabulary to `CamaleonCms::Post` (`STATUSES`, `EDITOR_STATUSES`, `RESTORABLE_STATUSES`, `ENGINE_META_KEYS`, `ENGINE_OPTION_KEYS`) and reference it from the controller; verify the existing write-integrity specs stay green.
- [ ] 1.3 Refuse a submitted `post[status]` outside `EDITOR_STATUSES` in the request check (design D2) and drop a blank status from an update's attributes before the write; add `Published`, `published ` and a payload status to `post_publish_permission_spec.rb`, plus the `status: ''` update cases, and turn the "stores the submitted status verbatim" example of `post_status_output_escaping_spec.rb` into a refusal; verify red before, green after.
- [ ] 1.4 Scan `meta[summary]` in the request check for a user without `post_content_unfiltered_html` (design D3), naming the field; add `spec/requests/security/post_summary_scan_spec.rb` (editor refused and listing renders no script, plain `<b>` accepted, admin stored as written, draft refused); verify red before, green after.

## 2. The refused-save path and the offered lists

- [ ] 2.1 Compute the refusals in `create`/`update` before the `create_post`/`update_post` hooks and re-render a refused update through a private form render without `authorize!` (design D4); add examples with an `update_post` hook that writes an option and with an `edit_publish`-only role to `post_template_layout_choice_spec.rb`; verify red before, green after.
- [ ] 2.2 Move the view-choice field maps, the refusal builder and the message helper into `PostViewChoicesConcern`, and derive option values as Rails does (design D5); add the `[text, value, {attrs}]`, `[value, {attrs}]`, grouped and String-list examples; verify red before (attrs shapes refused, String list raises), green after.
- [ ] 2.3 Run the post type create check with the post type under creation (design D5); add a POST example with a hook reading `args[:post_type]` to `post_type_view_options_spec.rb`; verify it raises before and creates after.

## 3. Options rows and containers (meta-storage-integrity)

- [ ] 3.1 Return an empty indifferent hash from `Metas#options` for a non-Hash row (design D6) and read `restore`'s previous status through `get_option`; add model examples to `spec/models/meta_spec.rb` (or a new `meta_corrupt_options_spec.rb`) and request examples (trash, edit page, public page on a string row) to `post_restore_status_spec.rb`; verify red before, green after.
- [ ] 3.2 Raise `CamaleonCms::Metas::InvalidContainer` from `set_metas`/`set_options` for a present non-hash container and rescue it in `AdminController` (design D7); add `field_options` to the post save's container check; add a model example and request examples for a category save with `meta[]=x` and a site settings save with a JSON `metas` array; verify red before (500 / rows written), green after.

## 4. Helpers, the scan task and the draft buffer

- [ ] 4.1 Keep `scope`, `separator`, `raise` and `throw` in `cama_t`'s English fallback and stop mutating the caller's hash (design D8); add examples to `spec/helpers/camaleon_helper_spec.rb` for the scoped fallback, `raise: true`, a `%{x}`-bearing value and an untouched options hash; verify red before, green after.
- [ ] 4.2 Extend `camaleon_cms:security:scan_content` per design D9 (unlisted template/layout/default_*, non-object options row for posts and post types, summary) and update the task description; add examples to `spec/lib/tasks/unsafe_stored_content_rake_spec.rb`; verify red before, green after.
- [ ] 4.3 Destroy the current user's own parentless buffer named by `post[draft_id]` on create (design D10); add examples (own buffer gone, another user's buffer kept) to `post_draft_save_spec.rb`; verify red before, green after.
- [ ] 4.4 Add a `:js` example to `spec/features/admin/posts_spec.rb` that submits a reserved key through the sidebar's draft save and asserts the editor stays open with the key shown as text; verify it fails with the pre-change JavaScript and passes now.

## 5. Tidy-ups and documentation

- [ ] 5.1 Walk each param group once in the request check with a `reserved_key?` predicate, one `cama_hash_param?` helper on `AdminController` used by the four existing spellings, and no dead branches (design D11); flatten the drafts create lookup; drop the redundant `to_s` calls in the status helpers; memoize the raw lister output so the refused re-render does not glob again; verify the full `spec/requests/security` directory stays green.
- [ ] 5.2 Share the write-integrity specs' prelude in a `spec/support` shared context, use the `:post` and `:user_admin` factories in `post_restore_status_spec.rb`, rename the stale "a blank template" example title, and make the post type "clear with a blank value" example assert the redirect and a prior value; verify the specs stay green.
- [ ] 5.3 Update `docs/security/permissions.md` (key names, status set, summary scan, containers), `docs/ai/ecosystem.md` (ASCII key names, `set_metas`/`set_options` raising, `cama_t` fallback options), `docs/upgrading-to-2.9.5.md` (scan task instead of "no operator action") and the `CHANGELOG.md` entry; correct the archived `restrict-post-template-layout-and-reserved-metas` design.md Non-Goal and D5 and its tasks.md 1.1/1.3; verify the doc anchors resolve.

## 6. Verification and wrap-up

- [ ] 6.1 Run `bin/rubocop -A` on the touched files, then the full `bin/rubocop` with no offenses.
- [ ] 6.2 Run the full `bin/rspec` and confirm it is green.
- [ ] 6.3 Run `bin/brakeman --no-pager` and confirm it reports 0 warnings.
- [ ] 6.4 Run `(cd spec/dummy && bin/rails zeitwerk:check)` and confirm "All is good".
- [ ] 6.5 Run `openspec validate harden-post-editor-write-rules --strict` and confirm it passes.
- [ ] 6.6 Archive the change with `/opsx:archive` on the branch and commit the archived change and the synced specs; verify `openspec list --json` shows no active change. Fold the substance into the PR #1297 description.
