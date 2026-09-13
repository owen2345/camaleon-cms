# Specify the meta storage and config loading behaviors hardened for json gem 3

## Why

json gem 3.0 rejects comments, repeated keys and unknown options by default. PR
[#1292](https://github.com/owen2345/camaleon-cms/pull/1292) made Camaleon's config loading and meta
storage behave the same under json 2 and json 3, and fixed the meta write bugs json 3 exposed: a key
stored twice, a write landing on a row that reads skip, and a second row on create. The fixes ship with
specs but with no OpenSpec capability, so nothing durable states what a meta write stores or how a
config file loads.

## What Changes

- Add `meta-storage-integrity`:
  - Option writers store one entry per key, whether the key was written as a String or a Symbol, and
    the writing instance reads it back by either.
  - `set_meta` keeps the value exactly as the caller passed it on the writing instance.
  - Hash and Array values (metas and custom-field values) serialize with one entry per key at any
    depth.
  - A stored meta whose JSON repeats a key reads with the last value.
  - When a key has several rows, writes update and reads return the lowest id.
  - A meta built before a record's first save is updated, not duplicated, by the after-create
    option save.
- Add `config-json-loading`:
  - `PluginRoutes` loads the system, plugin and theme configs accepting comments and repeated keys.
  - The JSON configs the gem ships, generates and tests with are plain JSON.
- No new application code. The behaviors and their specs are already on the PR #1292 branch; this
  change records them as requirements.

**Non-goals:**
- Supporting json 3 itself: camaleon_cms requires json `< 3` until Rails supports it.
- The older meta cache defects under separate investigation: `delete_meta` with loaded metas, stale
  `data_options` on update, `$current_site`, and `dup`/`reload` sharing the cache.

## Capabilities

### New Capabilities

- `meta-storage-integrity`: what option and meta writes store and what reads return. Covers key-type
  independence, the caller's cached value, repeated keys in stored JSON, duplicate rows, and metas
  built before the first save.
- `config-json-loading`: how `PluginRoutes` parses the system, plugin and theme configs, and the
  plain-JSON guarantee for the configs the gem ships.

### Modified Capabilities

None. The existing capabilities that touch these areas stay unchanged:
- `normalize-attrs-scoping` keeps its option round-trip scenario as is.
- `plugin-helper-registration` covers only the `helpers` key of a loaded config.
- `ecosystem-plugin-bindings` covers the `PluginRoutes` read methods.
- `meta-scope-resolution` covers `object_class` naming.

## Impact

- **Specs (new):** `openspec/specs/meta-storage-integrity/spec.md` and
  `openspec/specs/config-json-loading/spec.md`, via this change's deltas.
- **Application code (already on the branch):**
  - `app/models/concerns/camaleon_cms/metas.rb`
  - `app/models/concerns/camaleon_cms/custom_fields_read.rb`
  - `lib/plugin_routes.rb`
  - the json pin in `camaleon_cms.gemspec`, `Gemfile` and `gemfiles/*.gemfile`
  - the shipped JSON configs
- **Tests (already on the branch):**
  - `spec/models/meta_spec.rb`, `spec/models/meta_duplicate_rows_spec.rb`,
    `spec/models/meta_pending_create_spec.rb` and `spec/models/custom_field_value_json_spec.rb`
  - `spec/lib/plugin_routes_spec.rb` (`.all_themes`) and `spec/lib/shipped_json_configs_spec.rb`
- **Plugins and themes:**
  - What they read back from `set_meta` on the writing instance is unchanged.
  - `options` read indifferently on that instance, as after a reload.
  - Their configs keep loading with comments.
