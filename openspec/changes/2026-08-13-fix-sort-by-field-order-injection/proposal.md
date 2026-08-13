## Why

`sort_by_field(key, order)` is a documented public API — themes and plugins call
`collection.sort_by_field(key, params[:order])` — that interpolated `order` straight into the SQL
`ORDER BY` clause. On the supported Rails range (6.1+) ActiveRecord's raw-SQL guard blocks arbitrary
injection here, but two real problems remain: a hostile direction raises
`ActiveRecord::UnknownAttributeReference` — an unhandled 500 (minor DoS) — and the guard still permits
comma-separated `ORDER BY` continuations, so an attacker can append attacker-chosen `<column>
<direction>` terms (a blind ordering oracle). Audit finding Tier-2 #8.

### Triage verdict: legit (scoped)

Reproduced against master (`spec/initializers/active_record_extension_spec.rb`): a stacked/comment
direction raises `UnknownAttributeReference`, and a comma-continuation direction emits
`ORDER BY ...value ASC, ...term_order DESC` — the injected term executes. Both fail without the fix
(confirmed by stashing it). Arbitrary SQL is blocked by Rails' guard, so this is a Low, not a critical.

## What Changes

- `sort_by_field` whitelists the direction: a case-insensitive `DESC` orders descending, everything
  else (including the documented default) orders ascending. The argument is no longer interpolated.
- It orders by a quoted Arel column (`CustomFieldsRelationship.arel_table[:value]`) instead of an
  interpolated string, so a hostile direction can neither append `ORDER BY` terms nor raise.
- The method no longer relies on ActiveRecord's implicit raw-SQL guard — a future `Arel.sql()`
  refactor cannot silently reintroduce injection.

## Notes for upgraders

- `sort_by_field` now honors only `asc`/`desc` (case-insensitive) and falls back to ascending for any
  other value. Any caller that (undocumented) passed additional raw SQL through the `order` argument
  must use `reorder` directly instead.

## Out of scope

- The `key` argument is already bound as a query parameter and is not an injection sink; unchanged.
- The unrelated `filter_by_field` helper in the same file is not affected (no raw interpolation).
