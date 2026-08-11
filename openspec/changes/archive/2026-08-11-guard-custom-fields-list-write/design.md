# Design

## D1. Guard the write by verb, keep the render on GET

`#list` conflates a read (render the custom-fields partial for a post) with a write (persist the post's
categories). The write is state-changing, so it belongs behind CSRF protection, which Rails applies to
non-GET verbs only. Guarding it with `unless request.get?` — and adding POST to the route — puts the
write behind `protect_from_forgery` while leaving the GET render untouched.

The write is not removed outright: an existing spec documents that the endpoint updates a post's
categories and renders the field groups for them, and the (currently disabled) post-form JS that drives
it is intended to be re-enabled. Keeping the capability but requiring POST preserves that intent
securely — a re-enabled caller must POST, and the admin JS already carries the CSRF token on non-GET
requests via jquery_ujs.

## D2. Categories are authoritatively saved by the main post form

Post categories are persisted on the main save (`PostsController` builds `data_categories` from
`params[:categories]`), so the `#list` write is a convenience/preview path, not the system of record.
That is why guarding it does not affect saving categories through the normal post-edit flow, and why
the only active `#list` caller — the category-panel reload, which passes no `post_id` and so takes the
render-only `else` branch — is unaffected.

## D3. Why not `request.xhr?`

An `unless request.xhr?` guard would also block a top-level-navigation CSRF while keeping the endpoint
on GET, but it leans on a header (`X-Requested-With`) as an ad-hoc CSRF signal. Requiring a non-GET verb
routes the write through the framework's real CSRF machinery (`protect_from_forgery with: :exception`),
which is the mechanism the rest of the admin relies on, so it is preferred over an XHR sniff.
