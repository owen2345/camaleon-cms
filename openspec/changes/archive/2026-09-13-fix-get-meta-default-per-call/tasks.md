## 1. Failing specs (`meta-storage-integrity`)

- [x] 1.1 Create `spec/models/meta_default_spec.rb` with examples for "Each read of a meta with no value returns its caller's default":
  - a post with no `gallery` meta, read without a default and then with `[]`: on the post itself, on a freshly loaded post, and on a post loaded with `includes(:metas)`;
  - an empty-array default that the caller appends to in place, followed by another read with `[]`;
  - a stored empty-string row, read without a default and then with a default;
  - three reads of a missing meta on a post loaded without its metas, counted with `sql_queries(matching: /metas/)`.

  Verify with `bin/rspec spec/models/meta_default_spec.rb` that the first three examples fail on the current code. The query-count example passes, because it pins the query profile the fix keeps.
- [x] 1.2 In the same file, add an example for "A meta written as an empty string": `set_meta` with `''`, then `get_meta` with a default on the same instance and on a reloaded post. Verify that the same-instance read fails on the current code.

## 2. get_meta

- [x] 2.1 In `app/models/concerns/camaleon_cms/metas.rb`, change `get_meta` as design.md decides:
  - the memoized block returns the stored lookup, with `''` when there is no row or the stored value is empty;
  - outside `cama_fetch_cache`, return the caller's default when the memoized value is `''`.

  Update the method's comment, and leave `set_meta`, `options` and `CamaleonRecord` unchanged. Verify that the section 1 examples pass, and that `spec/models/meta_spec.rb`, `meta_duplicate_rows_spec.rb`, `meta_pending_create_spec.rb` and `meta_scope_resolution_spec.rb` pass.

## 3. Docs

- [x] 3.1 In `docs/upgrading-to-2.9.5.md`, add a subsection under "Notes for theme & plugin developers" saying that:
  - `get_meta` returns each call's own default;
  - a later read does not see a default changed in place unless it was written with `set_meta`;
  - `set_meta(key, '')` reads as the default on the writing instance.

  Add a matching row to "At a glance", and verify that the row's link resolves to the new subsection's anchor.
- [x] 3.2 In `docs/ai/ecosystem.md`, under "Hardening hazards", add an entry recording the `get_meta` caller review. It covers the consumers that change a returned default in place and pass it to `set_meta`, and `camaleon-ecommerce`'s `LegacyOrder` reads. Verify that the consumers it names match design.md's "Risks / Trade-offs".

## 4. Verification and delivery

- [x] 4.1 Rebase on `master` once `fix/same-instance-option-reads`, #1298, #1299 and #1301 have merged, resolving conflicts in `metas.rb` and in `openspec/specs/meta-storage-integrity/spec.md`. The #1302 requirement, archived as "An options row that is not an object reads as empty", needs no trim: its clause about a no-default read stays true. Verify that `bin/rspec spec/models` passes after the rebase.
- [x] 4.2 Run the CI-parity commands from `AGENTS.md` and verify all four pass: `bin/rspec`, `bin/rubocop -A` on touched files followed by a full `bin/rubocop` with no offenses, `bin/brakeman --no-pager`, and `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 4.3 Commit the specs, fix and docs, push `fix/get-meta-default-per-call`, and open the PR with a What and Why summary and a User-Visible Impact sentence (`docs/ai/workflows.md` Phase 4). Verify that the PR's CI run starts.
- [x] 4.4 Add a `CHANGELOG.md` entry under `## Unreleased` that links the PR and the upgrade-guide anchor. Verify that it is at most 500 characters.
- [x] 4.5 Run `/opsx:verify` and address its findings.
- [x] 4.6 Run `/opsx:archive` on the branch, syncing both requirement changes into `openspec/specs/meta-storage-integrity/spec.md`. Commit the result together with the changelog entry, using the skip-ci directive once the PR has had a full run (`docs/ai/workflows.md` Phase 3). Verify that every box in this file is checked.

## 5. Review follow-ups

