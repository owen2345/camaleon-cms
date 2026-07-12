## Context

The current SVG upload security relies on a regex-based denylist (`SUSPICIOUS_PATTERNS` / `UNSAFE_EVENT_PATTERNS` in `ContentSecurity`) that scans raw file bytes for dangerous patterns. This has fundamental weaknesses:

1. Entity encoding bypasses byte-level scans (`javascript&#58;` does not match `/javascript:/i`)
2. XML DTD entity substitution bypasses all patterns (`&x;` resolves to `<script>` after parsing)
3. The denylist is inherently incomplete — missing event handlers (pointer, animation, transition events) and a concatenation bug (`onunloadonsubmit`) leave gaps
4. Even if scanning catches some attacks, successfully uploaded SVGs are served from `public/media/` as static files with `Content-Type: image/svg+xml` and no security headers, rendering inline in the site origin

The regex patterns are duplicated in `runtime_uploader_concern.rb` and `uploader_helper.rb`, extracted to `lib/camaleon_cms/content_security.rb` in a prior change.

## Goals / Non-Goals

**Goals:**
- Replace the regex-based content scan for SVGs with Nokogiri XML parse-based detection that rejects dangerous SVGs before storage
- Add a Rack middleware to serve SVG files under `/media/` with `X-Content-Type-Options: nosniff` and `Content-Security-Policy: script-src 'none'` headers
- Remove the now-redundant `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` for SVGs
- Keep regex-based scanning as a safety net for non-SVG files

**Non-Goals:**
- No changes to non-SVG upload handling
- No changes to the upload storage path or file naming conventions
- No changes to thumbnail generation or image processing
- No breaking API changes

## Decisions

**Decision 1: Nokogiri XML parse-based SVG content rejection**

Parse uploaded SVG files with Nokogiri and reject the upload if dangerous content is detected. Nokogiri is already available in the Rails dependency tree (required by ActionPack). Rejection is preferred over sanitization because:
- Simpler implementation — detect and reject, no XML reconstruction
- Clearer security boundary — dangerous content never reaches storage
- User can re-upload a clean SVG; no legitimate reason to have event handlers or scripts in a CMS media upload

| Alternative | Verdict |
|---|---|
| Nokogiri XML parse + reject if dangerous | **Chosen** — Nokogiri resolves all entities automatically, making entity-based bypasses impossible; simpler and safer than sanitization |
| Nokogiri XML parse + strip + store sanitized | Rejected — more complex (XML reconstruction), risk of content corruption, no benefit over rejection |
| Loofah HTML5 sanitizer | Rejected — Loofah targets HTML, not SVG; SVG-specific elements and namespaces would be lost |
| Regex denylist expansion | Rejected — fundamentally incomplete; new bypasses emerge as web APIs evolve |

Detection logic:
1. Parse the SVG with `Nokogiri::XML(content)` — this resolves DTD entities automatically
2. Check for `<script>` elements → reject
3. Check for attributes starting with `on` (event handlers) → reject
4. Check for `href` and `xlink:href` attributes with `javascript:` URIs → reject
5. If no dangerous content found, pass through to normal upload processing

**Decision 2: Rack middleware for SVG serving headers**

Insert a middleware before `ActionDispatch::Static` that adds security headers to SVG responses under `/media/`.

| Alternative | Verdict |
|---|---|
| Rack middleware | **Chosen** — no file movement needed, existing URLs preserved, adds defense-in-depth |
| Controller route catch-all | Rejected — requires moving SVGs out of `public/` or complex routing; would break existing URLs |
| Nginx/Apache config | Rejected — Rails should own its security; dev/test environments also need protection |

Middleware behavior:
- Intercepts all GET requests where `PATH_INFO` matches `/media/.*\.svg\z`
- Adds `X-Content-Type-Options: nosniff`
- Adds `Content-Security-Policy: script-src 'none'`
- Leaves response body unchanged (SVG still renders visually, but scripts are blocked)

`Content-Security-Policy: script-src 'none'` is preferred over `Content-Disposition: attachment` because it does not break SVG display when referenced from `<img>` tags or when navigating directly to the URL — the SVG renders normally, only JavaScript execution is blocked.

**Decision 3: Remove regex-based SVG scanning**

Since Nokogiri-based detection resolves all entities and rejects dangerous content before storage, the regex-based `file_content_unsafe?` scan is redundant for SVG files. The `file_content_unsafe?` method will skip SVG files entirely (detected by `.svg` extension or `image/svg+xml` content type). The method is retained for non-SVG files as a safety net.

The `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` constants in `ContentSecurity` can be removed or deprecated.

## Risks / Trade-offs

- **[Nokogiri performance]** → XML parsing is slower than raw byte scanning. For typical SVGs (10-100KB), the overhead is negligible. The `filesystem_max_size` setting (default 100MB) bounds worst-case impact.
- **[XML parsing errors]** → Malformed SVG might fail to parse. Mitigation: wrap in a rescue block; if parsing fails, reject the upload with a clear error message rather than accepting potentially ambiguous content.
- **[Legitimate SVGs rejected for false positives]** → A clean SVG that happens to contain `javascript:` in benign text content (e.g., a blog post rendered as SVG) would be rejected. Mitigation: extremely unlikely in practice; `javascript:` in SVG text content is vanishingly rare in CMS media uploads.
- **[Middleware ordering]** → The middleware must be positioned before `ActionDispatch::Static` to intercept static file responses. Mitigation: use `insert_before` in the engine initializer, which reliably positions middleware in Rails 8.x.
- **[CSP scope]** → `Content-Security-Policy: script-src 'none'` only affects the SVG document itself. It does not protect against clickjacking or other attacks on the parent page. Mitigation: this is intentional — the middleware's purpose is SVG XSS prevention, not general security hardening.
