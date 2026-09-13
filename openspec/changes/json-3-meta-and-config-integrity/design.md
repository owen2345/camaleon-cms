## Context

See proposal.md, "Why". The approach is shaped by these constraints:

- **json 3** raises on comments, repeated keys (when parsing and when generating) and unknown options.
- **json 2** accepts comments and repeated keys. From 2.20 and 2.13 respectively it warns about them,
  but only under `-W:deprecated`. Before 3.0 it ignores unknown options, so `allow_comments: true` and
  `allow_duplicate_key: true` are safe on every 2.x release.
- **Rails:** every released line from 6.1 to 8.1.3.1 fails under json 3 inside ActiveSupport's JSON
  encoding or decoding.
- **Meta storage:**
  - Metas sit behind a per-record in-memory cache.
  - A read parses stored JSON into an indifferent hash.
  - The option writers read the options hash, change it, and write it back through `set_meta`.
  - Two private serializers exist: `Metas#fix_meta_value` and `CustomFieldsRead#fix_meta_value`. The
    second shadows the first on posts, taxonomies and users.
- **Public API:** `set_meta`, `get_meta`, `set_option` and `options` are called directly by plugins and
  themes (`docs/ai/ecosystem.md`).
- **Schema:** unchanged since 2018. Data backfills are Rake tasks, never migrations
  (`docs/ai/reference.md`).

## Goals / Non-Goals

**Goals:**

- Config loading and meta storage behave the same under json 2 and json 3.
- What plugins read back from `set_meta` on the writing instance does not change.

**Non-Goals:**

- Lifting the json pin.
- Rewriting existing repeated-key or duplicate rows in place. Reads tolerate them, and the next write of
  a record's options stores them without repeats.
- The older cache defects: `delete_meta` with loaded metas, stale `data_options` on update,
  `$current_site`, and `dup`/`reload` sharing the cache.

## Decisions

**Pin json below 3 as a runtime dependency.** The pin lives in the gemspec, with the same constraint in
the root Gemfile and the CI gemfiles.
- Rejected, leaving the pin to hosts: a plain `bundle update camaleon_cms` on Rails 8.1 resolves json 3
  and breaks every session read.
- Rejected, a development dependency: it protects the local and CI bundles but not hosts.

**Normalize option keys in the option writers, not in `set_meta`'s cache.**
- A first iteration cached an indifferent copy in `set_meta`. That changed what plugins read back on the
  writing instance: equality with their own hash, keyword splats, Symbol `keys`, and object identity.
- Keys only mix inside the options hash, where a writer adds a key to what an earlier write left.
- So the writers now work on an indifferent options hash: in place when it is already indifferent, and
  starting from an empty indifferent hash when the record has none. `set_meta` caches the caller's value
  untouched.

**One indifferent JSON generator for both serializers.** Both `fix_meta_value` copies make Hash and Array
values indifferent at every depth before generating.
- Rejected, deleting the `CustomFieldsRead` copy: the `Metas` copy also coerces Strings with `to_var`,
  which would change stored custom-field values.

**Tolerate repeated keys on read.** Meta reads parse with `allow_duplicate_key: true`, which keeps json 2's
last-value result on every version.
- Rejected, a Rake repair task: it would have to scan and rewrite every meta's JSON to fix rows that
  already read correctly.

**Lowest id for both the write target and the read.** The write lookup orders by id, and eager-loaded reads
take the lowest id among the matches.
- Rejected, a unique index plus a dedupe migration: it would change the schema and need a data migration,
  while aligning the order stops the lost writes without either.

**Update the pending built meta during create.** A saved record's `set_meta` first looks for an unsaved
meta with the same key in the association.
- Rejected, moving the options save to `after_commit`: it takes the save outside the create's
  transaction.
- Rejected, declaring the callback after the association: the concern's `included` block runs before the
  including model defines `has_many :metas`.

**Tolerant loaders, strict shipped files.** The six config parses go through one helper that allows comments
and repeated keys. The configs the gem ships stay plain JSON, and a spec that parses them strictly guards
that. Tolerance serves files hosts and third-party gems own; strictness keeps what the gem ships valid for
any parser.

## Risks / Trade-offs

- [A host bundle holding a gem that requires json 3 cannot resolve camaleon_cms 2.9.5] → The upgrade
  guide says so. The pin is lifted once Rails releases support json 3.
- [Before, `set_meta` on a saved record that also held an unsaved built meta for that key wrote a row at
  once; now it updates the built meta, which is stored with the record's next save] → That path used to
  store a duplicate row.
- [After a first option write, the writing instance's `options` is an indifferent hash instead of a
  plain one] → A reloaded record already returned an indifferent hash, and `get_option` reads both.
- [Repeated-key and duplicate rows stay in the database until the record is written again] → Reads return
  a consistent value in the meantime, and no value is lost.
- [The `allow_*` options have no effect on json releases that predate them] → Those releases already
  accept comments and repeated keys by default.
