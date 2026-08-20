# Proposal: add-multilingual-content-translation-spec

## Why

Camaleon stores multilingual content inline, as HTML-comment locale markers
(`<!--:en-->Hello<!--:-->`) inside a single column, and resolves them at render time through
monkey-patches on `String`, `Hash` and `Array`. This mechanism is load-bearing across the
codebase — post titles and content, slugs, taxonomy names, custom field values, metas and site
options all pass through it, and slug-uniqueness validation parses it — yet it has no capability
of its own. Adjacent specs already depend on it without stating it: `post-content-sanitization`
requires markers to survive sanitization, and `escaped-title-composition` reasons about
transformations applied to translatable names.

The gap has cost something concrete. `String#translations` memoized its parsed result in an
instance variable on the receiver, which Ruby 3.4's frozen `nil.to_s` cannot carry, so validating
a post without a slug raised `FrozenError` instead of reporting `Slug can't be blank` — a defect
that stood since before 2.9.2 with nothing recording that parsing must not mutate its receiver.

## What Changes

This is a **documentation-only** change: it records behavior that already exists, verified by
executing the current implementation rather than by reading it. No application code changes as
part of this change.

The one requirement not purely historical is that parsing must not depend on mutating the
receiver, which the accompanying fix in this PR makes true for frozen strings.

Captured behavior:

- Marker syntax and the locale-code shape the parser accepts.
- Resolution order for `String#translate`: requested locale, then `I18n.default_locale`, then an
  empty string when the value carries translations for neither, then the value itself when it
  carries none.
- Pass-through for untagged content, so a plain string is never damaged by being translated.
- The `String#translations` / `String#translations_array` contracts, including the
  `translations_array` fallback to the receiver.
- `Hash#to_translate` composition and its round-trip with `String#translations`.
- `Array#translate` element-wise mapping.
- Marker survival through `CamaleonRecord.cama_sanitize_translatable`, and the guarantee that
  user-typed `!--` / `--!` text is not promoted into marker delimiters.
- Parsing does not mutate the receiver, so frozen strings are safe.

## Capabilities

### New Capabilities

- `multilingual-content-translation`: the inline locale-marker format and the resolution rules
  that read it.

### Modified Capabilities

<!-- none -->

## Impact

No code impact. Documents `lib/ext/translator.rb`, the translation sentinels in
`app/models/camaleon_record.rb`, and the behavior relied on by decorators, validators and
`post-content-sanitization`. Existing regression coverage lives in
`spec/lib/ext/translator_spec.rb`.
