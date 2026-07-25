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

    it 'accepts CSV' do
      expect(scan("name,email\nAda,ada@example.com", ext: '.csv')).to be_falsey
    end

    it 'accepts JSON' do
      expect(scan(%({"title":"Report","count":42}), ext: '.json')).to be_falsey
    end
  end

  describe 'accepted false positive' do
    # Normalization decodes entities before matching, so a document that merely
    # *shows* escaped markup is rejected. This is fail-closed and intentional --
    # see design.md Risks. Pinned so it is not "fixed" later as a bug.
    it 'rejects a document containing HTML-escaped code examples' do
      expect(scan(%(<p>Use &lt;script&gt; carefully</p>))).to be_truthy
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
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"><rect onclick="alert(1)"/></svg>)
      expect(CamaleonCms::SvgContentChecker).to receive(:unsafe?).with(svg).and_call_original
      expect(scanner.content_unsafe?(svg, filename: 'x.svg')).to be(true)
    end

    it 'accepts a clean SVG' do
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>)
      expect(scanner.content_unsafe?(svg, filename: 'x.svg')).to be_nil
    end

    it 'handles binary content without raising' do
      binary = File.binread("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png")
      expect { scanner.content_unsafe?(binary, filename: 'rails.png') }.not_to raise_error
    end
  end

  describe CamaleonCms::ContentSecurity do
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
