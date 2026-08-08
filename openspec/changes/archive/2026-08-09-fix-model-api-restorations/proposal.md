## Why

The 2026-08 regression audit batched five model-API findings as PR 4. The 2026-08-05 ecosystem
sweep (all 22 public plugin/theme/host repos) found **zero consumers** for every surface here, so
these restorations are cheap insurance on core's own merits rather than live-break fixes — while
two changelog claims need correcting because they misstate what shipped:

- **M5** — `Media.find_by_key` was renamed `by_key` (#1168's `Rails/DynamicFindBy` sweep). An
  external caller now hits Rails' dynamic finder against a `key` column that does not exist — a
  loud `NoMethodError` where a working relation used to return.
- **M6** — `unassign_category` (a working public API at 2.9.2) was removed together with the
  genuinely broken `assign_tags`/`unassign_tags` pair; `assign_category` survived.
- **M10** — NavMenu/NavMenuItem lost their `order(id: :asc)` default scopes: external iteration
  order is now DB-arbitrary. (The Site half of the audited finding is vacuous — `term_group` is
  never written for sites — so Site keeps no scope; its commented-out remnant is deleted.)
- **M4** — the `ActiveRecordExtras` module (`update_or_create`, `update_or_create!`,
  `assign_or_new`) was removed. Zero consumers exist; master has never shipped it in a release.
  Disposition: **document as removed** with a migration note — no code restore.
- **M11** — the #1222 changelog says slug uniqueness applies "under the same parent and
  taxonomy", but `PostUniqValidator` queries `ptype.site.posts` — **site-wide across post
  types**. A slug held by a Page blocks a Product of the same site. The claim is corrected and
  the missing cross-post-type spec added; the behavior itself is unchanged.

## What Changes

- `Media.find_by_key` returns as an alias of `by_key` (same relation contract).
- `CategoriesTagsForPosts#unassign_category` is restored on the current `update_counts`
  counter API.
- `NavMenu` and `NavMenuItem` regain `default_scope { order(id: :asc) }`; all five render paths
  keep winning via `reorder(:term_order)` (#1194). Site's commented-out scope remnant is deleted.
- CHANGELOG documents the `ActiveRecordExtras` removal with a migration note (M4) and corrects
  the #1222 scope claim (M11).
- New spec coverage: alias contract, unassign flow with counter updates, default-order SQL shape,
  and the cross-post-type slug collision.

## Capabilities

### New Capabilities

- `model-api-compatibility`: the restored legacy model surfaces — `Media.find_by_key` alias,
  `unassign_category` with counter maintenance, and default navigation enumeration order (with
  the render-path `term_order` precedence).
- `post-slug-uniqueness`: the actual slug-uniqueness contract — site-wide across post types,
  drafts excluded — so the scope can never again be documented from assumption.

### Modified Capabilities

None.

## Impact

- `app/models/camaleon_cms/media.rb`, `app/models/concerns/camaleon_cms/categories_tags_for_posts.rb`,
  `app/models/camaleon_cms/nav_menu.rb`, `app/models/camaleon_cms/nav_menu_item.rb`,
  `app/models/camaleon_cms/site.rb` (comment deletion only), `CHANGELOG.md`.
- Specs: new `spec/models/model_api_compatibility_spec.rb`; extension to
  `spec/validators/post_uniq_validator_spec.rb`.
- No routes, controllers, views, or data changes. Behavior deltas: two restored methods,
  deterministic default nav ordering (render output unchanged), corrected documentation.
