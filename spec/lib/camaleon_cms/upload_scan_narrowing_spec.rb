# frozen_string_literal: true

RSpec.describe CamaleonCms::ContentSecurity do
  let(:scanner) { Class.new { include CamaleonCms::UploaderContentSecurity }.new }

  describe 'blocked scheme tolerance' do
    it 'accepts prose where a scheme word precedes a spaced colon' do
      expect(scanner.content_unsafe?('Sample data : 42', filename: 'notes.txt')).to be_nil
    end

    # A browser strips LF/CR/TAB from inside a URL, so a newline-gapped *functional* data: URI
    # ("data\n:text/html,..") resolves to a live "data:text/html,.." and stays blocked.
    it 'still rejects a newline gap inside a functional data: URI' do
      expect(scanner.content_unsafe?(%(<a href="data\n:text/html,x">y</a>), filename: 'x.txt')).not_to be_nil
    end

    # A bare "data:" with no media type or ;/, delimiter is not a working URI, so it is left alone even
    # across a gap -- once the gap is stripped it is indistinguishable from prose like "metadata: 42",
    # and blocking it would false-positive on ordinary text/CSV/log uploads.
    it 'accepts a non-functional data: word even across a newline gap' do
      expect(scanner.content_unsafe?("column: data\n: 42\n", filename: 'notes.txt')).to be_nil
    end

    it 'still rejects a TAB injected inside a scheme name' do
      expect(scanner.content_unsafe?(%(<a href="jav\tascript:alert(1)">x</a>), filename: 'x.txt')).not_to be_nil
    end

    it 'still rejects a LF injected inside a scheme name' do
      expect(scanner.content_unsafe?(%(<a href="java\nscript:alert(1)">x</a>), filename: 'x.txt')).not_to be_nil
    end

    it 'still rejects a CR injected inside a scheme name' do
      expect(scanner.content_unsafe?(%(<a href="javascr\ript:alert(1)">x</a>), filename: 'x.txt')).not_to be_nil
    end

    it 'still rejects a plain javascript: URI' do
      expect(scanner.content_unsafe?(%(<a href="javascript:alert(1)">x</a>), filename: 'x.txt')).not_to be_nil
    end

    it 'still rejects a plain vbscript: URI' do
      expect(scanner.content_unsafe?(%(<a href="vbscript:msgbox">x</a>), filename: 'x.txt')).not_to be_nil
    end

    it 'still rejects a data: URI' do
      expect(scanner.content_unsafe?('<img src="data:text/html;base64,PHNjcmlwdD4=">', filename: 'x.txt'))
        .not_to be_nil
    end
  end
end
