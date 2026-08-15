# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SvgContentChecker do
  let(:fixtures) { "#{CAMALEON_CMS_ROOT}/spec/support/fixtures" }

  # Shared SVG scaffold declaring both namespaces, so any block can wrap a markup snippet without
  # re-pasting the root element.
  def svg_wrapping(markup)
    %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">#{markup}</svg>)
  end

  describe '.unsafe?' do
    it 'rejects SVG with script tag' do
      content = File.read("#{fixtures}/unsafe-test-xss.svg")
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with onclick attribute' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <rect onclick="alert(1)" width="50" height="50"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with onpointerdown event handler' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <rect onpointerdown="alert(1)" width="50" height="50"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    # An SVG inlined into an HTML document fires ONCLICK exactly as onclick; the case-sensitive XPath
    # missed it while the non-SVG ruleset (case-insensitive) rejected it.
    it 'rejects an uppercase/mixed-case event handler attribute' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <rect ONCLICK="alert(1)" OnMouseOver="alert(2)" width="50" height="50"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with onbegin animation event' do
      content = File.read("#{fixtures}/unsafe-svg-onbegin.svg")
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with javascript: in href' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <a href="javascript:alert(1)">click</a>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with entity-encoded javascript: in href' do
      content = File.read("#{fixtures}/svg-javascript-encoded.svg")
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with DTD entity containing script tag' do
      content = File.read("#{fixtures}/svg-dtd-entity.svg")
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'accepts safe SVG without dangerous content' do
      content = File.read("#{fixtures}/svg-safe.svg")
      expect(described_class.unsafe?(content)).to be(false)
    end

    it 'rejects nil content' do
      expect(described_class.unsafe?(nil)).to be(true)
    end

    it 'rejects empty content' do
      expect(described_class.unsafe?('')).to be(true)
    end

    it 'rejects SVG with foreignObject containing iframe' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
          <foreignObject width="100" height="100">
            <iframe src="https://phishing.com"></iframe>
          </foreignObject>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with data: URI in href' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <a href="data:text/html,<script>alert(1)</script>">click</a>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with object tag' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <object data="javascript:alert(1)"></object>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects SVG with embed tag' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <embed src="javascript:alert(1)"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'rejects non-XML content (binary garbage)' do
      expect(described_class.unsafe?("\xFF\xFE\x00\x01")).to be(true)
    end

    # SMIL animation elements carry no script themselves; the vector is the
    # onbegin/onend/onrepeat attribute, which the element-agnostic on* rule below
    # still rejects.
    it 'accepts an animated SVG with no event handlers' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <circle cx="50" cy="50" r="10">
            <animate attributeName="r" values="10;20;10" dur="2s" repeatCount="indefinite"/>
          </circle>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(false)
    end

    it 'accepts a set element with no event handlers' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <rect width="50" height="50"><set attributeName="fill" to="blue" begin="1s"/></rect>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(false)
    end

    it 'still rejects an animate element carrying an onbegin handler' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <animate onbegin="alert(1)" attributeName="r" dur="1s"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'still rejects a bare foreignObject' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <foreignObject width="100" height="100"><div xmlns="http://www.w3.org/1999/xhtml">t</div></foreignObject>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end
  end

  # Security: doc.to_xml echoes the declared encoding, so a UTF-16/UTF-32 SVG produced an
  # ASCII-incompatible String that raised Encoding::CompatibilityError from the raw <script scan --
  # an exception the Nokogiri::XML::SyntaxError rescue did not catch, surfacing as a 500 on upload
  # instead of a verdict. The scan must return a boolean for any declared encoding.
  describe 'non-UTF-8 declared encodings' do
    def utf16(markup)
      xml = %(<?xml version="1.0" encoding="UTF-16"?>#{markup})
      "\xFF\xFE".b + xml.encode(Encoding::UTF_16LE).b
    end

    it 'does not raise on a benign UTF-16 SVG and accepts it' do
      content = utf16('<svg xmlns="http://www.w3.org/2000/svg"><rect width="5" height="5"/></svg>')
      expect { described_class.unsafe?(content) }.not_to raise_error
      expect(described_class.unsafe?(content)).to be(false)
    end

    it 'still rejects a dangerous UTF-16 SVG (fails closed, no crash)' do
      content = utf16('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>')
      expect(described_class.unsafe?(content)).to be(true)
    end
  end

  # Security (audit 2026-08-11 NEW-1): #1226 narrowed the SVG scan and left the scheme checks without
  # the TAB/LF/CR gap tolerance that ContentSecurity::BLOCKED_SCHEME_PATTERN carries. A browser strips
  # a TAB/LF/CR inside a URI scheme before executing it, so "java&#9;script:" is live markup that the
  # no-gap regexes missed. The SVG scanner is the ONLY gate for an uploaded .svg (the generic ruleset
  # is skipped for that extension), so it must match its non-SVG sibling.
  describe 'in-scheme TAB/LF/CR gap evasion (parity with ContentSecurity)' do
    it 'rejects a TAB gap inside a javascript: href' do
      expect(described_class.unsafe?(svg_wrapping('<a href="java&#9;script:alert(1)">click</a>'))).to be(true)
    end

    # The audit's proof-of-concept: an animated href fires with no user interaction (begin="0s"),
    # so this gap variant is auto-triggering stored XSS, not a click-through.
    it 'rejects the auto-triggering animated javascript: href' do
      markup = '<a xlink:href="java&#9;script:alert(1)"><animate attributeName="x" begin="0s"/></a>'
      expect(described_class.unsafe?(svg_wrapping(markup))).to be(true)
    end

    # Defense-in-depth parity for the serialized `doc.to_xml` catch-all: a gap scheme outside an href is not
    # itself executable, but the non-SVG ruleset already rejects the same bytes, so the SVG scanner
    # must not disagree about them.
    it 'rejects a newline gap inside a scheme anywhere in the document' do
      expect(described_class.unsafe?(svg_wrapping('<text>java&#10;script:alert(1)</text>'))).to be(true)
    end

    it 'still accepts a safe SVG whose text merely mentions a colon' do
      expect(described_class.unsafe?(svg_wrapping('<text>Fig 1: a red circle</text>'))).to be(false)
    end
  end

  # A browser interprets a data: URI by its media type: data:image/png is an inert bitmap (Inkscape/
  # Figma embed rasters this way and such files must upload), while data:text/html and
  # data:image/svg+xml carry active content and must stay rejected.
  describe 'data: URI scheme handling' do
    it 'accepts an embedded raster image (data:image/png)' do
      expect(described_class.unsafe?(svg_wrapping('<image xlink:href="data:image/png;base64,AAAA"/>'))).to be(false)
    end

    it 'accepts other raster media types' do
      %w[image/jpeg image/gif image/webp image/x-icon].each do |mime|
        expect(described_class.unsafe?(svg_wrapping(%(<image xlink:href="data:#{mime};base64,AAAA"/>)))).to be(false)
      end
    end

    it 'still rejects data:text/html' do
      expect(described_class.unsafe?(svg_wrapping('<a href="data:text/html,alert(1)">y</a>'))).to be(true)
    end

    it 'still rejects data:image/svg+xml, which can carry script' do
      expect(described_class.unsafe?(svg_wrapping('<a href="data:image/svg+xml,payload">y</a>'))).to be(true)
    end

    it 'still rejects a bare data: URI' do
      expect(described_class.unsafe?(svg_wrapping('<a href="data:,payload">y</a>'))).to be(true)
    end

    it 'accepts prose whose text merely contains a scheme-like word' do
      expect(described_class.unsafe?(svg_wrapping('<text>Metadata: 42 rows of data</text>'))).to be(false)
    end
  end

  # These five are valid SVG and none executes script on its own, but an uploaded SVG is served
  # inline from the site origin. ContentSecurity::BLOCKED_ELEMENTS already refuses all of them in
  # every non-SVG upload; refusing them here stops the two rulesets disagreeing about the same
  # bytes, which is what let an accepted .svg be re-uploaded under another extension.
  describe 'elements that make a served SVG behave like a page' do
    it 'rejects a form, which can collect credentials on the site origin' do
      expect(described_class.unsafe?(svg_wrapping('<form action="https://evil.example"><input name="p"/></form>')))
        .to be(true)
    end

    it 'rejects a meta refresh, which can navigate the visitor away' do
      expect(described_class.unsafe?(svg_wrapping('<meta http-equiv="refresh" content="0;url=https://evil.example"/>')))
        .to be(true)
    end

    it 'rejects a base element, which can repoint every relative URL in the document' do
      expect(described_class.unsafe?(svg_wrapping('<base href="https://evil.example/"/>'))).to be(true)
    end

    it 'rejects a style element' do
      expect(described_class.unsafe?(svg_wrapping('<style>rect { fill: red }</style>'))).to be(true)
    end

    it 'rejects a link element, which can pull in remote styling' do
      expect(described_class.unsafe?(svg_wrapping('<link rel="stylesheet" href="https://evil.example/x.css"/>')))
        .to be(true)
    end

    it 'still accepts a plain shape, so the ban is scoped to those five' do
      expect(described_class.unsafe?(svg_wrapping('<circle cx="50" cy="50" r="40" fill="red"/>'))).to be(false)
    end
  end

  describe 'HTML parse mode' do
    def html(markup)
      described_class.unsafe?(markup, mode: :html)
    end

    context 'with the handler match keyed on shape rather than a name list' do
      # The four the regex denylist in ContentSecurity misses. Each is an ordinary interaction
      # handler that fires on a plain click or touch -- no exotic element required.
      %w[onpointerdown ontouchstart onauxclick onemptied].each do |handler|
        it "rejects #{handler}, which no denylist stem matches" do
          expect(html(%(<div #{handler}="alert(1)">x</div>))).to be(true)
        end
      end

      it 'rejects a handler name that does not exist yet, because the match is on the on prefix' do
        expect(html(%(<div onsomethingnotyetinvented="alert(1)">x</div>))).to be(true)
      end

      it 'rejects a handler in mixed case' do
        expect(html(%(<div OnPointerDown="alert(1)">x</div>))).to be(true)
      end
    end

    context 'with malformed input, where HTML has no parse-failure signal' do
      it 'accepts a badly nested document that carries nothing dangerous' do
        expect(html('<div><p><span>unclosed everything')).to be(false)
      end

      it 'still rejects a badly nested document that carries a handler' do
        expect(html('<div><p><span onpointerdown=x>hi</div>')).to be(true)
      end

      it 'accepts a whitespace-only document, which parses to a nil root' do
        expect(html("\n  \n")).to be(false)
      end

      it 'accepts a comment-only document, which also parses to a nil root' do
        expect(html('<!-- just a comment -->')).to be(false)
      end

      it 'accepts ordinary prose containing a comparison operator' do
        expect(html('<p>Ages 5 &lt; n &lt; 12 qualify</p>')).to be(false)
      end
    end

    context 'with the same payload in either mode' do
      # The two modes exist because the parsers differ, not because the rules do. A payload that is
      # well-formed XML and valid HTML must get the same verdict whichever parser reads it.
      let(:handler_payload) do
        %(<svg xmlns="http://www.w3.org/2000/svg"><rect onpointerdown="alert(1)" width="10" height="10"/></svg>)
      end

      let(:clean_payload) do
        %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>)
      end

      it 'rejects the handler payload in XML mode' do
        expect(described_class.unsafe?(handler_payload, mode: :xml)).to be(true)
      end

      it 'rejects the handler payload in HTML mode' do
        expect(described_class.unsafe?(handler_payload, mode: :html)).to be(true)
      end

      it 'accepts the clean payload in both modes' do
        expect(described_class.unsafe?(clean_payload, mode: :xml)).to be(false)
        expect(described_class.unsafe?(clean_payload, mode: :html)).to be(false)
      end
    end

    context 'with elements the generic ruleset refuses but the SVG list omitted' do
      # BANNED_TAGS is the union of the SVG list and ContentSecurity::BLOCKED_ELEMENTS. Without the
      # union, routing .html here would have refused these for fewer reasons than the regex denylist
      # it replaced -- a narrowing disguised as a hardening.
      %w[applet frameset frame template portal marquee math].each do |tag|
        it "rejects a #{tag} element, which BLOCKED_ELEMENTS also refuses" do
          expect(html("<#{tag}></#{tag}>")).to be(true)
        end
      end
    end

    it 'defaults to XML mode when no mode is given, preserving the original signature' do
      expect(described_class.unsafe?(svg_wrapping('<circle r="5"/>'))).to be(false)
      # Content that parses to no root at all is refused in XML mode -- the fail-closed signal HTML
      # mode cannot have. The identical bytes are accepted as HTML, where they are just prose.
      expect(described_class.unsafe?('plain text, no markup at all')).to be(true)
      expect(html('plain text, no markup at all')).to be(false)
    end
  end
end
