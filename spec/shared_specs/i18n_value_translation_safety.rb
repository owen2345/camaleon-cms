# frozen_string_literal: true

RSpec.shared_context 'i18n value base matrix' do
  let(:safe_input) { 't(admin.my_text)' }
  let(:quoted_safe_input) { 't(  "admin.my_text"  )' }
  let(:expected_translation) { 'My Text' }
  let(:plain_input) { 'Regular label' }
end

RSpec.shared_context 'i18n value malformed payload matrix' do
  let(:malformed_payloads) do
    [
      "t(admin.my_text, default: 'fallback')",
      't(admin.my_text',
      't(admin.my_text)); Kernel.system(\'echo pwned\')',
      't()',
      't("admin.my_text\')'
    ]
  end
end

RSpec.shared_context 'i18n value malicious payload matrix' do
  let(:malicious_payloads) do
    [
      "t(Kernel.system('echo pwned'))",
      't(File.read("/etc/passwd"))',
      "t(%x[echo pwned])"
    ]
  end
end

RSpec.shared_examples 'i18n value translation safety' do
  include_context 'i18n value base matrix'
  include_context 'i18n value malformed payload matrix'
  include_context 'i18n value malicious payload matrix'

  it 'translates safe i18n key expressions' do
    expect(render_i18n_value(safe_input)).to eq(expected_translation)
  end

  it 'translates safely quoted i18n key expressions' do
    expect(render_i18n_value(quoted_safe_input)).to eq(expected_translation)
  end

  it 'returns non-i18n strings unchanged' do
    expect(render_i18n_value(plain_input)).to eq(plain_input)
  end

  it 'returns malformed t(...) payloads unchanged' do
    malformed_payloads.each do |payload|
      expect(render_i18n_value(payload)).to eq(payload)
    end
  end

  it 'returns malicious t(...) payloads unchanged' do
    malicious_payloads.each do |payload|
      expect(Kernel).not_to receive(:system) if payload.include?('Kernel.system')
      expect(render_i18n_value(payload)).to eq(payload)
    end
  end
end
