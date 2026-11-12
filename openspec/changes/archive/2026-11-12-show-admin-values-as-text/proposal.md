# Show admin values as text

## Why

The admin JavaScript put some values into HTML strings. A value with a tag then added an element to
the admin page. The event handler of that element ran in the session of the admin.

The tag editor of the post form built each tag from the value of the tags input. The save of a post
stores a tag name as sent. So an author who is not an administrator can store a name with markup.
The tags input also takes the `tags` param of a GET request, so a link reached the same code.

The post form put the slug into the HTML of its permalink line. No server code changes a slug. So
an author who is not an administrator can store a slug with a tag through a request of their own.

The media manager built its breadcrumb from the `folder` param of its page. So a link ran markup
when the page opened. The details of an image and the title of the image editor held the `dimension`
param. Its markup ran after a click on an image.

### Triage verdict: legit

A probe stored a tag name with `img` markup as a Contributor. The `onerror` handler of that markup
ran in the edit form of an admin. A link with the `tags` param ran the same handler.
`spec/features/admin/post_tag_markup_spec.rb` fails before the fix.

A probe stored a slug with an `img` tag as an Editor and as a Contributor. Its `onerror` handler ran
in the edit form of an admin. `spec/features/admin/post_slug_markup_spec.rb` fails before the fix.

A probe opened the media manager through a link with an `img` tag in `folder`, and then in
`dimension`. Its `onerror` handler ran at once for `folder`, and after a click for `dimension`.
`spec/features/admin/media_manager_param_markup_spec.rb` fails before the fix.

## What Changes

- The tag editor shows a tag name as text. It sets and reads the name of a tag as text.
- The permalink line of the post form shows the slug, and the URL around it, as text.
- The media manager shows the `folder` param and the `dimension` param of its page as text.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the text form of a tag name.

## Capabilities

### New Capabilities

- `admin-value-text-display`: the admin JavaScript shows a tag name, a slug, and the `folder` and
  `dimension` params of the media manager as text, not as HTML.

### Modified Capabilities

None.

## Impact

- `app/assets/javascripts/camaleon_cms/admin/tageditor/_jquery.tag-editor.js`
- `app/assets/javascripts/camaleon_cms/admin/_post.js`
- `app/assets/javascripts/camaleon_cms/admin/uploader/_media_manager.js`
- Specs: `spec/features/admin/post_tag_markup_spec.rb`,
  `spec/features/admin/post_slug_markup_spec.rb` and
  `spec/features/admin/media_manager_param_markup_spec.rb`
- `docs/upgrading-to-2.9.5.md`
- Ecosystem: no sibling checkout of a surveyed member calls `tagEditor`.