- [x] 5.1 Read a meta stored as null as one with no value, for `get_meta` and `get_option`, through one predicate; spec the role-form row that made post type creation raise.
- [x] 5.2 Memoize in `set_meta` what a reload reads (`stored_form_of`, shared with `get_meta` and `PostType`'s decorator-option checks); rewrite the identity examples, add `spec/models/meta_written_form_spec.rb`, and rename and rewrite the `set_meta` requirement.
- [x] 5.3 Keep the metas in memory when `PostType` refuses a decorator-option write, with a spec for an unsaved post type.
- [x] 5.4 Pin the eager-loaded branch and the per-key query profile, prove the blank write stores its row, share one metas-query counter, and create the spec's posts for the installed post type.
- [x] 5.5 Qualify the requery clause of the new requirement, describe the `LegacyOrder` reads and the by-reference memo in the docs, and bring this archive up to the merged base.
- [x] 5.6 Return a meta or option stored as a number, a boolean or a hash from `the_meta` and `the_option` as read, with a decorator spec.
- [x] 5.7 Memoize a plain String copy of text that holds no JSON, so `set_meta` hands back neither the caller's String nor an html_safe one; spec both in `spec/models/meta_written_form_spec.rb` and add the scenario to the `set_meta` requirement.
- [x] 5.8 Describe `the_meta` and `the_option` reading every item of an Array as a String through the locale, in the decorator's comment, the upgrade guide, this change and the requirement, and spec an Array holding a number and a boolean.
- [x] 5.9 Remove the `options` branches that converted a String or a plain Hash `get_meta` returned, which only a row holding a JSON string could still reach, and spec such a row reading as empty options.
- [x] 5.10 Memoize nil, not the concern's frozen `''`, for a key with no row, and spec what a missing meta's read memoizes.
- [x] 5.11 Look a key up by its String form in `get_meta`, as `set_meta` stores it, and spec an Integer key read from eager-loaded metas and from the database.
- [x] 5.12 Return the boolean `stored_meta_value` looks up for a legacy `'t'`/`'f'` row instead of deriving it again through `stored_form_of`.
- [x] 5.13 Copy text that cannot open a JSON text without calling `JSON.parse` in `stored_form_of`, and spec such text read back unparsed, with the edge texts of the written-form table reading as before.
- [x] 5.14 Return the value passed from `set_meta`, as 2.9.4 did, instead of the form it memoizes, so the option writers return the options they wrote; correct its comment and spec both return values.
- [x] 5.15 Keep the Hash or the Array an instance handed out memoized when it is written back, taking the stored form in place, so a hash `options` returned keeps reading later option writes; spec a held options hash, a hash written back twice and a written-back list.
- [x] 5.16 Put back the options an option writer changed when its `set_meta` raises, refused or failed, instead of `PostType` dropping the memo, and spec a refused write read without a query and a failed write of each writer.
- [x] 5.17 Read the decorator option out of a stored form of the options through one `PostType` helper, shared by the write check and the stored-value lookup.
- [x] 5.18 Look the stored decorator option up through `stored_meta_row`, the row a write updates, and spec a refused write on a post type with loaded metas issuing no metas query.
- [x] 5.19 Hand `PostType`'s decorator-option check the form `set_meta` is about to store through a private hook, instead of an override computing it a second time, and spec an options write parsing the options once.
- [x] 5.20 Spec `the_meta` and `the_option` returning a meta and an option stored as a hash as read, on the writing post and a freshly loaded one, and add the scenario to the decorator requirement.
- [x] 5.21 Fold the hash read-back example of `spec/models/meta_spec.rb` into the written-form one, which already covered the rest of it, keeping its indifferent-hash check and the key added to the caller's hash afterwards.
- [x] 5.22 Record `camaleon-ecommerce`'s order-shipped email, whose tracking URL an all-digit consignment number read back as an Integer leaves empty, in the ecosystem survey, the design, the proposal and the upgrade guide, correcting the survey's claim that no consumer changes.
- [x] 5.23 Count in `metas_selects` a SELECT behind leading whitespace or a query log comment, and no table whose name only starts with metas, with a spec of the helper.
- [x] 5.24 Match a metas SELECT with two patterns, its opening and its table, through a pattern list `sql_queries` now takes, instead of one pattern bridging them with `.*` that ran back over the whole statement; spec the list and long statements.
- [x] 5.25 Name the key's String form once in `set_meta`, as `get_meta` does, for the pending-row, stored-row and built-row lookups, the check, the writes and the memo.
- [x] 5.26 Make `LEGACY_BOOLEANS` a private constant of the metas concern, as `JSON_TEXT_OPENING` is; nothing outside the concern reads it.
- [x] 5.27 Look a key's row up through one helper, `meta_row`, for `get_meta`'s read and, with `stored_only`, for the stored row a write updates and `PostType`'s stored decorator option, instead of two copies of the lookup.
- [x] 5.28 Take the text of a value outside the rescue in `stored_form_of`, so a value whose text cannot be taken raises its own error before the write is checked instead of reading as no value; spec it in `spec/models/meta_written_form_spec.rb`.
- [x] 5.29 Keep reading a legacy `'t'`/`'f'` row as the boolean when storing it again raises anything, not only a database error, as the method-level rescue the extraction of `stored_form_of` removed did; spec a repair that raises `FrozenError`.
- [x] 5.30 Store a String `'t'` or `'f'` as its JSON string in `fix_meta_value`, so it reads back as the String on the writing instance and after a reload instead of as the boolean a legacy row holding the bare letter reads as; add both to the written-form table, spec the stored text beside a legacy row, and describe it in the upgrade guide, the design and the `set_meta` requirement.
- [x] 5.31 Describe a value of another class, a `BigDecimal`, a `Time` or a `Date`, reading back on the writing instance as a reload reads the text it is stored as, in the upgrade guide, the design and the `set_meta` requirement, and add the three to the written-form table.
