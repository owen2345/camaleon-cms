## Context

See proposal.md — Why. The constraints that shape the approach:

- **Extension selects the ruleset, and the client supplies the extension.** `content_unsafe?`
  branches on `cama_svg_extension?(filename)`; everything else falls to the regex denylist.
  `params[:formats]` is a picker filter, not a security control, and defaults to permitting
  everything.
- **Uploads are served same-origin** from `public/media/<site_id>/`.
- **The project policy places the entire trust decision at save time.** Untrusted content is scanned
  and refused on finding something dangerous, never sanitized or rewritten; file types are not
  restricted; and content that passes is stored and served verbatim. Nothing downstream of that
  decision may constrain it — a trusted user's upload must behave in the browser exactly as they
  intended, so serving-side headers, policies and dispositions are not available as controls here.
- **`UnsafeMarkup` already exists** and already rejects every `on*` attribute by allowlist — but it
  is bound to post and custom-field content, not uploads.

## Goals / Non-Goals

**Goals:**

- Make the strong ruleset reachable for every upload a browser parses as markup.
- Keep the verdict independent of which parser read the bytes.
- Close the two paths where content is scanned in name only: compressed markup, and executable
  script.

**Non-Goals:**

- A server-enforced extension allowlist. The archived `2026-08-03-scoped-upload-roots-and-scan-narrowing`
  design reached for one because it was simultaneously trying to *widen* HTML support; this change
  does not need that lever and does not add it.
- Removing `params[:formats]` as an upload filter. It stays exactly what it is.
- Any serving-side control over stored content — `nosniff`, CSP, `Content-Disposition`, a separate
  media origin. Content that was permitted to be stored is served verbatim and runs unrestricted.
  Every control in this design acts at the save-time decision and nowhere else.
- Consolidating all authored-markup detection into one module. See D2.
- Archive-borne malware (`.zip`, `.docx`). A distribution concern, not origin XSS.

## Decisions

### D1 — Route by render behavior, not by a literal `.svg` match

The branch becomes "will a browser parse this as markup?" instead of "is this named `.svg`?".
This is a generalization, not a restriction: nothing becomes unuploadable, every upload is still
scanned, and rejection still requires actually finding something dangerous.

| Alternative | Verdict |
|---|---|
| Route by render behavior | **Chosen** — closes the gap without restricting any type; fits the scan-and-reject policy exactly |
| Add the missing stems (`onpointer`, `ontouch`, …) to the denylist | Rejected — the list is unbounded and grows with the platform; the archived SVG design already rejected denylist expansion on these grounds, and `onpointerdown` was its worked example |
| Server-enforced extension allowlist | Rejected — contradicts the project policy of not restricting upload types, and is not needed to close this gap |

The generic denylist stays in service for non-markup uploads. Its incompleteness cannot produce a
stored-XSS path there, because those bytes are not parsed as markup by the browser.

### D2 — Generalize `SvgContentChecker` rather than reuse `UnsafeMarkup`

`UnsafeMarkup` catches every `on*` attribute more thoroughly than the SVG checker does — it is an
allowlist, so it never names a handler at all. But pointing it at uploads rejects legitimate files.
Measured against the post-content allowlist:

| Input | Verdict | Cause |
|---|---|---|
| `<div onpointerdown="x()">` | rejected | correct |
| minimal real HTML document | rejected | `<html>/<head>/<body>` not in the allowlist |
| content with an ordinary HTML comment | rejected | `disallowed_comment?` refuses every `<!--` that is not a translation marker |
| 3 MB of clean text | rejected | `MAX_GATED_VALUE_BYTES` is 2 MB |

Those three rules are correct for a translated rich-text field and wrong for a document upload, and
only `tags:`/`attributes:` are parameterized — the comment rule, translation-marker shield and size
ceiling are hardcoded.

| Alternative | Verdict |
|---|---|
| Widen `SvgContentChecker` to all markup | **Chosen** — smallest delta, no regression for uploads that succeed today, closes the gap |
| Reuse `UnsafeMarkup` with a document allowlist | Deferred — the better end state if all authored markup should share one detector, but it means parameterizing three more rules and adding a third policy mode to a module currently serving two. Worth doing deliberately, not as a side effect of a security fix |
| Reuse `UnsafeMarkup` as-is | Rejected — rejects legitimate HTML documents, per the table above |

