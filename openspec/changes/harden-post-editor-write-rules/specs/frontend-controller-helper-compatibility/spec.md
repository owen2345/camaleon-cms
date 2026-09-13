## ADDED Requirements

### Requirement: cama_t resolves its English fallback with the caller's lookup options

`cama_t(key, options)` SHALL look the English fallback up with the lookup options the caller passed (`scope`, `separator`, `raise`, `throw`) and without the interpolation values, so the fallback is the same translation the caller named and is interpolated exactly once with the caller's values. The helper SHALL NOT modify the options hash the caller passed.

#### Scenario: A scoped key falls back to the scoped English text

- **WHEN** the current locale lacks a key and `cama_t` is called with `scope:` and an interpolation value
- **THEN** the result is the English translation under that scope, interpolated with the value

#### Scenario: A missing key with raise: true raises

- **WHEN** `cama_t` is called with `raise: true` for a key missing in every locale
- **THEN** it raises the missing-translation error

#### Scenario: An interpolation value carrying a placeholder token is inserted verbatim

- **WHEN** the current locale lacks a key and `cama_t` is called with a value containing `%{x}`
- **THEN** the result contains that value verbatim and nothing raises

#### Scenario: The caller's options are left untouched

- **WHEN** the same options hash is passed to two `cama_t` calls for different keys
- **THEN** the second call resolves its own English fallback, not the first call's
