# Design

## D1. Decoded-member scanning

The stored value is a JSON `{attr:, value:}` pair, and what the renderer emits is the *decoded*
members, not the stored bytes. The two differ: the ActiveSupport JSON encoder (the admin-form path)
unicode-escapes angle brackets, so the stored string of a script payload contains no `<` at all and
passes any byte-level scan — while `JSON.parse` at render restores the markup exactly. The gate
therefore parses first and scans each member with the shared markup gate (post allowlist), the same
check `editor` values get. A value that does not parse is scanned as-is, which is what the renderer
would fall back to (it renders nothing for unparseable JSON; the gate stays conservative anyway).

## D2. Verbatim render plus the value bugfix

With the gate in place the partial emits the pair verbatim — consistent with the policy's
stored-equals-authored contract and with `editor` values — and the long-standing bug of printing
the attribute name twice is fixed by rendering `attrs['value']` in the value position.

## D3. Testing

Model examples (in `custom_field_value_rejection_spec.rb`): a literal-bytes script pair
(`JSON.generate`) and a unicode-escaped pair (`#to_json`, asserted to carry no literal `<script`)
are both refused for an untrusted author; a benign pair and an admin's script pair are stored
byte-for-byte. View examples (`render_custom_field_field_attrs_spec.rb`): the pair renders
verbatim, the VALUE is rendered (not the label twice), and an unparseable value renders no pair.
Gate examples fail without the `JSON_MARKUP_FIELD_KEYS` branch and the view bugfix example fails
against the original partial (stash-verified).