The checker's subject is now broader than SVG. The capability path `svg-upload-sanitization` is
preserved for continuity; renaming it is archive-time churn with no behavioral content.

### D3 — Two parse modes, one ruleset

`html`/`htm`/`shtml` are parsed with the HTML parser; `svg`/`svgz`/`xhtml`/`xht`/`xml`/`xsl`/`xslt`
keep the XML parser. Both apply the same rejection rules, so a payload gets the same verdict either
way.

The modes differ in exactly one respect, and it must not be papered over: `Nokogiri::XML` reports a
syntax error on a malformed document, which the current checker uses as a fail-closed signal.
`Nokogiri::HTML` never raises — every byte sequence parses. HTML mode therefore has no
parse-failure signal and is decided entirely by the rules applied to the resulting tree. Carrying
the XML rescue into HTML mode would be dead code implying a guarantee that does not exist.

This is also why routing must stay narrow. Running an HTML parse over non-markup produces false
rejections — `if a<b and on=1 then x` in a `.txt` parses to a `<b>` element with an `on` attribute
and would be refused. Only extensions actually served as markup reach the parser, so that input
never gets there.

### D4 — Bounded decompression, and scan raw bytes when the payload is not gzip

Gzip output is high-entropy: neither a regex nor a parser can see through it, so `.svgz` is scanned
today in name only. Decompress first, then apply the markup checker.

Decompression needs its own size bound, unlike plain parsing. A plain parse is already bounded by
the upload `maximum` size option, but compression breaks that relationship — a few-KB upload can
expand to gigabytes, so the input limit no longer bounds the work. Read the decompressed stream in
chunks to a ceiling and refuse on overflow; never read it unbounded.

Bytes under a compressed extension that are not valid gzip are scanned as raw markup rather than
skipped: nginx's default mime map serves `.svgz` as `image/svg+xml`, so an ungzipped file under that
name still renders. Failing over to a raw scan keeps both server configurations covered.

### D5 — Script types reuse `media_unfiltered_upload`

JavaScript admits no meaningful scan. There is no safe subset, every dangerous capability is
reachable through dynamic construction (`window['fet'+'ch']`, `[]['constructor']['constructor']`),
and legitimate uploaded JS is arbitrary JS — indistinguishable from a payload by any static rule. A
scanner that cannot reach a verdict must fail closed, and a fail-closed scanner for script types is
a permission gate.

Reusing the existing permission rather than adding one grants nothing new: a holder already skips
scanning entirely and can already store these files. An install that has granted it sees no change.

| Alternative | Verdict |
|---|---|
| Reuse `media_unfiltered_upload` | **Chosen** — zero behavior change for existing grants; the permission's own description already claims this ground ("grants the ability to publish active content there") |
| Serve script types as downloads instead of refusing them | Rejected — a serving-side control, outside the save-time decision; it would also constrain what a trusted user's deliberate upload does in the browser |
| New dedicated permission | Rejected — a role holding `media_unfiltered_upload` today would *lose* script upload unless also granted the new one, a regression for existing installs, plus a second permission to document |
| Scan JS content for dangerous APIs | Rejected — defeated by one line of obfuscation; would assert a guarantee the implementation cannot keep |

### D6 — The backfill is a report-only Rake task

New rules apply at upload time, so files already stored are never re-examined. A Rake task follows
the project convention (`lib/tasks/unsafe_stored_content.rake` is the precedent) and avoids forcing
a `schema.rb` regeneration that a migration would.

Report-only, never destructive: deleting or quarantining a site's stored media on the strength of a
scanner verdict is the operator's decision, not the task's. The output names the file and the rule
that would refuse it so that decision can be made.

### D7 — The governing rule is amended in all three places, with the wording agreed here

Both policy errors caught while planning this change (a proposed extension gate for markup, and a
proposed `nosniff` widening) passed the letter of the written rule. The rule underdetermines two
joints, and the same two gaps exist in `AGENTS.md`, `docs/security/permissions.md` and
`openspec/specs/security-capability-gating/spec.md` — so amending one and not the others would put
them out of sync.

- **Scope.** The remedy rule is written entirely around "at save" and enumerates transformations
  (sanitize/strip/escape/rewrite). A response header transforms nothing and acts after save, so it
  conforms to the letter while breaking the principle.
- **Precedence.** The gating rule licenses a default-off permission for "an action that presents a
  security threat" without ranking it below scanning, so a gate reads as available wherever the
  author judges something dangerous.

