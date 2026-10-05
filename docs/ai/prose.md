# Prose Standard

All prose follows ASD-STE100 Simplified Technical English. A person must understand the prose easily. This rule comes first, before the rules for short sentences and concise prose. The maintainer set this standard on 2026-10-04 and put the clarity rule first on 2026-10-05.

## Clear prose comes first

A text can obey each rule of the other sections and still be hard to understand. Such a text is a defect.

- Write for a developer who reads the code for the first time. That reader did not see the PR, its design notes or its review.
- Use the plain name of a thing. Do not use a label that only the authors of the change know.
- Each sentence must make sense alone. Do not write a sentence that only points back to the sentence before it.
- Give the cause with the effect. Say who does what, and what the user or the caller gets.
- Use more words when fewer words are not clear. Use a list for cases and conditions.
- Read each sentence alone after you write or change a text. Ask what the sentence tells that reader.

## Scope

The standard applies to this repository and to the sibling plugin, theme and host app repositories.

The standard applies to:

- Code comments.
- `README.md` and the files under `docs/`.
- `CHANGELOG.md` entries.
- New commit messages.
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
- Do not remove a word or a fact that the reader needs to understand the text. Clear prose comes first.

## Examples

| Do not write | Write |
|---|---|
| Saving the post fires the hook; it'll run the callbacks. | The hook runs the callbacks when the author saves the post. |
| The value has been cached and should be reused. | The model caches the value. The next call must use the same value. |
| Bail out if the site isn't there. | Return if the site does not exist. |
| A value row refuses a value that a gate refuses. | The save of a custom-field value fails when its author is not permitted to save its content. |
| The create of a post rolls back what it stored. No other admin save does. | The create of a post stores nothing. Each other admin save keeps what it stored before the custom-field values. |
| A redirect then reaches another page that refuses again. | A redirect does not help: the next page runs the same hook, and the save fails again. |
