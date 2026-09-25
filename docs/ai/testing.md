# Testing Guide

Run specs with `bin/rspec` (it forces `RAILS_ENV=test` and boots `spec/dummy`); `bin/rspec spec/path_spec.rb:12` runs one example. Rails commands go through `spec/dummy` in a subshell (`AGENTS.md` Ground rules).

## Which specs to run

Run the specs the change adds or edits and the adjacent ones: the spec files of the model, concern, controller or helper the change touches, and whatever `grep -rln <changed symbol> spec/` finds. That is the pre-push check; CI runs the whole suite on every push. Run the whole suite locally only when the user asks for it or after a refactoring with a wide blast radius (a base class, a concern every model includes, a shared helper), and never two runs at once: the suite shares one SQLite database.

## Database

`rails_helper` keeps the SQLite test schema current from `spec/dummy/db/schema.rb` (`maintain_test_schema!`); `bundle exec rake app:db:test:prepare` rebuilds it by hand.

## Helpers (`spec/support/common.rb`)

```ruby
init_site              # exposes the suite-wide shared site as @site (+ @post)
init_site(fresh: true) # a per-example site, only when the slug must match the
                       # Capybara server host (multi-site UI flows)
admin_sign_in          # sets the auth cookie directly (fast; verifies the password)
admin_form_sign_in     # the real login form; only for specs of the sign-in flow
wait(2)                # wait for JS
cama_root_relative_path
confirm_dialog         # accept JS dialogs
```

`sql_queries(matching:) { … }` collects the SQL a block issues, only the statements matching a pattern, or every
pattern of a list, when given, `metas_selects { … }` the SELECTs against the metas table and `metas_updates { … }`
the UPDATEs of it (`spec/support/sql_queries.rb`); count them to pin a query profile.

`rolled_back_transaction { … }` runs a block in a savepoint of its own and rolls it back, for specs of what a
rollback leaves on the records the block wrote.

### The shared site (`spec/support/shared_site.rb`)

Installing a site costs ~0.6s, so one canonical site is installed per suite run, committed outside the per-example transactions, and reused everywhere: `init_site`, `Cama::Site.first` and the `post`/`post_type`/`user` factories resolve to it, and example-level mutations roll back. Create another site only when the test is about multi-site behavior (`create(:site)` installs a real one). Installation already claims the default slugs — roles `admin`/`editor`/`contributor`/`client`, post types `post`/`page` — and slugs are unique per parent and taxonomy, so reuse those records (`site.user_roles.find_by!(slug: 'admin')`) instead of creating same-slug duplicates.

## Conventions

- A spec starts at the `# frozen_string_literal: true` magic comment: `.rspec` requires `rails_helper` for every file, so no spec requires it itself. Spec type is inferred from the directory (`spec/models`, `spec/requests`, `spec/features`, `spec/helpers`).
- Factories live in `spec/factories/`; `rails_helper` points FactoryBot at them explicitly because `Rails.root` is `spec/dummy` and the default lookup finds nothing. The engine does not inject them into host apps — a host or plugin harness that wants them sets `FactoryBot.definition_file_paths` itself, as the cama_contact_form harness does. Site-owned factories default to the shared site; pass `site:` for another. `spec/factories/site.rb` shows the install-on-create pattern.
- Shared examples live in `spec/shared_specs/`: `it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]` and `it_behaves_like 'i18n value translation safety', described_class`.
- Feature specs are tagged `:js`, call `init_site` and `admin_sign_in`, then `visit "#{cama_root_relative_path}/admin/…"`; `spec/features/admin/categories_spec.rb` is a compact example. Request specs (`spec/requests/`) are preferred over controller specs.

## Ecosystem member checks

CI also runs five ecosystem members' suites against the commit under test (`<member> / RSpec` checks; what they are and what a red one means: `docs/ai/ecosystem.md`, "Continuous cross-testing"). To reproduce one locally, run the member's suite from a sibling checkout with `CAMALEON_CMS_PATH` pointing at this working tree. For a plugin:

```bash
cd ../cama_contact_form
export RAILS_ENV=test CAMALEON_CMS_PATH=../camaleon-cms
bundle lock && bundle install   # re-resolves camaleon_cms and what it newly requires, nothing else
(cd spec/dummy && bundle exec rails db:test:prepare && bundle exec rails db:migrate)
bin/rspec
unset CAMALEON_CMS_PATH && git checkout Gemfile.lock spec/dummy/db/schema.rb && bundle install
```

The last line matters: the member's committed lock belongs to the released gem. `camaleon_editor` has `:js` specs, so clear `spec/dummy/tmp/cache` and `spec/dummy/public/assets` first. `florsan` is a host app on Postgres that copies the engines' migrations: run `bin/rails railties:install:migrations`, `bin/rails db:test:prepare` and `bin/rails db:migrate` from its root instead, and restore `db/schema.rb` (and delete any migration the first command copied) afterwards.

## Security Vulnerability Reproduction

A vulnerability fix starts with a failing spec that reproduces it (`AGENTS.md` Ground rules); whether the report is legit is decided first by the triage protocol in `docs/ai/workflows.md` Phase 2A. Reproductions live in `spec/requests/security/`, driven through the real endpoint so the request context the permission decision reads is the real one. `repro_markup_and_script_upload_scanning_spec.rb` is the model: state the gap in the header comment, exercise it as the attacker would, and assert the safe outcome so the spec fails while the vulnerability is present.
