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

## 2. The permalink line

- [x] 2.1 Add `spec/features/admin/post_slug_markup_spec.rb`. A stored slug with an `img` tag must show
  as text. A plain slug must show inside the URL of the post. The Preview link and the View link must
  hold a slug with `$&` as the post stores it. Make sure that the examples of the `img` tag and of
  `$&` fail before the fix.
- [x] 2.2 Set the slug and the URL around it as text in `set_slug` of `_post.js` (D1). Build the Preview
  link and the View link from the same parts of the URL, with no `replace` call.
- [x] 2.3 Give the change in `docs/upgrading-to-2.9.5.md`.
- [x] 2.4 Add two examples to `spec/features/admin/post_slug_markup_spec.rb`. After a draft save, the
  Preview link must hold a slug with `&draft_id=` as the post stores it. It must also keep a param
  that other code added after the draft id. Make sure that the example of the slug fails before the
  fix.
- [x] 2.5 Write the draft id into the last `draft_id` param of the Preview link in
  `set_preview_draft_id` of `_post.js`.

## 3. The media manager

- [x] 3.1 Add `spec/features/admin/media_manager_param_markup_spec.rb`. A `folder` param and a
  `dimension` param with an `img` tag must show as text. A parent folder with an `img` tag or a quote
  must show as the text of its link. A plain folder path must keep its links. Make sure that each
  example fails before the fix, except the example of the plain path.
- [x] 3.2 Build the breadcrumb, the dimension of the details and the editor title from text in
  `_media_manager.js` (D1).
- [x] 3.3 Give the change in `docs/upgrading-to-2.9.5.md`.
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

## 9. Verification and shipping

- [x] 9.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 9.2 Add the CHANGELOG entry, archive this change on the branch
