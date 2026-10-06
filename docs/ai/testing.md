# Testing Guide

Run specs with `bin/rspec` (it forces `RAILS_ENV=test` and boots `spec/dummy`); `bin/rspec spec/path_spec.rb:12` runs one example. Rails commands go through `spec/dummy` in a subshell (`AGENTS.md` Ground rules).

## Which specs to run

`AGENTS.md` "Verify before pushing" says which specs to run before a push and when to run the whole suite; `grep -rln <changed symbol> spec/` finds the adjacent ones. Never have two runs going at once: the suite shares one SQLite database, and runs on separate ones still share the dummy app's files, such as the uploads under `spec/dummy/public/media`.

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
the UPDATEs of it (`spec/support/sql_queries.rb`); count them to pin a query profile. `sql_queries` skips the
BEGIN, SAVEPOINT and COMMIT statements unless you pass `include_transactions: true`.

`rolled_back_transaction { … }` runs a block in a savepoint of its own and rolls it back, for specs of what a
rollback leaves on the records the block wrote.

### The shared site (`spec/support/shared_site.rb`)

Installing a site costs ~0.6s, so one canonical site is installed per suite run, committed outside the per-example transactions, and reused everywhere: `init_site`, `Cama::Site.first` and the `post`/`post_type`/`user` factories resolve to it, and example-level mutations roll back. Create another site only when the test is about multi-site behavior (`create(:site)` installs a real one). Installation already claims the default slugs — roles `admin`/`editor`/`contributor`/`client`, post types `post`/`page` — and slugs are unique per parent and taxonomy, so reuse those records (`site.user_roles.find_by!(slug: 'admin')`) instead of creating same-slug duplicates.

## Conventions

- A spec starts at the `# frozen_string_literal: true` magic comment: `.rspec` requires `rails_helper` for every file, so no spec requires it itself. Spec type is inferred from the directory (`spec/models`, `spec/requests`, `spec/features`, `spec/helpers`).
- `spec_helper` disables the RSpec monkey patches (`config.disable_monkey_patching!`). A top-level group must start with `RSpec.describe`, `RSpec.shared_examples` or `RSpec.shared_context`: a file with a bare `describe` does not load. The `should` and `stub` syntaxes do not exist.
- Factories live in `spec/factories/`; `rails_helper` points FactoryBot at them explicitly because `Rails.root` is `spec/dummy` and the default lookup finds nothing. The engine does not inject them into host apps — a host or plugin harness that wants them sets `FactoryBot.definition_file_paths` itself, as the cama_contact_form harness does. Site-owned factories default to the shared site; pass `site:` for another. `spec/factories/site.rb` shows the install-on-create pattern.
- Shared examples live in `spec/shared_specs/`: `it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]` and `it_behaves_like 'i18n value translation safety', described_class`.
- Feature specs are tagged `:js`, call `init_site` and `admin_sign_in`, then `visit "#{cama_root_relative_path}/admin/…"`; `spec/features/admin/categories_spec.rb` is a compact example. Request specs (`spec/requests/`) are preferred over controller specs.

### JavaScript in feature specs

- Clear `spec/dummy/tmp/cache` and `spec/dummy/public/assets` before a red check of a change to the admin JavaScript: otherwise the browser may get the bundle compiled before the change, and the example passes on it.
- Hold what an example waits on instead of sleeping: `spec/features/admin/post_draft_autosave_spec.rb` wraps `$.ajax` so a draft request stays pending until the example releases it (`hold_draft_requests` / `release_draft_requests`), and loads an admin page in place as `camaleon_admin_ajax` does (`load_in_place`).
- To check that no alert opened, look for `body.modal-open`: Bootstrap adds the modal to the page only once its backdrop has faded in, so `have_no_css('#cama_alert_modal')` right after the answer that would open one passes either way.
- An error thrown, uncaught, in a later task by a function the example defined with `execute_script` reaches `window` error listeners as "Script error."; to read its message, add the code as an inline `<script>` of the page.
- In a window the page sends to a URL after opening it, wait with `have_current_path` before any DOM query: Chrome raises on a query that spans the navigation away from `about:blank`, and Capybara does not retry it. `window_opened_by` needs the window to stay open; for one that opens and closes inside the block, check `page.windows.size` instead.

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
