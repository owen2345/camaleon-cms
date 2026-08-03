# Tasks: add-multilingual-content-translation-spec

## 1. Establish ground truth

- [x] 1.1 Execute the current implementation to confirm resolution order, the empty-string case,
  the `translations_array` fallback, regional locale codes, multiline content, `to_translate`
  round-trip, `Array#translate` coercion, and the sanitization round-trip

## 2. Author the capability

- [x] 2.1 Write the `multilingual-content-translation` delta covering format, resolution,
  pass-through, array contract, frozen-receiver safety, sanitization survival, and composition
- [x] 2.2 Record in `design.md` why the empty-string case is deliberate and why the
  outside-marker retention artifact is left unspecified

## 3. Close-out

- [x] 3.1 `openspec validate --strict` passes; existing regression coverage
  (`spec/lib/ext/translator_spec.rb`) already exercises the frozen-receiver requirement
- [x] 3.2 Archive this change on the branch as part of the PR
