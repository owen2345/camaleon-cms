# Tasks

## 1. The tag editor

- [x] 1.1 Add `spec/features/admin/post_tag_markup_spec.rb`, with the examples below. Make sure that
  each example fails before the fix, except the example of the normal use.
  - A stored tag name with `img` markup and the `tags` param of a GET link must show as text.
  - The text input of an open tag must hold a name with a quote.
  - The normal use of the editor must still work.
  - A name with markup that the admin adds must show as text.
  - A name that the admin types again must replace its tag.
  - The `beforeTagDelete` callback must get a name as text.
- [x] 1.2 Set and read the name of a tag as text in the tag editor (D1, D2).
- [x] 1.3 Give the text form of a tag name in `docs/upgrading-to-2.9.5.md`.
- [x] 1.4 Add an example to `spec/features/admin/post_tag_markup_spec.rb`. For an open tag, the
  `beforeTagDelete` callback must get the name that the tag had when the admin opened it. A new tag
  must give no call. Make sure that the example fails before the fix.
- [x] 1.5 Give `beforeTagDelete` the stored name of an open tag in the right-click delete (D2). Skip
  the call for a new tag.
- [x] 1.6 Add an example to `spec/features/admin/post_tag_markup_spec.rb`. A right click must delete
  a new tag with no text, and an open tag whose text the admin removed, with no error. Make sure
  that the example fails before the fix.
- [x] 1.7 Leave a tag that the right-click delete removes in the blur handler of the tag editor
  (D13).
- [x] 1.8 Add an example to `spec/features/admin/post_tag_markup_spec.rb`. The `beforeTagSave`
  callback must get the old name of a tag as text. Make sure that the example fails when `old_tag`
  comes from `.html()`.
- [x] 1.9 Remove the closed tags with a given name in one function, `remove_duplicates`, of the tag
  editor. `split_cleanup` and the blur handler call it.
- [x] 1.10 Start the `beforeTagDelete` example on the list of posts. It needs only the tag editor
  plugin, which the admin layout loads.
- [x] 1.11 Add an example to `spec/features/admin/post_tag_markup_spec.rb`. A right click on an open
  tag with the name of another tag as its text must delete only the open tag. The `beforeTagSave`
  callback must get no call. Make sure that the example fails before the fix.

## 2. The permalink line

- [x] 2.1 Add `spec/features/admin/post_slug_markup_spec.rb`. A stored slug with an `img` tag must show
  as text. A plain slug must show inside the URL of the post. The Preview link and the View link must
  hold a slug with `$&` as the post stores it. Make sure that the examples of the `img` tag and of
  `$&` fail before the fix.
- [x] 2.2 Set the slug and the URL around it as text in `set_slug` of `_post.js` (D1). Build the Preview
  link and the View link from the same parts of the URL, with no `replace` call.
- [x] 2.3 Give the text form of the slug in `docs/upgrading-to-2.9.5.md`.
- [x] 2.4 Add two examples to `spec/features/admin/post_slug_markup_spec.rb`. After a draft save, the
  Preview link must hold a slug with `&draft_id=` as the post stores it. It must also keep a param
  that other code added after the draft id. Make sure that the example of the slug fails before the
  fix.
- [x] 2.5 Write the draft id into the last `draft_id` param of the Preview link in
  `set_preview_draft_id` of `_post.js`.
- [x] 2.6 Add two examples to `spec/features/admin/post_slug_markup_spec.rb`. The Preview link and
  the View link must hold a slug with `?`, `#` and a space in its percent-encoded form. They must
  hold a slug with `+ , ; = : @` as it is. Make sure that the first example fails before the fix.
- [x] 2.7 Encode the slug in `post_url` of `_post.js` (D12).
- [x] 2.8 Give the form of the links in `docs/upgrading-to-2.9.5.md`.
- [x] 2.9 Add two examples to `spec/features/admin/post_slug_markup_spec.rb`. The line and the links
  must hold a URL with no placeholder as it is. With no URL for its language, the form must start
  and show the slug alone. Make sure that the examples fail before the fix.
- [x] 2.10 Keep a URL with no placeholder, and start the form with no URL, in `_post.js` (D15).
- [x] 2.11 Add an example to `spec/features/admin/post_slug_markup_spec.rb`. After Edit and Cancel,
  the line must show the same URL. After Edit and Accept, the line must show one URL with the new
  slug. Make sure that the example fails when `set_slug` does not empty the line.
- [x] 2.12 Remove the Edit link of the permalink line for a URL with no placeholder in `_post.js`
  (D15). Add its expectation to the example of that URL. Make sure that the example fails before
  the fix.

## 3. The media manager

- [x] 3.1 Add `spec/features/admin/media_manager_param_markup_spec.rb`. A `folder` param and a
  `dimension` param with an `img` tag must show as text. A parent folder with an `img` tag or a quote
  must show as the text of its link. A plain folder path must keep its links. Make sure that each
  example fails before the fix, except the example of the plain path.
- [x] 3.2 Build the breadcrumb, the dimension of the details and the editor title from text in
  `_media_manager.js` (D1).
- [x] 3.3 Give the text form of the `folder` param and of the `dimension` param in
  `docs/upgrading-to-2.9.5.md`.
- [x] 3.4 Add `spec/features/admin/media_manager_file_markup_spec.rb`. A name and a URL with `img`
  markup must show as text in the details of a file and in the image editor. The message of a failed
  image request must show the URL as text. Make sure that the examples fail before the fix.
- [x] 3.5 Set the name and the URL of a file as text and as attribute values in `_media_manager.js`
  (D3).
