## 1. Branch and reproducing tests

- [x] 1.1 Create a `security/` branch off current `master` per AGENTS.md Phase 1
- [x] 1.2 Add a failing spec proving the same payload is accepted as `x.html`/`x.htm`/`x.xhtml`/`x.xml` and rejected as `x.svg` (the reported `onpointerdown` bypass)
- [x] 1.3 Add a failing spec proving a `.svgz` gzip payload carrying an event handler is accepted
- [x] 1.4 Add a failing spec proving `.js`, `.mjs`, `.cjs` and `.wasm` uploads carrying script payloads are accepted for a user without `media_unfiltered_upload`
- [x] 1.5 Confirm all four fail on `master` before writing any fix

## 2. Markup routing (D1)

- [x] 2.1 Add the markup-extension classification (`svg svgz svg.gz html htm xhtml xht shtml xml xsl xslt`), case-insensitive, with the fail-closed dotfile handling the current `.svg` check has
- [x] 2.2 Replace the `cama_svg_extension?` branch in `content_unsafe?` with markup routing; keep the generic ruleset for everything else
- [x] 2.3 Specs: every markup extension refuses the shared payload; `.txt` containing `if a<b and on=1 then x` is still accepted; uppercase and bare-dotfile names route to the markup checker
- [x] 2.4 Commit: markup routing only

## 3. Markup checker generalization (D2, D3)

- [x] 3.1 Widen `SvgContentChecker` to accept a parse mode; keep every existing rejection rule unchanged
- [x] 3.2 Add the HTML parse mode for `html`/`htm`/`shtml`; keep XML mode for the rest
- [x] 3.3 Confine the `Nokogiri::XML::SyntaxError` rescue to XML mode — do not carry a parse-failure guarantee into HTML mode that the parser cannot provide
- [x] 3.4 Specs: identical payloads get identical verdicts in both modes; a malformed-but-clean `.html` is accepted; a malformed `.html` carrying a handler is rejected; ordinary HTML comments and unclosed tags do not cause rejection
- [x] 3.5 Specs: an attribute named `onsomethingnotyetinvented` is rejected, proving the match is on shape and not a name list
- [x] 3.6 Commit: markup checker generalization

## 4. Compressed markup (D4)

- [x] 4.1 Decompress gzip payloads for compressed-markup extensions before scanning, reading in chunks to a decompressed-size ceiling
- [x] 4.2 Refuse on ceiling overflow rather than continuing to decompress
- [x] 4.3 Fall back to scanning raw bytes as markup when the payload is not valid gzip
- [x] 4.4 Specs: hostile `.svgz` rejected; clean `.svgz` accepted; a compression bomb is refused at the bound without exhausting memory; ungzipped bytes under `.svgz` are still scanned
- [x] 4.5 Commit: compressed markup scanning

## 5. Script-type gating (D5)

- [x] 5.1 Add the script-extension classification (`js mjs cjs wasm swf`), case-insensitive, same dotfile handling as markup
- [x] 5.2 Refuse script-type uploads for users without `media_unfiltered_upload`, reusing the existing fail-closed permission resolution (no request user, no site, or a resolution error all count as not holding it)
- [x] 5.3 Specs: refused without the permission, including an obfuscated payload; accepted with it; accepted for `admin`; refused with no request context
- [x] 5.4 Commit: script-type gating, on its own so it can be reverted independently of the markup work

## 6. Backfill scan task (D6)

- [x] 6.1 Add a report-only Rake task under `lib/tasks/` that scans the media root and reports files the current rules would refuse, modelled on `lib/tasks/unsafe_stored_content.rake`
- [x] 6.2 Report each finding by site and path with the rule that would refuse it; never delete, move, quarantine or rewrite
- [x] 6.3 State in the task output that a finding is not automatically evidence of compromise
- [x] 6.4 Specs: hostile stored markup and stored script are reported; reported files remain present and byte-identical; a clean media root reports nothing and exits successfully
- [x] 6.5 Commit: backfill scan task

## 7. Documentation

- [x] 7.1 CHANGELOG entry — lead paragraph plus upgrader notes only; name `media_unfiltered_upload` as the grant that restores script uploads, and credit the reporter
- [x] 7.2 Replace the AGENTS.md §1 "Security remedy rule" bullet with the agreed wording in design.md D7
- [x] 7.3 Add rule 3 to "The gating rule" in `docs/security/permissions.md` per design.md D7 (scan-before-gate precedence, plus the extend-don't-replace paragraph)
- [x] 7.4 Add property 4 to "The remedy rule" in `docs/security/permissions.md` per design.md D7, and change its intro from "Three properties follow" to "Four properties follow"
- [x] 7.5 Update the `media_unfiltered_upload` section of `docs/security/permissions.md` for its widened meaning (script-type uploads), and cross-check that the four documented permissions still read as instances of the amended gating rule
- [x] 7.6 Confirm the amended prose in 7.2–7.4 matches the `security-capability-gating` spec delta normatively — the spec is the codification, the docs restate it
- [x] 7.7 Check `docs/ai/*` for any statement that the content denylist is the control for markup uploads, and correct it

## 8. Verification

- [x] 8.1 Confirm the four specs from group 1 now pass
- [x] 8.2 `bin/rubocop -A` on touched files — run before the suite, since autocorrect can rewrite adjacent string literals
- [x] 8.3 `bin/rspec` full suite green
- [x] 8.4 `bin/brakeman --no-pager` clean
- [x] 8.5 `(cd spec/dummy && bin/rails zeitwerk:check)` passes
- [x] 8.6 Self-audit against `docs/ai/criteria.md` before opening the PR
- [x] 8.7 `openspec validate harden-upload-markup-and-script-scanning --strict` still passes, then archive on the branch before merge
