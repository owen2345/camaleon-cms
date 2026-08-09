## 1. M9 + M8 — revert the scope naming, align the widget literals (commit 1)

- [x] 1.1 `spec/models/meta_scope_resolution_spec.rb`: demodulize contract — `Post`, `Main`
      (Widget::Main), `User` (stubbed `Admin::User`-style host class), plain host class
      (host-model and widget directions proven red against the prefixed concern earlier in the
      session).
- [x] 1.2 `spec/requests/admin/widget_field_values_spec.rb`: assigned-widget field value
      round-trips through the group placed on the widget (era-portable joint pin — red on any
      one-sided rename).
- [x] 1.3 `common_relationships.rb` → `name.demodulize`; assign controller allowed-slugs lookup
      and `get_caption` widget case → `'Main'`; the two security-spec fixtures follow.
- [x] 1.4 No repair task, no compatibility read (maintainer decision: unreleased churn,
      prefixed rows abandoned). Specs green; rubocop clean; commit.

## 2. M7 — rollback-hazard note (commit 2, docs-only, [skip ci])

- [x] 2.1 CHANGELOG upgrader note: `Widget::Assigned` rows written on master are invisible to
      2.9.2 after a rollback (`post_class` STI discriminator — separate mechanism, not
      reverted).

## 3. N4 — definition lifecycle (commit 3)

- [x] 3.1 `spec/models/custom_field_definition_lifecycle_spec.rb`: hook teardown pins (post,
      post type — complete, callback-driven) and the hook-less leave-definitions repro
      (PostComment; proven red against the delete_all concern).
- [x] 3.2 `common_relationships.rb`: drop `dependent: :delete_all` from `custom_fields` and
      `custom_field_groups`, cop-pinned with the ownership rationale.
- [x] 3.3 Specs green; rubocop clean; commit.

## 4. Verification and CI parity

- [x] 4.1 Full `bin/rspec` suite green.
- [x] 4.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 5. OpenSpec + PR protocol

- [x] 5.1 `openspec validate fix-scope-drift-and-cascade --strict` passes; archive on-branch
      (syncs `meta-scope-resolution` and `custom-field-definition-lifecycle`); commit the
      archived change (no `[skip ci]` — it heads the first push).
- [x] 5.2 Push, open the PR (What and Why + User-Visible Impact; protocol constraints), first
      push runs CI.
- [x] 5.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
