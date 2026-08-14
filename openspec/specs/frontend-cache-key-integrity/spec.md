# frontend-cache-key-integrity Specification

## Purpose
The front_cache plugin serves a stored page body keyed by URL. That key must identify the URL
uniquely, so one URL's cached body is never served for a different URL, and building it must not be
derailed by a malformed admin-configured path pattern.
## Requirements
### Requirement: The page cache key is lossless

The front_cache page cache key SHALL be derived from the full request URI by a collision-resistant
transform (a cryptographic digest), not a lossy one such as `parameterize`. Two requests whose URIs
differ SHALL map to different cache keys.

#### Scenario: URLs differing only in separators do not collide

- **WHEN** two cacheable requests have URIs that differ only in characters `parameterize` would
  collapse (for example `/a/b` versus `/a-b`)
- **THEN** they are stored under different cache keys

### Requirement: A malformed path pattern does not break request handling

The configured cache path patterns SHALL be compiled defensively: an invalid pattern SHALL be
skipped rather than raising, so a bad admin-entered pattern cannot 500 every matched request.

#### Scenario: An invalid pattern is ignored

- **WHEN** the cache path patterns include a string that is not a valid regular expression
- **THEN** matching skips it and does not raise

