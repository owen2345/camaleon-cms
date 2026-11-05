# Design

## Context

`CamaleonCms::AdminController` rescues `ActiveRecord::RecordInvalid` of a custom-field value or a
post type, and `CamaleonCms::Metas::InvalidContainer`. Each handler set a flash and redirected back.
A redirect is the right answer for a submitted form. An XHR follows a redirect on its own, and the
script gets the page that the redirect led to, never the message.

The XHR callers of an admin save that can be refused, surveyed in Camaleon and in the sibling
plugins and themes:

- The nav menu item settings modal (`nav_menu.js`). It read only a success.
- The draft save of the post editor (`_post.js`). It reads a non-2xx answer as a failed draft
  save, and a page that is not JSON too.
- `camaleon_admin_ajax` submits each `cama_ajax_request` form by XHR, with the `cama_ajax_request`
  param, and shows the page that a redirect leads to. The flash shows on that page.
- `camaleon_editor` posts its grid templates by XHR. That save renders its errors in the form and
  raises no refusal.
- The settings forms of the plugins that pass custom-field values are submitted forms.

## Decisions

**D1. The shared handlers answer by the kind of the request.** A private `refuse_admin_save`
answers for both handlers. Rejected: a rescue in `save_custom_settings` only. The draft save and
any plugin that posts by XHR keep an answer that no script can read.

**D2. An XHR without `cama_ajax_request` gets the 422.** `admin_logged_actions` already tells the
two kinds of XHR apart with the same test. `camaleon_admin_ajax` adds the param to each form that
it submits and to each link that it follows.

**D3. The body is the message as plain text.** The modal shows the text. The draft script reads a
non-2xx answer as a failed save, whatever the body. Rejected: a JSON body such as
`{ error: [...] }`. The draft script reads that shape only on a 200, and the modal would need a
reader for it.

**D4. The status is the number `422`.** Rack 3.1 and later print a deprecation warning for
`:unprocessable_entity` on Rails 7.1, which gives the symbol to Rack as it is. Rails 7.2.3 and 8.1
give Rack the new symbol in its place. `:unprocessable_content` exists only from Rack 3.1, so a host app on an
earlier Rack would get an `ArgumentError`. The number holds across the support range. The cop
`Rails/HttpStatus` would change it to the new symbol, so a `rubocop:disable` comment stops it at
that line.

**D5. The 422 sets no flash.** A flash would show on the next page that the user opens.

**D6. The modal shows a plain-text 422 in place, as text.** A refusal can quote user input. Any
other failure shows a generic message, `msg.save_failed` of the admin JavaScript locale. A 422 of
another type is one: an error page, for example of a CSRF failure. The spinner
comes down on each outcome: before, a failed request left it up. A success keeps its answer: a
non-empty body is alerted, and the modal closes.

**D7. The draft save keeps its message.** Before, the script got the redirected page and could not
read it as JSON. Now it gets a 422. Both reach its failure handler, which says that the draft could
not be saved. A draft save that shows the refusal itself is a change of its own.
