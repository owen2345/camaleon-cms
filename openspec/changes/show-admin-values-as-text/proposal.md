# Show admin values as text

## Why

The admin JavaScript put some values into HTML strings. A value with a tag then added an element to
the admin page. The event handler of that element ran in the session of the admin.

The tag editor of the post form built each tag from the value of the tags input. The save of a post
stores a tag name as sent. So an author who is not an administrator can store a name with a tag.
The tags input also takes the `tags` param of a GET request, so a link reached the same code.

### Triage verdict: legit

A probe stored a tag name with an `img` tag as a Contributor. Its `onerror` handler ran in the edit
form of an admin. A link with the `tags` param ran the same handler.
`spec/features/admin/post_tag_markup_spec.rb` fails before the fix.

## What Changes

- The tag editor shows a tag name as text. It reads a tag as text, and it encodes the name before
  it puts the name into an HTML string.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the text form of a tag name.

## Capabilities

### New Capabilities

- `admin-value-text-display`: the admin JavaScript shows a value as text, not as HTML.

### Modified Capabilities

None.

## Impact

- `app/assets/javascripts/camaleon_cms/admin/tageditor/_jquery.tag-editor.js`
- Spec: `spec/features/admin/post_tag_markup_spec.rb`
- `docs/upgrading-to-2.9.5.md`
- Ecosystem: no sibling checkout of a surveyed member calls `tagEditor`.
