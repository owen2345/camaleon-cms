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

The media manager also put the name and the URL of a file into HTML. The URL holds the names of the
folders of the file, and an upload takes the folder from its request. So a role with the `media`
permission can store a file whose URL holds markup.

The Featured Image panel of the post form put the name of the picked file into HTML. An upload cleans
the name of a file, but a file that reaches the storage another way keeps its name.

The Upload Image link of that panel put three image options of the post type into the JavaScript of
its click handler. A role with the `settings` permission can store such an option. A quote in the
option ended the String, and the rest of the option ran as script.

The form of a custom field group put the help of the selected placement into HTML. The help of a
category holds the name of the category, and an Editor can store a name with markup. That markup ran
when an admin opened a group of that category.

The list of the media manager wrote the JSON data of each file into a hidden `textarea` with no
HTML escape. Rails writes `<` and `&` of JSON as escapes, and a host app can turn that setting off.
A folder name with a closing `textarea` tag then ended the element, and its markup ran.

### Triage verdict: legit

A probe stored a tag name with `img` markup as a Contributor. The `onerror` handler of that markup
ran in the edit form of an admin. A link with the `tags` param ran the same handler.
`spec/features/admin/post_tag_markup_spec.rb` fails before the fix.

A probe stored a slug with an `img` tag as an Editor and as a Contributor. Its `onerror` handler ran
in the edit form of an admin. `spec/features/admin/post_slug_markup_spec.rb` fails before the fix.

A probe opened the media manager through a link with an `img` tag in `folder`, and then in
`dimension`. Its `onerror` handler ran at once for `folder`, and after a click for `dimension`.
`spec/features/admin/media_manager_param_markup_spec.rb` fails before the fix.

A probe stored an image in a folder with `img` markup in its name. A click on the file added an `img`
element from that name to the details. `spec/features/admin/media_manager_file_markup_spec.rb` fails
before the fix.

A probe picked a file with `img` markup in its name as the featured image of a post. The panel added
an `img` element from that name. `spec/features/admin/post_featured_image_markup_spec.rb` fails
before the fix.

A probe stored a post type option with a quote and script after it. A click on Upload Image ran that
script. The example of the option in `spec/features/admin/post_featured_image_markup_spec.rb` fails
before the fix.

A probe named a category with `img` markup and opened a custom field group of that category. The
form added an `img` element from that name when the page loaded.
`spec/features/admin/custom_field_group_help_markup_spec.rb` fails before the fix.

A probe turned the JSON setting off and stored an image in a folder path with a closing `textarea`
tag and an `img` tag. The list added an `img` element from that path.
`spec/requests/security/media_list_file_data_markup_spec.rb` fails before the fix.

## What Changes

- The tag editor shows a tag name as text. It sets and reads the name of a tag as text.
- The right-click delete of the tag editor removes an open tag with no text, with no error. It
  removes only the open tag, and gives no call of `beforeTagSave`.
- The permalink line of the post form shows the slug, and the URL around it, as text.
- The Preview link and the View link of the permalink line hold the slug as one segment of the
  path.
- The permalink line holds a URL with no place for the slug as it is, and has no Edit link then. The
  form starts with no URL for its language.
- The media manager shows the `folder` param and the `dimension` param of its page as text.
- The image editor starts for a `dimension` param that has a part with no digit.
- The media manager shows the name and the URL of a file as text. It sets the URL as an attribute
  value of the link of the details and of the image of the image editor.
- The Featured Image panel of the post form shows the name of the picked file as text.
- The Upload Image link of the Featured Image panel gives the image options of the post type to its
  handler as attribute values.
- The form of a custom field group shows the help of a placement as text. Each placement option with
  a name gives that name with one escape.
- The list of the media manager writes the JSON data of a file with the HTML escape.
- The `I18n` function of the admin JavaScript puts each value into a translation as text.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the text form of a tag name.

## Capabilities

### New Capabilities

- `admin-value-text-display`: the admin JavaScript shows a value as text, not as HTML, in each place
  that the list above names.

### Modified Capabilities

None.

## Impact

- `app/assets/javascripts/camaleon_cms/admin/tageditor/_jquery.tag-editor.js`
- `app/assets/javascripts/camaleon_cms/admin/_post.js`
- `app/assets/javascripts/camaleon_cms/admin/uploader/_media_manager.js`
- `app/assets/javascripts/camaleon_cms/admin/_modal.js`
- `app/views/camaleon_cms/admin/posts/_sidebar.html.erb`
- `app/assets/javascripts/camaleon_cms/admin/custom_fields_form.js`
- `app/views/camaleon_cms/admin/settings/custom_fields/form.html.erb`
- `app/views/camaleon_cms/admin/media/_render_file_item.html.erb`
- `app/assets/javascripts/camaleon_cms/admin/_i18n.js`
- Specs: `spec/features/admin/post_tag_markup_spec.rb`,
  `spec/features/admin/post_slug_markup_spec.rb`,
  `spec/features/admin/media_manager_param_markup_spec.rb`,
  `spec/features/admin/media_manager_file_markup_spec.rb`,
  `spec/features/admin/post_featured_image_markup_spec.rb`,
  `spec/features/admin/custom_field_group_help_markup_spec.rb`,
  `spec/features/admin/js_translation_value_spec.rb`,
  `spec/requests/security/media_list_file_data_markup_spec.rb` and
  `spec/requests/admin/title_escaping_spec.rb`
- `docs/upgrading-to-2.9.5.md`
- Ecosystem: `docs/ai/ecosystem.md` lists no consumer of `tagEditor`, and no sibling checkout of a
  surveyed member calls it.
