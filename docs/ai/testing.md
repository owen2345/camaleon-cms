# Testing Guide

> **Important:** Always set `RAILS_ENV=test` when running specs with `bundle exec rspec` if the `rspec` binstub is not present

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
init_site              # creates @site and @post
admin_sign_in          # authenticate admin user
admin_sign_in(user, pass)
wait(2)                # wait for JS execution
cama_root_relative_path # site URL helper
confirm_dialog         # accept JS dialogs
```

## RSpec Conventions

```ruby
# frozen_string_literal: true

require 'rails_helper'

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
    slug { 'test-site' }
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

## Feature Spec Pattern (Admin UI Tests)

```ruby
# frozen_string_literal: true

require 'rails_helper'

describe 'Posts workflows for Admin', :js do
  let(:post) { site.the_post('sample-post').decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let!(:site) { create(:site).decorate }

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
Before fixing a reported vulnerability, you MUST attempt to reproduce it with a failing test. This proves the vulnerability is "Legit" and prevents regressions.

### 1. Request Spec Template (for RCE, SQLi, XSS)
Use a Request Spec to simulate the attack payload.
```ruby
# spec/requests/security/repro_<name>_spec.rb
require 'rails_helper'

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
