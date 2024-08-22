# frozen_string_literal: true

RSpec.shared_examples 'sanitize attrs' do |model:, attrs_to_sanitize:|
  attrs_to_sanitize.each do |attr|
    it 'sanitizes attributes on create, not touching translation tags' do
      attrs_for_creation = { attr => '<!--:en-->"><script>alert(1)</script>' }
      attrs_for_creation.merge!(site: @site) if defined?(@site)
      model_instance = model.create(attrs_for_creation)

      expect(model_instance.__send__(attr)).to eql('<!--:en-->"&gt;alert(1)')
    end

    it 'sanitizes attributes on update, not touching translation tags' do
      attrs_for_creation = { attr => 'Legit text' }
      attrs_for_creation.merge!(site: @site) if defined?(@site)
      model_instance = model.create(attrs_for_creation)
      model_instance.update(attr => '<!--:en-->"><script>alert(1)</script>')

      expect(model_instance.__send__(attr)).to eql('<!--:en-->"&gt;alert(1)')
    end
  end
end
