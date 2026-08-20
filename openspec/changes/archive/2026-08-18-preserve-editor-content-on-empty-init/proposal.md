# Preserve post editor content when TinyMCE initializes empty

## Why

On a cold server, opening the post edit form in a throttled background browser tab can bring up
TinyMCE with an empty body even though the server rendered the post content into the textarea: the
content field's live value is blanked before TinyMCE reads it, and a save then overwrites the post
with the empty body. A plain (foreground) refresh fixes it, so the content is never lost
server-side. Bisected to #1163 (`PluginRoutes.reload` thread-safety), which shifted cold-start
timing enough to lose the editor's init race; the editor JavaScript itself is unchanged since 2.9.2.

## What Changes

- The admin TinyMCE editor restores the server-rendered content from the textarea's `defaultValue`
  when it initializes empty but the server value is not empty. It never overwrites Translatable
  clones or encoded multi-language values, whose per-locale decoding the Translatable plugin owns.

## Impact

- Affected capability: `post-editor-content-resilience` (new)
- Affected code: `app/assets/javascripts/camaleon_cms/admin/_data.js`
