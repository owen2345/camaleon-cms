# Design

## D1. Rejection, not transformation

An untrusted author's value is either stored exactly as written or refused with an error naming the
field — never rewritten. Sanitizing silently mutates content (data loss the author discovers later)
and invites try-until-it-slips-through probing of the sanitizer; rejection is loud, keeps
stored-equals-authored, and lets the frontend render verbatim. This is the model the upload scanner
and the contact-form gate already use; this change brings custom fields under it (and its sibling
change brings post content under it).

## D2. One gate at the model, positions decide the check

`CustomFieldsRelationship` is the single row every custom-field save writes through
(`set_field_values`, `set_field_value`, admin controllers, plugin code), so the validation cannot be
bypassed by a forgotten controller. The check follows the rendered position, exactly like the
contact-form gate: markup positions (`editor`) get the scrub-comparison against the post-content
allowlist; URI positions (`url`, `image`, `audio`, `video`, `file`) get the scheme check (a
`javascript:` href executes regardless of escaping); escaped element-content positions (text boxes,
selects, dates…) carry no gate because the renderer's ERB escaping already neutralizes markup there.

## D3. Trust mirrors post content; fail closed

Admins always pass ("admins have all the permissions"). For a post's fields the saver may hold
`post_content_unfiltered_html` on the post type — the same capability that governs the post body, so
a role trusted to script the body may script the body's fields. Fields of non-post objects (users,
categories, widgets, menus, site) have no matching scoped capability and are admin-only. A missing
request context (jobs, rake, console) fails closed — the gate applies, benign values still save —
with `unfiltered_value!` as the explicit pipeline opt-out (reader + bang, no writer).

## D4. Detector shared and in parity with cama_contact_form

`CamaleonCms::UnsafeMarkup` ports the gem's gate: one parse (`Loofah.html5_fragment` when
available), baseline reserialization, scrub with a `PermitScrubber` admitting `data-*`/`aria-*` by
shape, compare — plus the guards the comparison cannot see (markup the parser drops, a tag left
open, a translation marker inside a tag, non-marker comments, oversized values). The gem should
eventually consume this module instead of its private copy; until then, keep the two in parity when
either changes.

## D5. Refusal UX

Model validation raises `RecordInvalid` from the `create!` save paths, after the parent object saved.
`AdminController` rescues that (this model only) into a flash error carrying the field slug and
redirects back; the parent's own attributes stay saved, the refused value rows roll back inside
`set_field_values`' transaction. Post content itself is validated on the parent, so its refusal
re-renders the form with inline errors (sibling change).

## D6. Testing

`spec/models/custom_field_value_rejection_spec.rb`: editor script refused for an untrusted author
(nothing stored) and stored verbatim for an admin and for a granted non-admin role; benign rich text
stored unchanged; no-context saves fail closed for dangerous values and pass for benign; opt-out
stores verbatim; `javascript:` URL refused / ordinary URL stored; escaped positions carry no gate.
`spec/requests/security/custom_field_value_rejection_spec.rb`: the real posts controller path
refuses the script value with a flash error and stores benign rich text. Both fail on unfixed code
(stash-verified).
