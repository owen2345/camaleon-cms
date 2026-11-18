## Context

See `proposal.md`, "Why". The markup scan of PR #1345 reads each custom field value as it is stored. It rests on one premise: the `data` shortcode shows the value as stored. `String#sub` with a String replacement broke that premise.

## Decisions

**D1. A shortcode is replaced at its place, and an output is not searched again.** `_cama_replace_shortcodes` lists the shortcodes of the text once. It then replaces them from left to right, and each search starts after the last output. An output goes into the text by index, not as a replacement String.

- Alternative: the block form `content.sub(shortcode) { output }`. It shows each output as written, but the next search still reads the earlier outputs. Rejected, because a value with the text of a later shortcode still takes that shortcode's output.
- Alternative: refuse a backslash before a quote, a backtick, `&` or a digit at save. It refuses valid text, such as a Windows path, and it leaves the renderer as it is. Rejected.

**D2. An enclosing shortcode keeps its contract.** It gets its inner text as written in `args[:shortcode_content]`. The shortcodes of that text are then replaced in its output, from left to right. `spec/helpers/short_code_helper_spec.rb` holds this contract ("Many Shortcodes").

- A shortcode before the closing tag of an enclosing shortcode is one of its children. A child that the output does not show is not replaced.
- Alternative: replace the inner shortcodes first, and give the enclosing shortcode the result. It changes what `args[:shortcode_content]` holds for each plugin. Rejected.

**D3. A closing tag counts only after its shortcode.** A closing tag before a shortcode, or in an earlier output, is text. Before, it raised `NoMethodError`.

**D4. An output that is no String goes in as `String#sub` put it.** A Hash gives the value of the shortcode text, or an empty text. The `grid_editor` callback of `camaleon_editor` returns the Hash of `append_asset_libraries`, so its marker shows nothing. Any other output that is no String raises a `TypeError`, as before.

- Alternative: `output.to_s`, as the block form of `sub` does. It shows the Hash of `grid_editor` on each page of that plugin. Rejected.

**D5. `cama_replace_codes` replaces all codes in one pass.** It makes the code of each key in the given format. One `gsub` with a block then replaces each place of a code. The first value of a code counts, as the first `gsub` of the loop did before. An unknown format gives the text as it is.

- Alternative: the block form in each `gsub` of the loop. A later `gsub` still searches the values that an earlier one put in. Rejected.

## Risks / Trade-offs

- [A shortcode whose output has a backslash sequence now shows it as written.] → Before, `\\` showed one backslash and `\0` the shortcode. A plugin that wrote two backslashes to show one now shows two. No surveyed shortcode writes a backslash sequence in its own code (`docs/ai/ecosystem.md`).
- [An output that holds the text of a later shortcode keeps that text.] → Before, the later shortcode was replaced inside that output, and its own text stayed. No surveyed consumer relies on it.

## Migration Plan

Nothing to run. Stored content does not change. `docs/upgrading-to-2.9.5.md` tells plugin and theme developers what changes.