- [x] 3.6 Give the name and the URL of a file in `docs/upgrading-to-2.9.5.md`.
- [x] 3.7 Encode text for an HTML string with one function, `cama_escape_html` in `_modal.js`. Call
  it in the media manager and in the post form (D4).
- [x] 3.8 Add an example to `spec/features/admin/media_manager_file_markup_spec.rb`. The message of
  a failed image request must show a URL with `$&` as text. Make sure that the example fails before
  the fix.
- [x] 3.9 Set the URL as the text of an element in the message of a failed image request (D5).
- [x] 3.10 Add two examples to `spec/features/admin/media_manager_param_markup_spec.rb`. The image
  editor must start for a `dimension` param with no digit, and for a param whose height has no
  digit. Make sure that the examples fail before the fix.
- [x] 3.11 Read a part of the dimension with no digit as an empty part in `_media_manager.js`
  (D11).
- [x] 3.12 Add `spec/features/admin/media_list_file_data_markup_spec.rb`. With
  `escape_html_entities_in_json` off, a folder path with a closing `textarea` tag and an `img` tag
  must add no element to the list. Make sure that the example fails before the fix.
- [x] 3.13 Write the JSON of a file with the HTML escape in `media/_render_file_item.html.erb`
  (D14).
- [x] 3.14 Give the list in `docs/upgrading-to-2.9.5.md`.

## 4. The Featured Image panel

- [x] 4.1 Add `spec/features/admin/post_featured_image_markup_spec.rb`. The Featured Image panel of
  the post form must show the name of a picked file with `img` markup as text. Make sure that the
  example fails before the fix.
- [x] 4.2 Set the name of the picked file as text in `cama_upload_feature_image` of `_post.js` (D6).
- [x] 4.3 Give the Featured Image panel in `docs/upgrading-to-2.9.5.md`.

## 5. The Upload Image link

- [x] 5.1 Add an example to `spec/features/admin/post_featured_image_markup_spec.rb`. The file picker
  must get a post type option with a quote as text, and the script after the quote must not run.
  Make sure that the example fails before the fix.
- [x] 5.2 Hold the three image options of the post type in `data-` attributes of the link in
  `posts/_sidebar.html.erb`. Read them in its handler (D7).
- [x] 5.3 Give the link in `docs/upgrading-to-2.9.5.md`.

## 6. The custom field group form

- [x] 6.1 Add `spec/features/admin/custom_field_group_help_markup_spec.rb`. The help of a category
  with `img` markup in its name must show as text. The help of a post type must show its name as the
  author wrote it. Make sure that the example of the category fails before the fix.
- [x] 6.2 Add examples to `spec/requests/admin/title_escaping_spec.rb`. The `data-help` attribute of
  each option of a post type, and of a post, must read the name literally. Make sure that the
  examples fail before the fix.
- [x] 6.3 Set the help of the selected option as text in `custom_fields_form.js` (D8).
- [x] 6.4 Give the name with one escape in the four `data-help` attributes of `form.html.erb` (D8).
- [x] 6.5 Give the form in `docs/upgrading-to-2.9.5.md`.
- [x] 6.6 Add `spec/features/admin/custom_field_group_field_name_markup_spec.rb`. The title of a
  field panel must show a field name with `img` markup as text after a change of the name input.
  Make sure that the example fails before the fix.
- [x] 6.7 Set the name of a field as text in the title of its panel in `custom_fields_form.js`
  (D17). Give the title in `docs/upgrading-to-2.9.5.md`.
- [x] 6.8 Add two examples to `spec/features/admin/custom_field_group_help_markup_spec.rb`. The help
  of a post with `img` markup in its title must show as text. A placement with no help must remove
  the help of the placement before it. Make sure that the second example fails before the fix.
- [x] 6.9 Remove the help for a selected option with no help in `custom_fields_form.js` (D8).

## 7. The label of an option group

- [x] 7.1 Add `spec/features/admin/front_cache_post_type_markup_spec.rb`. The Front Cache settings
  page must show the name of a post type with `img` markup as the text of a group header. Make sure
  that the example fails before the fix.
- [x] 7.2 Encode the label of an option group in the bundled `_bootstrap-select.js` (D9).
- [x] 7.3 Give the label in `docs/upgrading-to-2.9.5.md`.

## 8. The upload plugin

- [x] 8.1 Add `spec/features/admin/media_upload_file_name_markup_spec.rb`. The plugin must show the
  name of a file with `img` markup as text, in each place of the list below. Make sure that each
  example fails before the fix.
  - The status bar of the media manager.
  - Each message that refuses a file.
  - The status bar of a plugin that sends a form.
  - The status bar that `createProgress` adds.
- [x] 8.2 Set the name of a file as text in the bundled `_jquery.uploadfile.min.js` (D10).
- [x] 8.3 Give the plugin in `docs/upgrading-to-2.9.5.md`.

## 9. The I18n function

- [x] 9.1 Add `spec/features/admin/js_translation_value_spec.rb`. The result of `I18n` must hold a
  value with `$&` as it is, and a value that holds a later placeholder as it is. Make sure that the
  two examples fail before the fix.
- [x] 9.2 Replace the placeholders in one pass in `_i18n.js`, with a function that returns the
  value (D16).
- [x] 9.3 Give the function in `docs/upgrading-to-2.9.5.md`.
- [x] 9.4 Add two examples to `spec/features/admin/js_translation_value_spec.rb`. A translation that
  is not a String must come back as it is. A placeholder that a translation holds twice must get
  its value at both places. Make sure that the first example fails before the fix.
- [x] 9.5 Return a translation that is not a String as it is in `_i18n.js` (D16).

## 10. Verification and shipping

- [x] 10.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 10.2 Add the CHANGELOG entry, archive this change on the branch
