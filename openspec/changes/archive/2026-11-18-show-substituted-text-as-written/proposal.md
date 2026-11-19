## Why

Three renderers put a value into a text with `String#sub` or `String#gsub` and a String replacement. Ruby reads a backslash sequence in such a replacement. `\'` gives the text after the match, `` \` `` the text before it, `\0` and `\&` the match, and `\\` one backslash. So the page does not show the value as it is stored:

- `do_shortcode` and `render_shortcode` replace each shortcode with its output. A `text_box` value `<img src="x" title="\'">` that the `data` shortcode shows takes in the rest of the post content. A second value then ends its `title` attribute and adds an event handler. Each value passes the markup scan alone. `spec/requests/security/data_shortcode_field_markup_spec.rb` reproduces it.
- `String#cama_replace_codes` replaces each code, such as `[c1]`, with a value. `cama_contact_form` gives it the values that a visitor sends, and `camaleon-ecommerce` the data of an order.
- `draw_menu` puts the rendered menu items into the menu container.

Two more defects come from a search of the changed text. `do_shortcode` searched the whole text again for each shortcode. So the text of a later shortcode in an earlier output was replaced there. A closing tag before a shortcode, or in an earlier output, raised `NoMethodError`. `cama_replace_codes` also searches each value that it put in for the next code.

## What Changes

- `do_shortcode` and `render_shortcode` replace each shortcode at its place, from left to right. A search starts after the last output, and each output shows as written. An enclosing shortcode gets its inner text as written, as before. The shortcodes of that text are replaced in its output, as before.
- `cama_replace_codes` replaces all codes in one pass over the text, and each value shows as written.
- `draw_menu` puts the menu items into the container with no replacement.

Non-goals:

- No change of the markup scan or of the stored text. Each value passed the scan, and the remedy is to show it as stored.
- No change of the shortcode syntax, of the registry or of the template of a shortcode.

## Capabilities

### New Capabilities

- `text-substitution-integrity`: a renderer shows each value that it puts into a text as written. It does not search that value again.

### Modified Capabilities

None.

## Impact

- `app/helpers/camaleon_cms/short_code_helper.rb`: `do_shortcode`, `render_shortcode` and the private `_cama_replace_shortcode`, which is gone.
- `lib/ext/string.rb`: `cama_replace_codes`.
- `app/helpers/camaleon_cms/frontend/nav_menu_helper.rb`: `draw_menu`.
- Specs: `spec/helpers/short_code_helper_spec.rb`, `spec/requests/security/data_shortcode_field_markup_spec.rb`, `spec/lib/ext/string_spec.rb` and `spec/helpers/camaleon_cms/frontend/nav_menu_helper_spec.rb`.
- Docs: `docs/upgrading-to-2.9.5.md`, `docs/ai/ecosystem.md` and `CHANGELOG.md`.
