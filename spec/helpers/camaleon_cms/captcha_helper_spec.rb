# frozen_string_literal: true

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
        # Struct-based stub (mirrors session_captcha_runtime_concern_spec): RSpec doubles
        # are not available inside this plain class, only in example context.
        @current_site ||= Struct.new(:id, :max_try_attack) do
          def get_option(_key, default)
            max_try_attack || default
          end
        end.new(1, 5)
      end

      # the per-IP attack counter keys on the client IP; a plain stub is enough here
      def request
        @request ||= Struct.new(:remote_ip).new('127.0.0.1')
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

    it 'honors a string-keyed placeholder in input_args' do
      I18n.backend.store_translations(:en, camaleon_cms: { captcha_placeholder: 'Default' })

      result = helper_instance.cama_captcha_tag(5, { alt: '' }, { 'placeholder' => 'My placeholder' })

      expect(result).to include('placeholder="My placeholder"')
      expect(result).not_to include('placeholder="Default"')
    end

    it 'keeps a caller-supplied image style alongside the pointer cursor' do
      result = helper_instance.cama_captcha_tag(5, { alt: '', style: 'border: 1px solid red;' })

      expect(result).to include('cursor: pointer;')
      expect(result).to include('border: 1px solid red;')
    end

    context 'with bootstrap_group_mode enabled' do
      it 'wraps the image inside a span.input-group-btn' do
        result = helper_instance.cama_captcha_tag(5, { alt: '' }, {}, true)

        expect(result).to include('input-group input-group-captcha')
        expect(result).to include(%(<span class="input-group-btn"))
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

  describe '#cama_captcha_verified?' do
    it 'accepts the issued challenge (case-insensitively) and consumes it so it cannot be replayed' do
      helper_instance.session[:cama_captcha] = ['ABCDE']
      helper_instance.params[:captcha] = 'abcde'

      expect(helper_instance.cama_captcha_verified?).to be(true)
      # single-use: the solved challenge is cleared, so the same value no longer verifies
      expect(helper_instance.cama_captcha_verified?).to be(false)
    end

    it 'rejects a value that does not match the issued challenge' do
      helper_instance.session[:cama_captcha] = ['ABCDE']
      helper_instance.params[:captcha] = 'ZZZZZ'

      expect(helper_instance.cama_captcha_verified?).to be(false)
    end

    it 'rejects a blank submission even if the session somehow holds a blank challenge' do
      helper_instance.session[:cama_captcha] = ['']
      helper_instance.params[:captcha] = ''

      expect(helper_instance.cama_captcha_verified?).to be(false)
    end
  end

  describe '#captcha_verify_if_under_attack' do
    it 'passes without consuming the pending challenge when the key is not under attack' do
      helper_instance.session[:cama_captcha] = ['ABCDE']

      expect(helper_instance.captcha_verify_if_under_attack('login')).to be(true)
      # the challenge still belongs to whatever form issued it
      expect(helper_instance.session[:cama_captcha]).to eq(['ABCDE'])
    end

    it 'accepts a correct captcha while under attack without resetting the counter' do
      helper_instance.session['cama_captcha_login'] = 6
      helper_instance.session[:cama_captcha] = ['ABCDE']
      helper_instance.params[:captcha] = 'ABCDE'

      expect(helper_instance.captcha_verify_if_under_attack('login')).to be(true)
      # a solve alone must not clear the throttle: only the caller's explicit
      # cama_captcha_reset_attack after a real success does
      expect(helper_instance.session['cama_captcha_login']).to eq(6)
      expect(helper_instance.cama_captcha_under_attack?('login')).to be(true)
    end

    it 'rejects a wrong captcha while under attack' do
      helper_instance.session['cama_captcha_login'] = 6
      helper_instance.session[:cama_captcha] = ['ABCDE']
      helper_instance.params[:captcha] = 'NOPE1'

      expect(helper_instance.captcha_verify_if_under_attack('login')).to be(false)
    end
  end

  describe '#cama_captcha_increment_attack' do
    it 'increments the per-IP counter via an ATOMIC cache increment (guards the lost-update fix)' do
      # A plain read-then-write would race and lose updates under concurrent failures from one IP;
      # pin that the atomic primitive is used, not Rails.cache.write.
      expect(Rails.cache).to receive(:increment).and_call_original

      helper_instance.cama_captcha_increment_attack('login')

      expect(helper_instance.cama_captcha_attack_ip_count('login')).to eq(1)
    end

    it 'accumulates the per-IP counter across successive failures' do
      3.times { helper_instance.cama_captcha_increment_attack('login') }

      expect(helper_instance.cama_captcha_attack_ip_count('login')).to eq(3)
    end
  end

  describe '#cama_captcha_reset_attack' do
    it 'clears the per-IP counter so a user who finally succeeds is no longer throttled' do
      2.times { helper_instance.cama_captcha_increment_attack('login') }
      expect(helper_instance.cama_captcha_attack_ip_count('login')).to eq(2)

      helper_instance.cama_captcha_reset_attack('login')

      expect(helper_instance.cama_captcha_attack_ip_count('login')).to eq(0)
      expect(helper_instance.session['cama_captcha_login']).to eq(0)
    end
  end
end
