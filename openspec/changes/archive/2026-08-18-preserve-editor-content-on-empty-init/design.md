# Design

## Guard the symptom, not the cause

The blank editor was bisected to #1163 (`PluginRoutes.reload` thread-safety), which shifted
cold-start timing enough to lose the editor's init race in a throttled background tab. The editor
JavaScript is unchanged since 2.9.2 and #1163's thread-safety fix must stay, so the race is guarded
where the symptom lands rather than by reverting the cause. The route/asset boot work in #1272 does
not help here: the edit form loads with routes already drawn, so this is a client-side race, not a
route-draw stall.

## Restore from `defaultValue`

The server always renders the post content into the textarea, and the DOM preserves that initial
value in `textarea.defaultValue` regardless of what blanks the live `value`. So the guard, in
TinyMCE's `init` handler, restores `defaultValue` when the editor came up empty but `defaultValue`
is not empty. It skips Translatable clones (`.translate-item`) and encoded multi-language values
(leading `<!--:`), whose per-locale decoding the Translatable plugin owns, so it can only ever
restore real single-language content and never corrupts an encoded field.

## Testing

The background-tab throttling race is not reproducible in a headless feature spec. The feature spec
instead drives the exact DOM state the race produces -- an empty live value with the server value
still in `defaultValue` -- and asserts the guard refills the editor; it fails without the guard.