The spec delta in this change carries both clauses normatively. The prose wording below is agreed
here so applying it is mechanical rather than improvised.

**`AGENTS.md` §1 — replace the "Security remedy rule" bullet with:**

> - **Security remedy rule (reject at save; don't transform, don't constrain downstream):** content
>   or uploads from untrusted users are **scanned and rejected at save** — never sanitized, stripped,
>   escaped-away, or otherwise rewritten. The save-time decision is the **only** lever: content that
>   passes is stored *and served* verbatim, and no response header, CSP, content-disposition,
>   separate origin or other serving-side control may constrain what a stored file does in the
>   browser. Before proposing any control, ask whether it would constrain a **trusted** user's
>   content — if it would, it is outside the model however conventional it is as security hygiene.
>   Admins can do anything. For other roles, **prefer the scan**: a dedicated default-off permission
>   is the remedy only where a scan cannot reach a verdict at all (uploaded JavaScript has no safe
>   subset, so no scan can decide it) — never a substitute for scanning where scanning works, and
>   never a restriction on file types the scan can judge. Full model:
>   `docs/security/permissions.md` ("The remedy rule" and "The gating rule"); codified in
>   `openspec/specs/security-capability-gating/spec.md`.

**`docs/security/permissions.md` → "The gating rule" — add as rule 3, after the fail-closed rule:**

> 3. **A gate is the last resort, not the first.** Where the threat is *content* and that content can
>    be judged, the save-time scan judges it (see the remedy rule below) — a blanket refusal by file
>    type, format or category is wrong there. A dedicated permission is the remedy only where no scan
>    can reach a verdict at all. Uploaded JavaScript is the worked example: it has no safe subset and
>    every dangerous capability is reachable through dynamic construction
>    (`window['fet'+'ch']`, `[]['constructor']['constructor']`), so no static rule decides it and the
>    check fails closed. Uploaded markup is the counter-example: it has a finite grammar, so the
>    parse-based scan decides it and `.html` is deliberately *not* gated by type.
>
> Where an existing permission's holders already possess the capability, extend that permission
> rather than adding one — a new permission would *revoke* the capability from installs that already
> granted the old one. `media_unfiltered_upload` covers script uploads for exactly this reason: a
> holder already skips the scan and could already store them.

**`docs/security/permissions.md` → "The remedy rule" — add as property 4, and change the intro's
"Three properties follow" to "Four properties follow":**

> 4. **The save-time decision is the only lever.** Content that passes the gate is stored *and
>    served* verbatim. No response header, CSP, `X-Content-Type-Options`, `Content-Disposition`,
>    separate media origin or other serving-side control constrains what a stored file does in the
>    browser — a trusted user was permitted to store it, so it behaves exactly as they intended.
>    This bounds the rule from below as the no-transform clause bounds it from above. The test before
>    proposing any control: *would it constrain a trusted user's content?* If yes, it is outside this
>    model whatever its merit as general security hygiene.

## Risks / Trade-offs

- **Roles uploading `.js` today start being refused** → This is the intended behavior change and the
  only one in the change. Needs a CHANGELOG upgrader note naming `media_unfiltered_upload` as the
  grant that restores it. Ships as its own commit so it can be reverted independently.
- **Widening markup routing widens what reaches a parser** → Bounded by the existing upload
  `maximum` size option for uncompressed input, and by the explicit decompression ceiling for
  compressed input. The `.svg` path already had this property; the change extends it rather than
  introducing it.
- **HTML-mode uploads lose the parse-failure backstop** → Accepted and specified, not hidden. A
  malformed HTML file is judged on its content. There is no way to recover the signal, since the
  HTML parser is the same one the browser uses.
- **`svg-upload-sanitization` now describes more than SVG** → Path preserved deliberately; the
  capability's first requirement states the widened scope so the name cannot mislead a reader who
  opens the spec.
- **The backfill may report a large number of pre-existing files** on installs that have permitted
  markup or script uploads for years → Report-only means this is informational, not an outage. Worth
  saying plainly in the task output that a finding is not automatically a compromise.

## Migration Plan

1. Land D1–D4 first: pure hardening, no behavior change for uploads that succeed today.
2. Land D5 as its own commit — the only user-visible restriction — with the CHANGELOG upgrader note.
3. Land D6, which is additive and read-only.
4. Rollback: each commit is independent. Reverting D5 alone restores script uploads for untrusted
   roles without touching the markup work.
