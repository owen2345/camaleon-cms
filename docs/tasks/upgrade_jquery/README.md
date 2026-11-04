# Upgrade jQuery

## Status: Complete (core migration)

## Summary

Migrated jQuery 2.2.4 → 3.7.1 and jQuery UI 1.11.4 → 1.13.3 across the Camaleon CMS codebase. All critical breaking changes in custom (non-vendored) code have been fixed.

## Changes Made

### 1. jQuery version switch (5 files)
`//= require jquery2` → `//= require jquery3` in:
- `app/assets/javascripts/camaleon_cms/admin/admin-basic-manifest.js`
- `app/assets/javascripts/camaleon_cms/admin/admin-manifest.js`
- `app/apps/themes/camaleon_first/assets/js/main.js`
- `app/apps/themes/default/assets/js/main.js`
- `app/apps/themes/new/assets/js/main.js`

### 2. jQuery UI upgrade (1 file)
- `app/assets/javascripts/camaleon_cms/admin/_jquery-ui.min.js` — replaced with v1.13.3 from CDN

### 3. Breaking change fixes (5 files, 18 edits)

| Deprecated API | Replacement | File(s) | Count |
|---|---|---|---|
| `.error()` on jqXHR | `.fail()` | `uploader/_media_manager.js` | 3 |
| `.load()` event shorthand | `.on('load', fn)` | `uploader/_media_manager.js` | 1 |
| `.bind(event, fn)` | `.on(event, fn)` | `uploader/_media_manager.js`, `_custom_fields.js`, `_translator.js` | 6 |
| `.unbind()` | `.off()` | `_custom_fields.js` | 1 |
| `.delegate(sel, evt, fn)` | `.on(evt, sel, fn)` | `_custom_fields.js` | 1 |
| `.scroll(fn)`, `.resize(fn)` | `.on('scroll', fn)`, `.on('resize', fn)` | `_post.js`, `uploader/_media_manager.js` | 3 |
| `$.parseJSON(str)` | `JSON.parse(str)` | `_custom_fields.js`, `_post.js` | 2 |
| `$.trim(str)` | `str.trim()` | `_libraries.js` | 1 |

## Not Changed (deferred)

These vendored plugins still use deprecated jQuery APIs or need attention:

| Plugin | Version | Status |
|---|---|---|
| jQuery Nestable | 2012 | Compatible with jQuery 3 — no changes needed |
| jQuery Sieve | 0.3.0 | Compatible with jQuery 3 — uses `.on()` already |
| Bootstrap Colorpicker | 2012 | Compatible with jQuery 3 — no changes needed |
| AdminLTE `lte/app.js` | — | Uses `.selector` property (removed in jQuery 3) — separate issue |

## Resolved Vendored Plugins

| Plugin | Change | Details |
|---|---|---|
| jQuery tagEditor | Updated 1.0.16 → 1.0.21 + patched | Replaced with upstream v1.0.21. Patched `.bind()` → `.on()`, all `$.trim()` → `.trim()` |
| jQuery Form | Updated 3.51.0 → 4.3.0 + patched | Replaced with upstream v4.3.0. Patched `$.isFunction()` → `typeof`, `$.isArray()` → `Array.isArray()`, `$.trim()` → `.trim()` |
| jQuery Upload File | Patched in place (4.0.8) | Replaced `.unbind("click")` → `.off("click")`, `jQuery.type(a)` → `typeof a`, `e.type(a)` → `typeof a` |
| jQuery Tags Input | Removed from manifest | `//= require` directive removed from `admin-manifest.js` — plugin was loaded but never called (project uses tagEditor instead) |

## Recommended Follow-up

1. Add `jquery-migrate` 3.x plugin during development to catch remaining deprecation warnings
2. Test all admin panel workflows in browser
3. Address AdminLTE `.selector` property usage (separate from jQuery API deprecation)
4. Consider adding ESLint `no-deprecated-jquery` rule to prevent future regressions

## Branch

`feature/upgrade-jquery`
