# Design: add-multilingual-content-translation-spec

## Context

The inline locale-marker mechanism predates every existing capability in `openspec/specs/` and is
implemented as monkey-patches in `lib/ext/translator.rb` (`String#translate`,
`String#translations`, `String#translations_array`, `Hash#to_translate`, `Array#translate`) plus
the sanitization sentinels in `app/models/camaleon_record.rb`. Two capabilities already lean on it
without stating it — `post-content-sanitization` (markers must survive sanitization) and
`escaped-title-composition` (transformations on translatable names). Writing it down was prompted
by a defect this PR fixes: parsing memoized onto the receiver, so a frozen receiver raised
`FrozenError`, and nothing recorded that parsing must not mutate what it reads.

## Goals / Non-Goals

**Goals:**

- Record the format and the resolution rules as they behave today, so future changes have
  something to be checked against.
- State the one property whose violation caused the defect: parsing must not depend on mutating
  the receiver.

**Non-Goals:**

- Changing any behavior. This change adds no code; the accompanying fix is scoped to the frozen
  receiver.
- Specifying the admin editing UI, the language-switcher, or `I18n` message translation
  (`ct`/`cama_t`/`on_translation`) — that is a different mechanism which happens to share the word
  "translation", and is already partly covered by `uploader-implementation-parity`.
- Enshrining incidental artifacts of the current parser (see D3).

## Decisions

- **D1 — Every scenario was derived by executing the implementation, not by reading it.** The
  resolution order, the empty-string case, the `translations_array` fallback, regional locale
  codes, multiline content, the sanitization round-trip and the `nil` element behavior were each
  confirmed against the running code before being written down. A spec asserted from a reading of
  the source would risk codifying what the author assumed rather than what ships.
- **D2 — The empty-string result is documented as deliberate, not as a quirk.** When a value
  carries translations but for neither the requested nor the default locale, `translate` returns
  `''`. That is a real product decision — render nothing rather than serve the reader a language
  they did not ask for — and stating it prevents a future "fix" from falling back to an arbitrary
  available locale.
- **D3 — Incidental parser artifacts are deliberately left unspecified.** Text sitting outside any
  marker is currently retained in the output (`"  \n<!--:en-->Hi<!--:-->"` translates to
  `"  \nHi"`). It is observable, but it reads as an artifact of the `gsub`-based extraction rather
  than intended behavior, so it is described nowhere in the requirements. Specifying it would make
  a future cleanup a spec violation.
- **D4 — Caching is permitted but must not be load-bearing.** The requirement says an
  implementation MAY cache on a mutable receiver but SHALL NOT make correctness depend on it. This
  keeps the current memoization legal (it is a real hot path: `translate` consults `translations`
  up to three times per call) while forbidding the shape that caused the defect.

## Risks / Trade-offs

- [Documenting current behavior can freeze a latent bug in place] → mitigated by D3: only rules
  that read as intended are stated, and the one known artifact is explicitly excluded.
- [The marker format is a public, on-disk contract that themes and plugins parse themselves] →
  that is precisely the argument for writing it down; the spec makes the contract explicit rather
  than creating it.

## Migration Plan

None. No code or data changes.

## Open Questions

None.
