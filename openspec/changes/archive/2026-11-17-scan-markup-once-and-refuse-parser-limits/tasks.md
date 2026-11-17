# Tasks

## 1. One walk of the elements

- [x] 1.1 Add the examples of "The markup gate reads each element once" to
  `spec/lib/camaleon_cms/unsafe_markup_spec.rb`. A fragment-wide `css` search raises in them.
- [x] 1.2 Replace the three `fragment.css` searches with one walk of the elements (D1, D2). The
  examples of task 1.1 pass.

## 2. The parser limits

- [x] 2.1 Add the examples of "The markup gate refuses a value that its parser cannot read" to
  `spec/lib/camaleon_cms/unsafe_markup_spec.rb` and `spec/models/post_content_rejection_spec.rb`.
  Make sure that they fail with `ArgumentError` before task 2.2.
- [x] 2.2 Catch `ArgumentError` in `parse`, and refuse the value in `unsafe_html?` (D3). The examples
  of task 2.1 pass.
