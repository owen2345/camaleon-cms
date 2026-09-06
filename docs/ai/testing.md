# Testing Guide

Run specs with `bin/rspec` (it forces `RAILS_ENV=test` and boots `spec/dummy`); `bin/rspec spec/path_spec.rb:12` runs one example. Rails commands go through `spec/dummy` in a subshell (`AGENTS.md` Ground rules).

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

### The shared site (`spec/support/shared_site.rb`)

Installing a site costs ~0.6s, so one canonical site is installed per suite run, committed outside the per-example transactions, and reused everywhere: `init_site`, `Cama::Site.first` and the `post`/`post_type`/`user` factories resolve to it, and example-level mutations roll back. Create another site only when the test is about multi-site behavior (`create(:site)` installs a real one). Installation already claims the default slugs — roles `admin`/`editor`/`contributor`/`client`, post types `post`/`page` — and slugs are unique per parent and taxonomy, so reuse those records (`site.user_roles.find_by!(slug: 'admin')`) instead of creating same-slug duplicates.

## Conventions

- A spec starts at the `# frozen_string_literal: true` magic comment: `.rspec` requires `rails_helper` for every file, so no spec requires it itself. Spec type is inferred from the directory (`spec/models`, `spec/requests`, `spec/features`, `spec/helpers`).
- Factories live in `spec/factories/`; `rails_helper` points FactoryBot at them explicitly because `Rails.root` is `spec/dummy` and the default lookup finds nothing. The engine does not inject them into host apps — a host or plugin harness that wants them sets `FactoryBot.definition_file_paths` itself, as the cama_contact_form harness does. Site-owned factories default to the shared site; pass `site:` for another. `spec/factories/site.rb` shows the install-on-create pattern.
- Shared examples live in `spec/shared_specs/`: `it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]` and `it_behaves_like 'i18n value translation safety', described_class`.
- Feature specs are tagged `:js`, call `init_site` and `admin_sign_in`, then `visit "#{cama_root_relative_path}/admin/…"`; `spec/features/admin/categories_spec.rb` is a compact example. Request specs (`spec/requests/`) are preferred over controller specs.

## Security Vulnerability Reproduction

A vulnerability fix starts with a failing spec that reproduces it (`AGENTS.md` Ground rules); whether the report is legit is decided first by the triage protocol in `docs/ai/workflows.md` Phase 2A. Reproductions live in `spec/requests/security/`, driven through the real endpoint so the request context the permission decision reads is the real one. `repro_markup_and_script_upload_scanning_spec.rb` is the model: state the gap in the header comment, exercise it as the attacker would, and assert the safe outcome so the spec fails while the vulnerability is present.
