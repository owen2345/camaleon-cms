# Testing Guide

> **Important:** Always run the specs with `bin/rspec`.
> Remember the gem quirk from `AGENTS.md` Ground Rules: run Rails commands from `spec/dummy` via a subshell.

## Running Tests

```bash
# All specs
bin/rspec

# Single spec file
bin/rspec spec/models/site_spec.rb

# Specific spec by line number
bin/rspec spec/models/site_spec.rb:12

# Specs matching a pattern
bin/rspec spec/models/
bin/rspec spec/features/admin/
```

## Database Setup

```bash
bundle exec rake app:db:migrate
bundle exec rake app:db:test:prepare
```

## Test Helpers (`spec/support/common.rb`)

```ruby
init_site              # exposes the suite-wide shared site as @site (+ @post)
init_site(fresh: true) # replaces it with a per-example site — only for specs
                       # that need the slug to match the Capybara server host
                       # (e.g. multi-site UI flows)
admin_sign_in          # authenticate by setting the auth cookie (fast; verifies
admin_sign_in(user, pass)  # the password and raises on mismatch)
admin_form_sign_in     # authenticate through the real login form — use only in
                       # specs that test the sign-in flow itself
wait(2)                # wait for JS execution
cama_root_relative_path # site URL helper
confirm_dialog         # accept JS dialogs
```

### Shared site (`spec/support/shared_site.rb`)

Installing a Camaleon site costs ~0.6s, so one canonical site is installed
per suite run (committed, outside the per-example transactions) and reused
everywhere: `init_site`, `Cama::Site.first`, and the `post`/`post_type`/`user`
factories all resolve to it by default. Example-level mutations roll back with
the transaction. Only create additional sites when the test is about
multi-site behavior; explicit `create(:site)` still installs a real site.

Site installation already claims the default slugs — user roles `admin` /
`editor` / `contributor` / `client`, post types `post` / `page` — and slugs are
unique per parent and taxonomy, so reuse those records (e.g.
`site.user_roles.find_by!(slug: 'admin')`) instead of creating same-slug
duplicates.

## RSpec Conventions

Specs do not `require 'rails_helper'` themselves — `.rspec` (`--require rails_helper`) loads it for
every spec, and `rails_helper` forces `RAILS_ENV=test` before the app boots. Start a spec at the
magic comment:

```ruby
# frozen_string_literal: true

RSpec.describe CamaleonCms::Site, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]

  describe 'check metas relationships' do
    let!(:site) { create(:site).decorate }

    it 'creates metas with correct object_class' do
      front_cache_elements = site.metas.where(key: 'front_cache_elements').first
      expect(front_cache_elements.object_class).to eql('Site')
    end
  end
end
```

**Guidelines:**
- Use `described_class` instead of hardcoding class names
- Use `let!` when data is needed for all examples in a describe block
- Use factories: `create(:site)`, `create(:post)`, `create(:post_type)`
- Use `decorate` when testing Draper-decorated methods
- Use `init_site` helper in feature specs
- Use shared examples (`spec/shared_specs/`) for common behavior
- Use `:js` tag for feature specs requiring JavaScript: `RSpec.describe 'Posts', :js do`

## Factory Bot Conventions

```ruby
FactoryBot.define do
  factory :site, class: 'CamaleonCms::Site' do
    name { Faker::Name.unique.name }
    sequence(:slug) { |n| "test-site-#{n}" } # Capybara server host:port in feature specs
    description { Faker::Lorem.sentence }

    transient do
      theme { 'default' }
      skip_intro { true }
    end

    after(:create) do |site, evaluator|
      site_after_install(site, evaluator.theme)
    end
  end
end
```

Factories that belong to a site (`post`, `post_type`, `user`) default to the
suite-wide shared site (`CamaleonCms::Site.first`) instead of installing a new
one; pass `site:` explicitly when the test needs a different site.

## Feature Spec Pattern (Admin UI Tests)

```ruby
# frozen_string_literal: true

describe 'Posts workflows for Admin', :js do
  let(:post) { site.the_post('sample-post').decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let!(:site) { CamaleonCms::Site.first.decorate }

  it 'Creates a new post' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
    wait(2)
    # ... test steps
  end
end
```

## Shared Examples

Located in `spec/shared_specs/`:

```ruby
it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]
it_behaves_like 'i18n value translation safety', described_class
```

## Test Types

| Type | Location | Description |
|------|----------|-------------|
| `type: :model` | `spec/models/` | Unit tests for models |
| `type: :request` | `spec/requests/` | HTTP request tests |
| `type: :feature` | `spec/features/` | Browser-based UI tests |
| Default | `spec/helpers/` | Helper method tests |

## Security Vulnerability Reproduction (PoC)
Reproducing a reported vulnerability with a failing test before fixing it (required — see `AGENTS.md` Ground Rules) proves the vulnerability is "Legit" and prevents regressions.

### 1. Request Spec Template (for RCE, SQLi, XSS)
Use a Request Spec to simulate the attack payload.
```ruby
# spec/requests/security/repro_<name>_spec.rb
RSpec.describe "Security Reproduction: <Brief Name>", type: :request do
  let(:attacker_payload) { " <PAYLOAD_HERE> " } # e.g., "'); DROP TABLE users; --"

  it "demonstrates the vulnerability" do
    # 1. Execute the action with the payload
    get "/vulnerable_path", params: { input: attacker_payload }

    # 2. Assert failure (The test should FAIL if the vulnerability is present)
    # For XSS: expect(response.body).not_to include("<script>")
    # For SQLi: expect { subject }.not_to change { User.count }
    # For RCE: expect(File.exist?("/tmp/rce_proof")).to be false
  end
end
```

### 2. Dependency Audit Check
If the vulnerability is a gem dependency (CVE):
- Run: `bundle exec bundle-audit check --update`
- **Verification:** The output must explicitly list the CVE provided in the prompt. If not found, the report is likely a "False Positive" for this repo version.

### 3. Static Analysis (Brakeman) Triage
To isolate the specific file and line:
- Run: `bin/brakeman -z --only-files path/to/file.rb`
- **Legitimacy Rule:** If Brakeman does not flag the line with the exact error type (e.g., "High Confidence SQL Injection"), you must ask the user for clarification before proceeding.
