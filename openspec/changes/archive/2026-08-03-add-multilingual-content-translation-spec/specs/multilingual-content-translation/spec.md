## ADDED Requirements

### Requirement: Translatable values carry their locales inline as comment markers

A single stored value MAY hold content for several locales at once, delimited by HTML-comment
markers of the form `<!--:<locale>-->content<!--:-->`. The locale code SHALL be 2 to 5 characters
drawn from word characters and `-`, so both plain (`en`) and regional (`pt-BR`) codes are
accepted. A value is treated as translatable when it starts with `<!--` after whitespace is
squished, so leading whitespace does not disable translation.

#### Scenario: A two-locale value exposes both locales
- **WHEN** a value is `<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->`
- **THEN** `translations` returns `{ en: 'Hello', es: 'Hola' }`

#### Scenario: A regional locale code is accepted
- **WHEN** a value is `<!--:pt-BR-->Ola<!--:-->`
- **THEN** `translations` contains the key `:'pt-BR'` with value `Ola`

#### Scenario: Content spanning several lines is preserved
- **WHEN** a locale's content contains newlines
- **THEN** the whole content, including the newlines, is returned for that locale

### Requirement: Translation resolves to the requested locale, then the default, then empty

`String#translate(locale = nil)` SHALL resolve against `I18n.locale` when no locale is given, and
otherwise in this order: the requested locale if the value carries it; else `I18n.default_locale`
if the value carries it; else an empty string when the value carries translations for other
locales; else the value itself.

The empty-string case is deliberate: a value that has been translated but not into any locale the
reader can be served renders as nothing rather than leaking another language's text.

#### Scenario: The requested locale is present
- **WHEN** `<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->` is translated to `:es`
- **THEN** the result is `Hola`

#### Scenario: The requested locale is absent and the default is present
- **WHEN** the same value is translated to `:fr`
- **AND** `I18n.default_locale` is `:en`
- **THEN** the result is `Hello`

#### Scenario: Neither the requested nor the default locale is present
- **WHEN** `<!--:es-->Hola<!--:-->` is translated to `:fr` and `I18n.default_locale` is `:en`
- **THEN** the result is an empty string

### Requirement: Untagged content passes through translation unchanged

A value carrying no locale markers SHALL be returned unchanged by `translate`, for any locale, and
SHALL report no translations. Translation is therefore safe to apply to values that were never
multilingual, which is what lets decorators call it unconditionally.

#### Scenario: A plain string survives translation
- **WHEN** `Just a title` is translated to `:es`
- **THEN** the result is `Just a title`
- **AND** `translations` returns an empty hash

#### Scenario: A blank value translates to itself
- **WHEN** an empty string is translated
- **THEN** the result is an empty string

### Requirement: The translations array falls back to the whole value

`String#translations_array` SHALL return the content of every locale the value carries, and SHALL
fall back to a single-element array holding the value itself when it carries none. Callers that
must inspect every stored variant — slug-uniqueness validation among them — can therefore treat
translated and untranslated values alike.

#### Scenario: A multilingual value yields one entry per locale
- **WHEN** `<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->` is asked for its translations array
- **THEN** the result contains `Hello` and `Hola`

#### Scenario: An untranslated value yields itself
- **WHEN** `Just a title` is asked for its translations array
- **THEN** the result is `['Just a title']`

### Requirement: Parsing does not mutate the receiver

Reading translations SHALL NOT require mutating the value being read, so frozen strings — Ruby's
shared frozen `nil.to_s`, and every literal in a file with the `frozen_string_literal` magic
comment — can be translated like any other value. An implementation MAY cache the parse on a
mutable receiver, but SHALL NOT make correctness depend on being able to do so.

#### Scenario: A frozen value is translatable
- **WHEN** `translate`, `translations`, or `translations_array` is called on a frozen string
- **THEN** the call returns the same result it would for an equal mutable string
- **AND** no `FrozenError` is raised

#### Scenario: Validating a record whose translatable column is unset
- **WHEN** a post with no slug is validated, so slug parsing receives `nil.to_s`
- **THEN** validation completes and reports its own errors, such as `Slug can't be blank`

### Requirement: Locale markers survive sanitization, and comment-like text is never promoted

`CamaleonRecord.cama_sanitize_translatable` SHALL preserve locale markers through HTML
sanitization while still stripping dangerous markup from the content between them. Text a user
typed that merely resembles a marker delimiter SHALL NOT be converted into one.

#### Scenario: Markers survive while script inside them does not
- **WHEN** `<!--:en--><script>x</script>Hi<!--:-->` is sanitized
- **THEN** the locale markers are still present and parse back to the `:en` locale
- **AND** the `<script>` element is gone

#### Scenario: User-typed comment-like text stays literal
- **WHEN** a user writes `Sale !-- 50% --!` in translatable content
- **THEN** the stored value still reads `Sale !-- 50% --!`
- **AND** no `<!--` or `-->` delimiter is introduced

### Requirement: Translatable values can be composed and mapped

`Hash#to_translate` SHALL compose a locale-keyed hash into the marker format, round-tripping with
`String#translations`. `Array#translate` SHALL translate each element, coercing non-strings, so a
collection of translatable values can be resolved in one call.

#### Scenario: A hash composes into markers and parses back
- **WHEN** `{ es: 'Hola', en: 'Hello' }` is composed with `to_translate`
- **THEN** the result is `<!--:es-->Hola<!--:--><!--:en-->Hello<!--:-->`
- **AND** parsing that result returns the original pairs

#### Scenario: An array translates element-wise
- **WHEN** `['<!--:es-->Hola<!--:-->', 'plain']` is translated to `:es`
- **THEN** the result is `['Hola', 'plain']`

#### Scenario: A nil element translates to an empty string
- **WHEN** an array containing `nil` is translated
- **THEN** that element resolves to an empty string rather than raising
