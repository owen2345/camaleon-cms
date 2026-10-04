# Prose Standard

All prose follows ASD-STE100 Simplified Technical English. The prose must be concise and easy for a person to read. The maintainer set this standard on 2026-10-04.

## Scope

The standard applies to this repository and to the sibling plugin, theme and host app repositories.

The standard applies to:

- Code comments.
- `README.md` and the files under `docs/`.
- `CHANGELOG.md` entries.
- PR titles and PR descriptions.
- The `describe`, `context` and `it` descriptions of new specs.

Apply the standard to the prose that you add or change. These limits apply:

- You can rewrite the description of an old spec only when your change edits that spec.
- Never rewrite a commit message that is already on the remote.

## Sentences and paragraphs

- Use a maximum of 25 words in a sentence. Use a maximum of 20 words in an instruction.
- Write about one topic in each sentence.
- Use a maximum of six sentences in a paragraph.
- Use a bullet list for an enumeration or for a set of conditions.

## Verbs

- Use the active voice when you know who or what does the action.
- Use the simple present, the simple past or the simple future tense. Do not use the present perfect.
- Use "can" for ability and "must" for obligation. Do not use "would", "should", "may" or "might".
- Do not use the "-ing" form of a verb. A technical name such as "closing tag" is correct.

## Words and punctuation

- Do not use semicolons, contractions or idioms.
- Keep the articles and the word "that".
- Use one term for each thing. Use the term the same way everywhere.

## Concise prose

- Remove rationale that the code or the PR description already gives.
- Keep the facts that the reader needs.

## Examples

| Do not write | Write |
|---|---|
| Saving the post fires the hook; it'll run the callbacks. | The hook runs the callbacks when the author saves the post. |
| The value has been cached and should be reused. | The model caches the value. The next call must use the same value. |
| Bail out if the site isn't there. | Return if the site does not exist. |
