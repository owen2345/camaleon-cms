## 1. M5 — Media.find_by_key alias (commit 1)

- [x] 1.1 Spec in new `spec/models/model_api_compatibility_spec.rb`: `find_by_key` returns the
      same records as `by_key` through a site's media scope (red: `NoMethodError` on the unfixed
      model); call sites carry the `Rails/DynamicFindBy` pin.
- [x] 1.2 Singleton alias in `media.rb` under `by_key`.
- [x] 1.3 Spec green; rubocop clean on touched files; commit M5.

## 2. M6 — unassign_category (commit 2)

- [x] 2.1 Spec: post assigned to two categories, `unassign_category` with a single id leaves the
      other assignment and refreshes the removed category's counter (red: `NoMethodError`).
- [x] 2.2 Restore the 2.9.2 body on `update_counts('categories')` in
      `categories_tags_for_posts.rb`, mirroring `assign_category`'s style.
- [x] 2.3 Spec green; rubocop clean; commit M6.

## 3. M10 — nav default ordering (commit 3)

- [x] 3.1 Spec: `NavMenu.all` / `NavMenuItem.all` SQL carries the ascending-id ORDER BY (red on
      master: no order); existing menu render specs stay green (`reorder(:term_order)` wins).
- [x] 3.2 `default_scope { order(id: :asc) }` on both models; delete Site's commented-out scope
      remnant.
- [x] 3.3 Specs green; rubocop clean; commit M10.

## 4. M4 — document ActiveRecordExtras as removed (commit 4, docs-only, [skip ci])

- [x] 4.1 CHANGELOG Unreleased: removal note for `update_or_create`/`update_or_create!`/
      `assign_or_new` with the `find_or_initialize_by` migration recipe.

## 5. M11 — slug-uniqueness scope truth (commit 5)

- [x] 5.1 Extend `spec/validators/post_uniq_validator_spec.rb` with the cross-post-type
      collision example (pins existing behavior — red-first N/A, documentation defect).
- [x] 5.2 Amend the #1222 changelog entry: "same taxonomy and parent" → site-wide across post
      types.

## 6. Verification and CI parity

- [x] 6.1 Full `bin/rspec` suite green.
- [x] 6.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 7. OpenSpec + PR protocol

- [x] 7.1 `openspec validate fix-model-api-restorations --strict` passes; archive on-branch
      (syncs `model-api-compatibility` + `post-slug-uniqueness`); commit the archived change
      (no `[skip ci]` — it heads the first push).
- [x] 7.2 Push, open the PR (What and Why + User-Visible Impact; protocol constraints), first
      push runs CI.
- [x] 7.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
