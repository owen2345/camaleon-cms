# Design

## D1. Whitelist the direction, don't interpolate it

The one piece of caller input that reached the `ORDER BY` was the sort direction. It is now mapped to
a symbol before use:

```ruby
direction = order.to_s.casecmp?('DESC') ? :desc : :asc
```

`casecmp?` returns a boolean (Ruby 2.4+, safe across the 6.1+ range), so `desc`/`DESC`/`Desc` order
descending and anything else — the documented `'ASC'` default, a typo, or an attack string — orders
ascending. Falling back to ascending preserves the method's documented default and keeps a hostile
value from raising; it never becomes SQL.

## D2. Order by a quoted Arel column

The interpolated `reorder("#{cfr_table}.value #{order}")` is replaced with an Arel ordering node:

```ruby
.reorder(CamaleonCms::CustomFieldsRelationship.arel_table[:value].public_send(direction))
```

`arel_table[:value].asc` / `.desc` renders a properly quoted identifier plus a literal `ASC`/`DESC`
keyword (`"custom_fields_relationships"."value" ASC`). SQL has no bind slot for an ORDER BY direction,
so nothing is bound here — the keyword is safe because it can only come from the two whitelisted D1
symbols. No caller string is concatenated into SQL, so there is no ORDER BY sink left to guard. `arel_table`, attribute indexing, and `.asc`/`.desc` are stable public
Arel API across Rails 6.1–8.1, so the fix is version-agnostic.

## D3. Why not just rely on Rails' raw-SQL guard

On 6.1+ ActiveRecord already rejects arbitrary raw SQL in `reorder` via
`disallow_raw_sql!` / `column_name_with_order_matcher`. That guard is real but not sufficient here:

- It **raises** `ActiveRecord::UnknownAttributeReference` for a stacked/comment payload — an unhandled
  500 for any plugin that forwards `params[:order]` (a minor DoS, and a poor caller experience).
- Its matcher **permits comma-separated continuations**, so `order = "ASC, users.password DESC"`
  passes the guard and appends an attacker-chosen `ORDER BY` term — a blind ordering oracle.
- It is **implicit**: a later refactor that wraps the string in `Arel.sql(...)` to "fix a deprecation"
  would silently reintroduce full injection.

Whitelisting the direction and quoting the column removes all three, and stops the security of a public
API from depending on a framework internal.

## D4. Testing

`spec/initializers/active_record_extension_spec.rb` seeds two posts with a sortable custom field and
asserts, at the layer the code lives in:

- legitimate `asc` / `desc` / default directions still sort correctly (behavior preserved);
- a stacked/comment direction no longer raises and falls back to ascending;
- a comma-continuation direction does not add the injected term to the generated SQL.

The hostile-direction examples fail against unfixed master (verified by stashing the fix): the
stacked/comment example by the `UnknownAttributeReference` raise, and the comma-continuation example
by the injected `term_order` term in `to_sql`.
