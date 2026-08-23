# frozen_string_literal: true

describe 'CamaleonCms::Admin::ApplicationHelper' do
  describe '#cama_shortcode_print' do
    it 'returns an input tag with auto-select JS attributes' do
      code = '[test_shortcode]'
      result = helper.cama_shortcode_print(code)

      expect(result).to include('input')
      expect(result).to include('class="code_style"')
      expect(result).to include('readonly="readonly"')
      expect(result).to include('onmousedown="this.clicked = 1;"')
      expect(result).to include('onfocus="if (!this.clicked) this.select(); else this.clicked = 2;"')
      expect(result).to include('onclick="if (this.clicked == 2) this.select(); this.clicked = 0;"')
      expect(result).to include('value="[test_shortcode]"')
    end

    it 'escapes the value attribute to prevent XSS' do
      malicious_code = '"><script>alert(1)</script>'
      result = helper.cama_shortcode_print(malicious_code)

      expect(result).to include('value="&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;"')
      expect(result).not_to include('"><script>')
    end
  end
end
