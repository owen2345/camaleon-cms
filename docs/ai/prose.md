# Prose Standard

All prose follows ASD-STE100 Simplified Technical English. A person must understand the prose easily, and the prose must be short. Clear prose comes first, but long prose is hard to read too. The maintainer set this standard on 2026-10-04 and put the clarity rule first on 2026-10-05. The rules for short prose and plain names came on 2026-10-06.

## Clear prose comes first

A text can obey each rule of the other sections and still be hard to understand. Such a text is a defect.

- Write for a developer who reads the code for the first time. That reader did not see the PR, its design notes or its review.
- Use the plain name of a thing. Do not use a label that only the authors of the change know.
- Name the product: write "Camaleon", not "core" or "the engine".
- Use the names that a Rails developer knows: `String`, `Integer`, a record, a validation. Do not write "a text" for a `String`.
- Explain a term of the domain one time, with an example of what the user sees.
- Each sentence must make sense alone. Do not write a sentence that only points back to the sentence before it.
- Give the cause with the effect. Say who does what, and what the user or the caller gets.
- Use a list for cases and conditions.
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

- A code comment says what the code does and why, in a few lines. Do not list each edge case, each Rails version or each result there: the specs hold the cases, and `design.md` holds the reasons.
- Tell each fact in one place. Other places give one line or a link.
- Write the history of a decision (who chose it, when, and the options that lost) only in `design.md`. A comment marks a behavior that the maintainer chose to keep with "(intended)".
- An upgrade note says what changes for the reader and what the reader must do. It does not explain how the code works.
- Remove rationale that the code or the PR description already gives.
- Do not remove a word or a fact that the reader needs to understand the text.

## Examples

| Do not write | Write |
|---|---|
| Saving the post fires the hook; it'll run the callbacks. | The hook runs the callbacks when the author saves the post. |
| The value has been cached and should be reused. | The model caches the value. The next call must use the same value. |
| Bail out if the site isn't there. | Return if the site does not exist. |
| A value row refuses a value that a gate refuses. | The save of a custom-field value fails when its author is not permitted to save its content. |
| The create or update of a post rolls back what it stored. No other admin save does. | The create or update of a post stores nothing. Each other admin save keeps what it stored before the custom-field values. |
| A redirect then reaches another page that refuses again. | A redirect does not help: the next page runs the same hook, and the save fails again. |
| A field group can repeat on a record. The group number of a value says which copy of the group holds the value. | An author can add a repeatable field group to a post several times, for example a "Slide" group for each slide. The group number of a value is the index of its slide, from 0. |
| Code can give the integer as an Integer or as a text of 1 to 16 ASCII digits. | The group number is an Integer, or a String of 1 to 16 digits such as `'5'`. |
| The core admin forms send the index of the group. | The admin forms of Camaleon send the index of the group. |
