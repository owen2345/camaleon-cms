# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SessionCaptchaRuntimeConcern do
  let(:runtime_class) do
    Class.new do
      include CamaleonCms::SessionCaptchaRuntimeConcern

      def session
        @session ||= {}
      end

      def params
        @params ||= {}
      end

      def current_site
        @current_site ||= Struct.new(:max_try_attack) do
          def get_option(_key, default)
            max_try_attack || default
          end
        end.new(5)
      end

      def cama_captcha_tag(*)
        'captcha-tag'
      end
    end
  end

  let(:runtime) { runtime_class.new }

  it 'tracks attack count and renders tag only when threshold exceeded' do
    6.times { runtime.cama_captcha_increment_attack('login') }

    expect(runtime.cama_captcha_total_attacks('login')).to eq(6)
    expect(runtime.cama_captcha_under_attack?('login')).to eq(true)
    expect(runtime.cama_captcha_tags_if_under_attack('login')).to eq('captcha-tag')
  end

  it 'verifies captcha value using request params' do
    runtime.session[:cama_captcha] = ['ABC12']
    runtime.params[:captcha] = 'abc12'

    expect(runtime.cama_captcha_verified?).to eq(true)
  end
end
