# Keep script out of the custom-field form

## Why

After a failed save, the custom-fields partial of an admin form shows the submitted field values
again, so the admin keeps what they entered. The partial also read those values from the params of a
GET request. So a link such as `posts/new?field_options[0][photo][values][]=<value>` put its value
into the form of the admin who opened it.

The image field shows a preview of its URL. `cama_custom_field_image_changed` put the URL into the
HTML of the preview. A value with a quote and a tag added that tag to the form, and the event handler
of the tag ran. The form calls that function for each value that it shows: a value of a link and a
stored value. The save of an image value refuses only a script URL, so an author who is not an
administrator can store such a value.

The editor fields of the form also showed the values of a link. Their TinyMCE configuration allows
`div`, `span` and `a` with any attribute.

### Triage verdict: legit

A probe opened the form of a new post through a GET link. The image value of the link held an `img`
tag with an `onerror` handler, and the handler ran. `spec/requests/security/custom_field_form_get_values_spec.rb` and
`spec/features/admin/custom_field_image_preview_spec.rb` fail before the fix.

## What Changes

- The partial shows the submitted values only for a request that is not a GET. A failed save is a
  POST, PATCH or PUT request. A GET request shows the values of the record.
- `cama_custom_field_image_changed` sets the URL as the `href` of the link and the `src` of the image
  of the preview. It does not parse the URL as HTML.
- `spec/requests/security/xss_vulnerabilities_spec.rb` sends its submitted values in a POST request.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the GET change.

## Capabilities

### New Capabilities

- `custom-field-form-value-safety`: which request shows submitted values in the custom-field form,
  and how the image preview shows its URL.

### Modified Capabilities

None.

## Impact

- `app/views/camaleon_cms/admin/settings/custom_fields/_render.html.erb`
- `app/assets/javascripts/camaleon_cms/admin/_custom_fields.js`
- Specs: the two reproductions, and the POST request of `spec/requests/security/xss_vulnerabilities_spec.rb`.
- `docs/upgrading-to-2.9.5.md`
- Ecosystem: `docs/ai/ecosystem.md` lists `camaleon-post-clone` as a consumer of the partial.
  `camaleon-spree` renders the partial too. So do the themes of `camaleon_website`, and its
  `camaleon_notification` and `store` plugins. No sibling checkout of a surveyed member links to a
  form with `field_options` values, and none calls the two image preview functions.
