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
  end
end
