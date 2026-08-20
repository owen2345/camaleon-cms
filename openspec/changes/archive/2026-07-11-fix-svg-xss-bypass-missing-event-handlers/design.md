## Context

`UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` are currently defined identically in two files:

- `app/helpers/camaleon_cms/uploader_helper.rb` (lines 8–14 and 16–24)
- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` (lines 9–15 and 17–25)

Both lists are missing `onbegin`, `onend`, and `onrepeat` — SVG animation event handlers that execute JavaScript. An SVG using `<animate onbegin="alert(1)"/>` bypasses the filter because none of the existing regexes match those attribute names.

## Goals / Non-Goals

**Goals:**
- Block `onbegin`, `onend`, `onrepeat` in uploaded SVG files before storage.
- Eliminate the code duplication so future additions touch one place.
- Add test coverage for SVG animation event handlers.

**Non-Goals:**
- No changes to the thumbnail/resize pipeline or the uploader storage layer.
- No changes to existing event handler patterns (they're already correct).
- No changes to how `file_content_unsafe?` reads or rewinds files.

## Decisions

**Decision 1: Extract shared patterns into `CamaleonCms::ContentSecurity` module.**

| Alternative | Verdict |
|---|---|
| Extract to `lib/camaleon_cms/content_security.rb` | **Chosen** — clear namespace, auto-loaded by Rails, no existing home is a better fit |
| Keep inline, add note to update both files | Rejected — proven failure mode (this PR is the evidence) |
| Extract to one of the existing files, include from the other | Rejected — neither `helper` nor `controller/concern` is the right namespace for a pure data module |

The module will define both `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` as frozen constants, identical in content to the current lists plus the three additions.

**Decision 2: Add `onbegin`, `onend`, `onrepeat` inline with `onblur`/`oncanplay` ordering.**

Alphabetical insertion keeps the list navigable. The resulting section:

```
onbegin onblur oncanplay ...
onend onerror ...
onrepeat onresize ...
```

**Decision 3: No regex refactoring.**

The existing regex builder — `/#{pattern}\w*\s*=/i` — is kept unchanged. The `\w*` allows for vendor-prefixed variants (e.g., `onbeginSomething=`) and `\s*=` catches the attribute-value separator. This matches the existing approach.

## Risks / Trade-offs

- **[False positive risk]** Adding three tokens to a blocklist has negligible risk — `onbegin`, `onend`, and `onrepeat` are not legitimate content attributes in any CMS workflow.
- **[Missing future handlers]** A blocklist approach is inherently incomplete. A future SVG spec addition or browser extension could introduce new executable attributes. Mitigation: the centralized module makes it easier to audit and update.
- **[URL-served SVGs]** The filter only applies to uploaded content. SVGs served from external URLs that the CMS links to (but doesn't store) are out of scope.
