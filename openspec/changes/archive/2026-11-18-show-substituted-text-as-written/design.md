## Context

See `proposal.md`, "Why". The markup scan of PR #1345 reads each custom field value as it is stored. It rests on one premise: the `data` shortcode shows the value as stored. `String#sub` with a String replacement broke that premise.

## Decisions

**D1. A shortcode is replaced at its place, and an output is not searched again.** `_cama_replace_shortcodes` lists the shortcodes of the text once. It then replaces them from left to right, and each search starts after the last output. An output goes into the text by index, not as a replacement String.

- Alternative: the block form `content.sub(shortcode) { output }`. It shows each output as written, but the next search still reads the earlier outputs. Rejected, because a value with the text of a later shortcode still takes that shortcode's output.
- Alternative: refuse a backslash before a quote, a backtick, `&` or a digit at save. It refuses valid text, such as a Windows path, and it leaves the renderer as it is. Rejected.

**D2. An enclosing shortcode keeps its contract.** It gets its inner text as written in `args[:shortcode_content]`. The shortcodes of that text are then replaced in its output, from left to right. `spec/helpers/short_code_helper_spec.rb` holds this contract ("Many Shortcodes").

- A shortcode before the closing tag of an enclosing shortcode is one of its children. A child that the output does not show is not replaced.
- The output can show the shortcodes of a child without that child, or without its closing tag. They are then replaced at their place in the output, as the next shortcodes of that text.
- The inner text of the parent ends at its closing tag. So a child has a closing tag only before that tag, and a later closing tag does not close it.
- A shortcode with no closing tag gets no inner text. Before, `args` kept the inner text of an earlier enclosing shortcode. The `lightbox` shortcode of `cama_image_lightbox` then showed that text, not its `title`.
- Alternative: replace the inner shortcodes first, and give the enclosing shortcode the result. It changes what `args[:shortcode_content]` holds for each plugin. Rejected.

**D3. A closing tag counts only after its shortcode.** A closing tag before a shortcode, or in an earlier output, is text. Before, it raised `NoMethodError`.

**D4. An output that is no String goes in as `String#sub` put it.** A Hash gives the value of the shortcode text, or an empty text. The `grid_editor` callback of `camaleon_editor` returns the Hash of `append_asset_libraries`, so its marker shows nothing. Any other output that is no String raises a `TypeError`, as before.

- Alternative: `output.to_s`, as the block form of `sub` does. It shows the Hash of `grid_editor` on each page of that plugin. Rejected.

**D5. `cama_replace_codes` replaces all codes in one pass.** It makes the code of each key in the given format. One `gsub` with a block then replaces each place of a code. The first value of a code counts, as the first `gsub` of the loop did before. An unknown format gives the text as it is.

- Alternative: the block form in each `gsub` of the loop. A later `gsub` still searches the values that an earlier one put in. Rejected.
- A text with invalid bytes is matched by its bytes. A Regexp raises `ArgumentError` on such a text, and the loop before replaced its codes with a String pattern. The maintainer chose to keep that result on 2026-11-18. No surveyed caller gives such a text: each call runs `translate` first, which raises on it.
- A valid text is never matched by its bytes. In an encoding such as Shift_JIS, a byte of a character can equal `[`.
- The byte match does not read the characters of a text with invalid bytes. In Shift_JIS, it also replaces a code whose `[` is the second byte of a character, which the loop before did not. The maintainer chose to keep this on 2026-11-19.
- Alternative: let the method raise, and say so in the upgrade note. A plugin that reads a template file in Latin-1 then gets an error in place of a mail. Rejected.
- Alternative: rescue the error and run the loop before. That loop reads a backslash sequence and searches each value again. Rejected.

**D6. `draw_menu` interpolates its items.** It renders the items first and puts them into the container string. The placeholder `{__}` is gone.

- Before, `String#sub` read a backslash sequence of an item name. A `{__}` in `container_prepend` also took the items in place of the placeholder. No surveyed theme writes `{__}`.

- Alternative: the block form `html.sub('{__}') { items }`. It keeps a placeholder that a theme option can hold. Rejected.

## Risks / Trade-offs

- [A shortcode whose output has a backslash sequence now shows it as written.] → Before, `\\` showed one backslash and `\0` the shortcode. A plugin that wrote two backslashes to show one now shows two. No surveyed shortcode writes a backslash sequence in its own code (`docs/ai/ecosystem.md`).
- [An output that holds the text of a later shortcode keeps that text.] → Before, the later shortcode was replaced inside that output, and its own text stayed. No surveyed consumer relies on it.

## Migration Plan

Nothing to run. Stored content does not change. `docs/upgrading-to-2.9.5.md` tells plugin and theme developers what changes.
