# frozen_string_literal: true

require 'rails_helper'

describe CamaleonCms::CaptchaHelper do
  subject(:helper_instance) { plain_class.new }

  # Test the helper when included in a plain object without view context.
  # This mirrors how CamaleonController includes the module — the controller
  # instance does NOT have direct access to view helpers like image_tag.
  let(:plain_class) do
    Class.new do
      include CamaleonCms::CaptchaHelper

      attr_accessor :session, :params

      def initialize
        @session = {}
        @params = {}
      end

      def current_site
        # Return a decorated site object required by cama_captcha_under_attack?
        site = instance_double(Cama::Site)
        allow(site).to receive(:get_option).and_return(5)
        site
      end

      def cama_captcha_url(**args)
        "http://test.host/captcha.png?len=#{args[:len]}&t=#{args[:t]}"
      end
    end
  end

  describe '#cama_captcha_tag' do
    it 'generates valid HTML with image and input tags' do
      result = helper_instance.cama_captcha_tag

      expect(result).to be_a(String)
      expect(result).to include('<img')
      expect(result).to include('src="http://test.host/captcha.png?len=5')
      expect(result).to include('<input')
      expect(result).to include('type="text"')
      expect(result).to include('name="captcha"')
    end

    it 'includes cursor-pointer style on the image' do
      result = helper_instance.cama_captcha_tag

      expect(result).to include(%(style="cursor: pointer;"))
    end

    it 'includes onclick handler that forces image reload with timestamp' do
      result = helper_instance.cama_captcha_tag

      expect(result).to include('onclick="this.src')
      expect(result).to include('new Date().getTime()')
    end

    it 'uses I18n translation for placeholder when none is provided' do
      I18n.backend.store_translations(:en, camaleon_cms: { captcha_placeholder: 'Type the code' })

      result = helper_instance.cama_captcha_tag

      expect(result).to include('placeholder="Type the code"')
    end

    it 'keeps an explicitly provided placeholder instead of the I18n default' do
      I18n.backend.store_translations(:en, camaleon_cms: { captcha_placeholder: 'Default' })

      result = helper_instance.cama_captcha_tag(5, { alt: '' }, { placeholder: 'My placeholder' })

      expect(result).to include('placeholder="My placeholder"')
      expect(result).not_to include('placeholder="Default"')
    end

    it 'falls back to I18n default when placeholder is an empty string' do
      I18n.backend.store_translations(:en, camaleon_cms: { captcha_placeholder: 'Default' })

      result = helper_instance.cama_captcha_tag(5, { alt: '' }, { placeholder: '' })

      expect(result).to include('placeholder="Default"')
    end

    it 'passes custom img_args attributes through to the image tag' do
      result = helper_instance.cama_captcha_tag(5, { alt: 'Verify', class: 'captcha-img' })

      expect(result).to include('alt="Verify"')
      expect(result).to include('class="captcha-img"')
    end

    it 'passes custom input_args attributes through to the input tag' do
      result = helper_instance.cama_captcha_tag(5, { alt: '' }, { class: 'form-control', id: 'captcha' })

      expect(result).to include('class="form-control"')
      expect(result).to include('id="captcha"')
    end

    context 'with bootstrap_group_mode enabled' do
      it 'wraps the image inside a div.input-group-append' do
        result = helper_instance.cama_captcha_tag(5, { alt: '' }, {}, true)

        expect(result).to include('input-group input-group-captcha')
        expect(result).to include(%(<div class="input-group-append"))
      end
    end

    context 'without bootstrap_group_mode' do
      it 'uses plain div.input-group-captcha without a span wrapper' do
        result = helper_instance.cama_captcha_tag

        expect(result).to include('class="input-group-captcha"')
        expect(result).not_to include('span')
      end
    end

    it 'includes a timestamp parameter in the image src for cache busting' do
      result = helper_instance.cama_captcha_tag

      # image_tag HTML-escapes & to &amp; in attrs
      expect(result).to match(%r{src="http://test\.host/captcha\.png\?len=5&amp;t=\d+"})
    end
  end
end
