# Design

## Context

See `proposal.md`, "Why". The custom-fields partial gives the values of a form to
`build_custom_field_group`, which builds each field and calls the render callback of its kind. Two
paths ran script from a value. A GET request put values into the form, and the image preview built
HTML from its URL.

## Goals / Non-Goals

**Goals:**

- A link cannot put field values into an admin form.
- The image preview runs no markup from its URL, for a stored value and for a submitted value.

**Non-Goals:**

- A change to the save of an image value. The save still refuses only a script URL.
- The other params that a form reads on a GET request, such as `categories` in the post sidebar,
  which selects checkboxes by id.

## Decisions

**D1. The partial shows submitted values only for a request that is not a GET.** The admin saves
are POST, PATCH or PUT requests: the create and update actions of the record resources, and the
save routes of `config/routes/admin.rb`. A form that renders again after a failed save renders in
the request of the save. So a GET request has no submitted values to show. A HEAD request needs no
case: Rails sends its answer with no body (`Rack::Head`).

- *Alternative: fix only the image preview.* Rejected: the editor fields show the values of a link
  too, and their TinyMCE configuration allows `div`, `span` and `a` with any attribute.
- *Alternative: the save actions give the submitted values to the partial as a local.* Rejected:
  plugin and theme views render the partial too, for example the product form of `camaleon-spree`.
  A plugin form that renders again after a failed save and gives no local loses the input of
  the admin. One test of the request method covers every form. The test is in the
  `cama_form_field_values` helper, which the partial calls.

**D2. The image preview sets its URL as attribute values.** The URL is a value, not markup. The
preview puts it in the position of an attribute value, as `<%= %>` puts a value in a view. That is
the normal output encoding of the platform, not a transform of the value. So D2 does not change the
remedy rule (`docs/security/permissions.md`). The stored value stays as the author wrote it, and
the link and the image get the whole value.

- *Alternative: refuse an image value with a quote or a tag at save.* Rejected: with a correct
  preview, such a value runs no script, so the save has no reason to refuse it. A check at save also
  does not see the `field_options` value of a GET link.

**D3. The preview keeps the URL scheme as it is.** The save of an image value refuses a script URL
from an author who is not trusted. An administrator can store any value. A role with
`post_content_unfiltered_html` for its post type can store any value in the field values of a post.
After D1, a link cannot put a URL into the form.
