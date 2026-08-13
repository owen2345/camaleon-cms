# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SvgContentChecker do
  let(:fixtures) { "#{CAMALEON_CMS_ROOT}/spec/support/fixtures" }

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

  # Security (audit 2026-08-11 NEW-1): #1226 narrowed the SVG scan and left the scheme checks without
  # the TAB/LF/CR gap tolerance that ContentSecurity::BLOCKED_SCHEME_PATTERN carries. A browser strips
  # a TAB/LF/CR inside a URI scheme before executing it, so "java&#9;script:" is live markup that the
  # no-gap regexes missed. The SVG scanner is the ONLY gate for an uploaded .svg (the generic ruleset
  # is skipped for that extension), so it must match its non-SVG sibling.
  describe 'in-scheme TAB/LF/CR gap evasion (parity with ContentSecurity)' do
    it 'rejects a TAB gap inside a javascript: href' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <a href="java&#9;script:alert(1)">click</a>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    # The audit's proof-of-concept: an animated href fires with no user interaction (begin="0s"),
    # so this gap variant is auto-triggering stored XSS, not a click-through.
    it 'rejects the auto-triggering animated javascript: href' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
          <a xlink:href="java&#9;script:alert(1)"><animate attributeName="x" begin="0s"/></a>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    # Defense-in-depth parity for the serialized catch-all (:41): a gap scheme outside an href is not
    # itself executable, but the non-SVG ruleset already rejects the same bytes, so the SVG scanner
    # must not disagree about them.
    it 'rejects a newline gap inside a scheme anywhere in the document' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <text>java&#10;script:alert(1)</text>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(true)
    end

    it 'still accepts a safe SVG whose text merely mentions a colon' do
      content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <text>Fig 1: a red circle</text>
          <circle cx="50" cy="50" r="40" fill="red"/>
        </svg>
      SVG
      expect(described_class.unsafe?(content)).to be(false)
    end
  end

  # These five are valid SVG and none executes script on its own, but an uploaded SVG is served
  # inline from the site origin. ContentSecurity::BLOCKED_ELEMENTS already refuses all of them in
  # every non-SVG upload; refusing them here stops the two rulesets disagreeing about the same
  # bytes, which is what let an accepted .svg be re-uploaded under another extension.
  describe 'elements that make a served SVG behave like a page' do
    def svg_wrapping(markup)
      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          #{markup}
        </svg>
      SVG
    end

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
end
