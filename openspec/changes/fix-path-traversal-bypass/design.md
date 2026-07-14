## Context

The #1198 security fix added a `start_with?` prefix guard at 4 sink locations (2 methods × 2 modules) to block arbitrary file reads. The guard was bypassable because `start_with?` operates on the raw string while `File.open` resolves `..` segments. An attacker can traverse outside allowed directories by prepending an allowed root before `../` segments (e.g., `/app/public/../config/secrets.yml`).

A second bypass path exists in `cama_tmp_upload`'s HTTP branch where a URL containing the site URL as a substring is converted to a local filesystem path via string substitution. This path is also not canonicalized and preserves `../` segments.

Third-party plugins call `upload_file` and `cama_tmp_upload` as public API. Every guard must be independently robust.

## Goals / Non-Goals

**Goals:**
- Fix the `..` bypass at all 4 sink guards by canonicalizing paths before prefix validation
- Fix the `crop_url` URL-to-path substitution to use host comparison and canonicalization
- Add path traversal detection to `UserUrlValidator` as defense-in-depth
- Fix `data:` URI being blocked by `UserUrlValidator`
- Use env-var for validation skip (default: validate everywhere)

**Non-Goals:**
- Not redesigning the full upload pipeline
- Not adding symlink-resolution (`File.realpath`) — `File.expand_path` is sufficient for the `..` bypass
- Not adding URL decoding to path validation — URL decoding is the caller's responsibility

## Decisions

### Decision 1: Canonicalize with `File.expand_path` at all 4 sink guards

Replace the raw `start_with?` prefix check with `File.expand_path` + prefix check at all 4 locations.

**Before:**
```ruby
if uploaded_io.is_a?(String)
  allowed_prefixes = [Rails.public_path.to_s, Dir.tmpdir]
  return { error: 'Invalid file path' } unless allowed_prefixes.any? { |p| uploaded_io.start_with?(p) }
end
```

**After:**
```ruby
if uploaded_io.is_a?(String)
  expanded = File.expand_path(uploaded_io)
  roots = [Rails.public_path.to_s, Dir.tmpdir]
  unless roots.any? { |r| expanded == r || expanded.start_with?(r + File::SEPARATOR) }
    return { error: 'Invalid file path' }
  end
  uploaded_io = expanded
rescue ArgumentError, TypeError
  return { error: 'Invalid file path' }
end
```

**Rationale:** `File.expand_path` resolves `..` lexically without requiring the file to exist (unlike `File.realpath`). The `== r` check handles the edge case where the expanded path IS the root directory. The `+ File::SEPARATOR` check prevents prefix collisions (e.g., `/app/public_other` is not under `/app/public/`). Rescue catches null bytes and nil.

### Decision 2: Host comparison in `cama_tmp_upload` HTTP branch

Replace substring-based site URL detection with proper host+port comparison.

**Before:**
```ruby
if uploaded_io.include?(current_site.the_url(locale: nil))
  uploaded_io = File.join(Rails.public_path,
    uploaded_io.sub(current_site.the_url(locale: nil), '')).to_s
end
```

**After:**
```ruby
uri = URI.parse(uploaded_io)
site_uri = URI.parse(current_site.the_url(locale: nil))

if uri.host == site_uri.host && uri.port == site_uri.port
  path = uri.path
  langs = current_site.get_languages
  if langs.size > 1
    path = path.sub(%r{\A/(?:#{Regexp.union(langs.map(&:to_s))})(?=/|$)}, '')
  end
  uploaded_io = File.expand_path(File.join(Rails.public_path, path))
end
```

**Rationale:** Host comparison avoids false matches from substring inclusion (e.g., `http://evil.com?url=http://site.com/`). `File.expand_path` canonicalizes the resulting path. Locale prefix stripping handles multi-lingual sites where the first language has no prefix.

### Decision 3: Improved `UserUrlValidator`

Replace the implementation of `CamaleonCms::UserUrlValidator` with an improved version that retains the existing class name, uses existing i18n keys, and adds:
- `reject_path_traversal:` opt-in flag (compares `uri.path` vs `uri.normalized_path`)
- `resolved_ip` accessor for DNS pinning
- `resolve: false` mode for static-only validation
- `validate_external_https` for HTTPS enforcement
- `skip_validation?` controlled by `ENV['CAMALEON_SKIP_URL_VALIDATION']` (default: validate everywhere)
- Stronger IP validation (`Resolv::IPv4::Regex`, `Resolv::IPv6::Regex`, out-of-range octet detection)

**Rationale:** Retaining the class name avoids breaking existing references in plugins. Adapting i18n keys to `camaleon_cms.admin.validate.*` reuses all 13 existing locale translations without adding translation debt. The env-var guard ensures development doesn't silently bypass security checks.

### Decision 4: `data:` URIs skip URL validation

In the `crop_url` controller action, skip `UserUrlValidator` when the URL starts with `data:`.

**Rationale:** `data:` URIs are client-generated (from `getCroppedCanvas().toDataURL()`), have no network component, and cannot be used for SSRF or path traversal via URL. The existing validator blocks them because DNS resolution fails on a scheme with no host.

### Decision 5: i18n — add to `en.yml` only

Add `https_only_url` and `path_traversal` keys to `config/locales/camaleon_cms/admin/en.yml`. Non-English locales fall back to English via Rails i18n default behavior.

**Rationale:** The 11 existing security keys (`host_invalid`, `html_tags`, etc.) already fall back to English for all non-English locales because they were never translated. Adding two more keys to the same pattern is consistent and avoids 22 unnecessary file modifications.

## Risks / Trade-offs

- **`File.expand_path` doesn't resolve symlinks**: An attacker with write access to the allowed directories could create a symlink pointing outside. Mitigation: write access to those directories already implies significant control. `File.realpath` could be added later if needed.
- **`File.expand_path` doesn't URL-decode `%2e%2e`**: If caller passes URL-encoded traversal, `File.expand_path` treats `%2e%2e` as a literal directory name. Mitigation: URL decoding is the caller's responsibility. The HTTP branch in `cama_tmp_upload` receives already-parsed URLs from `URI.parse`.
- **Case-insensitive filesystem**: On macOS, `/APP/PUBLIC/../etc` expands to `/APP/etc` which doesn't match `/app/public/`. Mitigation: Linux is the production target. macOS is development only.
- **`File.expand_path` with empty string returns `Dir.pwd`**: This could allow a relative traversal if the caller passes `""`. Mitigation: the `if uploaded_io.is_a?(String)` guard is preceded by `if uploaded_io.blank?` which returns early for empty strings.
