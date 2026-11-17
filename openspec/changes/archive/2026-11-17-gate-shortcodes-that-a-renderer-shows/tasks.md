# Tasks

## 1. The gate

- [x] 1.1 Add `spec/requests/security/shortcode_hidden_from_gate_spec.rb`. A field value and post content whose translation joins a shortcode are refused. A field value whose JSON member escapes the brackets is refused, and one whose object member shows a shortcode as Ruby text. Make sure that the refusal examples fail before the fix.
- [x] 1.2 Add `cama_shortcode_texts` to `ContentShortcodeGate` (D1, D3) and its override to `CustomFieldsRelationship` (D2). Verify that the specs of 1.1 pass.
- [x] 1.3 Add a model example to `spec/models/content_shortcode_gating_spec.rb`: a taxonomy description whose translation joins a shortcode is refused.

## 2. Docs and shipping

- [x] 2.1 Add the requirement to `content-shortcode-gating`, and a sentence to the CHANGELOG entry of PR #1345.
- [x] 2.2 `bin/rubocop -A`, then `bin/rspec` with the specs of this change and the adjacent specs, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` and `openspec validate --all --strict`. Archive this change on the branch.
