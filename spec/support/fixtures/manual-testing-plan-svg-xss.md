# Manual Testing Plan — SVG XSS Fix (PR #1199)

## Prerequisites

Start the dummy app:
```bash
(cd spec/dummy && bin/rails s)
```

Sign in as an admin user with media permissions.

---

### 1. Upload pipeline — dangerous SVGs (should ALL be rejected)

Use the file fixtures in this directory:

| Test case | Fixture | Expected |
|---|---|---|
| `<script>` tag | `unsafe-test-xss.svg` | Rejected |
| `onbegin` animation | `unsafe-svg-onbegin.svg` | Rejected |
| Entity-encoded `javascript:` | `svg-javascript-encoded.svg` | Rejected |
| DTD entity | `svg-dtd-entity.svg` | Rejected |

Or test via `curl` (requires session cookie from browser login):

```bash
curl -v -c /tmp/cookies -b /tmp/cookies \
  -F "file_upload=@spec/support/fixtures/unsafe-test-xss.svg;type=image/svg+xml" \
  http://localhost:3000/admin/media/upload
```

Additional inline test cases (create on the fly):

| Test case | Key attribute | Expected |
|---|---|---|
| `onclick` handler | `<rect onclick="alert(1)"/>` | Rejected |
| `onpointerdown` | `<rect onpointerdown="alert(1)"/>` | Rejected |
| `javascript:` in href | `<a href="javascript:alert(1)">` | Rejected |
| `foreignObject` + `iframe` | `<foreignObject><iframe src="...">` | Rejected |
| `data:` URI | `<a href="data:text/html,...">` | Rejected |
| `<animate>` with `onbegin` | `<animate onbegin="alert(1)">` | Rejected |
| Binary garbage | Upload `.svg` with raw bytes | Rejected |

---

### 2. Upload pipeline — safe SVGs (should be accepted)

| Test case | Expected |
|---|---|
| Clean SVG (`svg-safe.svg`) | Uploaded successfully |
| SVG with `<desc>`, `<title>`, `<metadata>` | Uploaded successfully |
| SVG with `<style>` block (no JS) | Uploaded successfully |

---

### 3. Security headers on served SVGs

```bash
# Upload a safe SVG first, then:
curl -v http://localhost:3000/media/<site_id>/<filename>.svg
```

Expected headers:
```
X-Content-Type-Options: nosniff
Content-Security-Policy: script-src 'none'
```

Non-SVG files are unaffected:
```bash
curl -v http://localhost:3000/media/<site_id>/<image>.png
```
Expected: no `Content-Security-Policy` header.

---

### 4. Non-SVG regression

| Test case | Expected |
|---|---|
| Upload PNG/JPEG | Normal upload |
| Upload `unsafe-html-onclick.html` | Rejected by regex (non-SVG safety net) |
| Upload `unsafe-html-onclick.html` as `.jpg` via format param swap | Still rejected by regex on raw bytes |

---

### 5. XXE attempt

Upload an SVG containing an external entity reference:
```xml
<?xml version="1.0"?>
<!DOCTYPE svg [
  <!ENTITY xxe SYSTEM "file:///etc/hostname">
]>
<svg xmlns="http://www.w3.org/2000/svg">&xxe;</svg>
```

Expected: upload rejected (parse fails or `nonet` prevents access). No file read occurs on the server.
