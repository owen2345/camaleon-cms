# Design: fix-1173-fallout-batch

## Context

PR #1173 converted `TermTaxonomy` (discriminator `taxonomy`) and `PostDefault` (discriminator
`post_class`) to native Rails STI, added user-content lifecycle options, and sprinkled
`inverse_of` across associations — with no changelog entry. The `2.9.2..master` audit confirmed
three fallout clusters (H8, H9, wrong `inverse_of`s), all verified by live execution. Batch 1
(#1223) covered the small restorations; this change covers the #1173 cluster. There are no
migrations in the range, so every fix must work against unchanged 2.9.2 schemas and row values.

## Goals / Non-Goals

**Goals:**

- Existing databases with custom discriminator values load and save again.
- User deletion behaves as on 2.9.2 (comments → anonymous user, widgets survive), with the
  master-era orphan damage repairable.
- Association traversals stop raising/mislabeling.

**Non-Goals:**

- H7 (post-content sanitization scope), H10–H12 (theme activation, uploads) — separate batches.
- Defining user-side `has_many` collections (`term_taxonomies`, `post_tags`, …) to make the
  guessed inverses real — that would add public API speculatively.
- Rewriting `post_class`/`taxonomy` values or adding migrations.

## Decisions

- **D1 — `base_class` fallback instead of raising (H8):** unknown discriminators instantiate the
  STI root (`TermTaxonomy` / `PostDefault`), which is exactly what 2.9.2 instantiated for every
  row. Alternatives rejected: raising (breaks existing data), `becomes`-style dynamic subclass
  creation (magic, no consumer). `base_class` is verified to resolve to the intended roots
  (`CamaleonRecord` is abstract).
- **D2 — Non-descendant resolutions are treated as unknown (H8):** `find_sti_class` on
  `TermTaxonomy` constantized any `CamaleonCms::<Camelized>` name without checking ancestry, so a
  taxonomy value of `meta` would instantiate `CamaleonCms::Meta` against the `term_taxonomy`
  table. The fallback now requires `klass <= base_class`. `PostDefault` keeps its `super` call
  before the fallback because AR's own resolution handles fully-qualified external plugin
  classes and already enforces ancestry.
- **D3 — Restore comment reassignment by removing `dependent: :nullify` (H9):** the
  `after_destroy :reassign_comments` callback is correct; the nullify callback (registered later,
  running earlier as a `before_destroy`) emptied its working set. Alternatives rejected: moving
  reassignment to `before_destroy` (changes its transactional position for no gain), reassigning
  inside the nullify handler (couples two mechanisms). `all_posts` keeps `dependent: :nullify` —
  `reassign_posts` runs first (declared earlier), so nullify only touches the
  no-surviving-admin remainder that 2.9.2 left dangling.
- **D4 — Widgets keep their rows; the association stays (H9):** `dependent: :destroy` is removed
  from the built-in user's `has_many :widgets`; the association itself remains as additive API.
  `Widget::Main#owner` drops its `inverse_of: :widgets` (→ `inverse_of: false`) because custom
  `user_model` classes get only `UserMethods`, which defines no `widgets` collection — the
  inverse was valid solely for the built-in model.
- **D5 — `inverse_of: false` over inventing user-side associations:** the `owner` inverses named
  associations that have never existed (`term_taxonomies`, `post_type_owners`, `post_tags` on the
  user). Declaring `inverse_of: false` restores 2.9.2 runtime semantics and satisfies
  `Rails/InverseOf` explicitly. `Site#nav_menu_items` also gets `inverse_of: false`: it joins by
  `term_group` (site id) while `NavMenuItem#parent` reads `parent_id` (menu id) — no correct
  inverse exists. `Post#drafts` instead gets the genuinely correct `inverse_of: :parent`
  (same foreign key, right association).
- **D6 — Orphan repair is a rake task, not a migration:** per house convention
  (`cross_site_field_groups.rake`, `site_custom_field_groups.rake`), data repair ships as
  `camaleon_cms:reassign_orphaned_comments`, resolving each orphaned comment's site through
  `post → post_type → site` and assigning `Site#get_anonymous_user`. Decorator readers
  additionally become nil-safe so unrepaired rows render blank instead of 500ing.

## Risks / Trade-offs

- [Base-class instances for plugin subclasses not yet loaded in lazy-loading dev mode] → the
  `descendants` scan can miss an unloaded subclass and fall back to the root; degraded typing in
  dev is strictly better than raising, and production eager-loads.
- [Keeping `all_posts` nullify diverges from 2.9.2's dangling ids in the no-admin case] →
  deliberate: `NULL` is the safer representation and `Post#author` display already rescues.
- [`inverse_of: false` forgoes future automatic inverse benefits] → matches 2.9.2; a later change
  can introduce real user-side collections deliberately.

## Migration Plan

No schema changes. Operators upgrading from a master-era deployment run
`rake camaleon_cms:reassign_orphaned_comments` once to repair comments orphaned by the
regression; installs coming from 2.9.2 need nothing.

## Open Questions

None.
