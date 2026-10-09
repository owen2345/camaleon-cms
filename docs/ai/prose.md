# Prose Standard

All prose follows ASD-STE100 Simplified Technical English. A person must understand the prose easily, and the prose must be short. Clear prose comes first, but long prose is hard to read too.

## Clear prose comes first

A text can obey each rule of the other sections and still be hard to understand. A text that is hard to understand is a defect.

- Write for a developer who reads the code for the first time. That reader did not see the PR, its design notes or its review.
- Use the plain name of a thing. Do not use a label that only the authors of the change know.
- Name the product: write "Camaleon", not "core" or "the engine".
- Use the names that a Rails developer knows: `String`, `Integer`, a record, a validation. Do not write "a text" for a `String`.
- Explain a term of the domain one time, with an example of what the user sees.
- Each sentence must make sense alone. Do not write a sentence that only points back to the sentence before it.
- Give the cause with the effect. Say who does what, and what the user or the caller gets.
- Read each sentence alone after you write or change a text. Ask what the sentence tells a developer who reads the code for the first time.

## Scope

The standard applies to this repository and to the sibling plugin, theme and host app repositories.

The standard applies to:

- Code comments.
- New commit messages.
- PR titles and PR descriptions.
- The `describe`, `context` and `it` descriptions of new specs.
- Any Markdown file, for example `README.md`, `CHANGELOG.md` and the files under `docs/` and `openspec/`.

Apply the standard to the prose that you add or change. These limits apply:

- You can rewrite the description of an old spec only when your change edits that spec.
- Never rewrite a commit message that is already on the remote.
- Do not apply the standard to a file that a tool writes. An example is the output of `openspec update` under `.claude/`, `.github/`, `.junie/` and `.opencode/`.
- Do not apply the standard to a file that another project wrote, for example the TinyMCE `readme.md` under `app/assets`.

## Sentences and paragraphs

- Use a maximum of 25 words in a sentence. Use a maximum of 20 words in an instruction.
- Write about one topic in each sentence.
- Use a maximum of six sentences in a paragraph.
- Use a bullet list for an enumeration or for a set of conditions.

## Verbs

- Use the active voice when you know who or what does the action.
- Use the simple present, the simple past or the simple future tense. Do not use the present perfect.
- Use "can" for ability and "must" for obligation. Do not use "would", "should", "may" or "might".
- In a requirement of an OpenSpec spec, write SHALL or MUST for an obligation. `openspec validate --strict` fails a requirement that has neither.
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
| The gate refuses the payload. | The save fails, because the author is not permitted to save this content. |
| It fails. | The save fails, and the author sees the error in a flash message. |
| This does not help. | A redirect does not help: the next page runs the same check, and the save fails again. |
| A post type groups the posts. | A post type is a kind of content, for example "News" or "Product". Each post belongs to one post type. |
| The method takes the id as an integer or as a text. | The method takes the id as an `Integer` or a `String`. |
| The core runs the hook. | Camaleon runs the hook. |
