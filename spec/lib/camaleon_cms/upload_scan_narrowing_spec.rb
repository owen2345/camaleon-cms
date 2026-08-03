# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::ContentSecurity do
  let(:scanner) { Class.new { include CamaleonCms::UploaderContentSecurity }.new }

  describe 'blocked scheme tolerance' do
    it 'accepts prose where a scheme word precedes a spaced colon' do
      expect(scanner.content_unsafe?('Sample data : 42', filename: 'notes.txt')).to be_nil
    end

    # Accepted false positive: browsers strip LF from a URL, so "data\n:" in an
    # attribute really does resolve to "data:". Prose in that exact shape stays
    # blocked because it is indistinguishable from the evasion.
    it 'still rejects a scheme word separated from its colon by a newline' do
      expect(scanner.content_unsafe?("column: data\n: 42\n", filename: 'notes.txt')).not_to be_nil
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
