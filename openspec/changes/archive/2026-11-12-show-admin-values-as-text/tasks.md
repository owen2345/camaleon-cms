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
- [x] 1.4 Add an example to `spec/features/admin/post_tag_markup_spec.rb`. The `beforeTagDelete`
  callback must get the name of an open tag with its spaces. Make sure that the example fails
  before the fix.
- [x] 1.5 Give the value of the input of an open tag to `beforeTagDelete` in the right-click delete
  (D2).

## 2. The permalink line

- [x] 2.1 Add `spec/features/admin/post_slug_markup_spec.rb`. A stored slug with an `img` tag must show
  as text. A plain slug must show inside the URL of the post. The Preview link and the View link must
  hold a slug with `$&` as the post stores it. Make sure that the first example and the last example
  fail before the fix.
- [x] 2.2 Set the slug and the URL around it as text in `set_slug` of `_post.js` (D1). Build the Preview
  link and the View link from the same parts of the URL, with no `replace` call.
- [x] 2.3 Give the change in `docs/upgrading-to-2.9.5.md`.
- [x] 2.4 Add an example to `spec/features/admin/post_slug_markup_spec.rb`. After a draft save, the
  Preview link must hold a slug with `draft_id=` as the post stores it. Make sure that the example
  fails before the fix.
- [x] 2.5 Write the draft id at the end of the Preview link in `set_preview_draft_id` of `_post.js`,
  with no `replace` call.

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
- [x] 3.7 Encode text for an HTML string with one function, `cama_escape_html` in `_modal.js`, in the
  media manager and in the post form (D4).
- [x] 3.8 Add `spec/features/admin/post_featured_image_markup_spec.rb`. The Featured Image panel of
  the post form must show the name of a picked file with `img` markup as text. Make sure that the
  example fails before the fix.
- [x] 3.9 Set the name of the picked file as text in `cama_upload_feature_image` of `_post.js` (D3).
- [x] 3.10 Give the Featured Image panel in `docs/upgrading-to-2.9.5.md`.
- [x] 3.11 Add an example to `spec/features/admin/media_manager_file_markup_spec.rb`. The message of
  a failed image request must show a URL with `$&` as text. Make sure that the example fails before
  the fix.
- [x] 3.12 Set the URL as the text of an element in the message of a failed image request (D5).

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Add the CHANGELOG entry, archive this change on the branch
