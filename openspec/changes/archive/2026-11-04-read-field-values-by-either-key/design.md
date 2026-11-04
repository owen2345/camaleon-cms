# Design

## Context

See proposal.md, "Why". `add_custom_field_group` in the same concern already reads its argument with
indifferent access. `set_meta` treats a String key and its Symbol twin as the same key
(`meta-storage-integrity`).

## Goals / Non-Goals

**Goals:**

- A plain Hash with String keys stores its values, and its group numbers are validated.

**Non-Goals:**

- A payload that is not a Hash and not request parameters, for example a list. The call raises
  `NoMethodError`, as before.
- An entry that is not a Hash. The call raises, as before.

## Decisions

**D1. The method reads a plain Hash with indifferent access.** `datas.with_indifferent_access` gives
a copy with String keys at each level, and the reads keep their Symbol keys. The copy leaves the
Hash of the caller as it is. Request parameters are not a Hash, and they already read by either key,
so the method does not convert them. The remedy rule of `docs/security/permissions.md` covers the
content of a value: the copy changes no value.

- *Alternative: refuse an entry with String keys before the delete.* Rejected: no other writer of
  Camaleon refuses a String key. `set_meta`, `set_option` and `add_custom_field_group` accept both.
  The sample in the comment of the method has String keys, so a refusal makes the sample an error.
- *Alternative: read each key twice (`values[:values] || values['values']`).* Rejected: it spreads
  the key rule over three reads, and each later read of an entry must repeat it.

**D2. The copy is one `with_indifferent_access` call for each save.** A Hash with indifferent access
returns a shallow copy, and a plain Hash converts each nested Hash one time. The admin saves pass a
Hash with indifferent access, so they pay one shallow copy.

**D3. A String key and its Symbol twin at one level raise `ArgumentError` before the delete.** The
copy of D1 keeps only one of their two values, and the order of the keys decides which. Before this
change, the method stored both twins of a slug when their entries had Symbol keys. The check reads
each level of the payload, the values of an entry too, so the copy changes no value. The maintainer chose the refusal.

- *Alternative: keep the last twin and record it as an intended limit.* Rejected: the call then
  deletes a value with no error.

**D4. `set_field_value` reads its args with indifferent access.** Its args had the same defect: a
String key such as `'group_number'` was ignored, so the call cleared and wrote group 0. The
maintainer chose to fix it in this change. The method refuses twin keys of its args, as D3 says.

## Risks / Trade-offs

- [A caller passes a Hash subclass with its own key rules] → the copy is a plain indifferent Hash.
  The rules of the subclass do not apply to the reads of this call. No surveyed consumer does this.
