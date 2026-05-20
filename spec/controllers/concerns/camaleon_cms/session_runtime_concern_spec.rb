# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SessionRuntimeConcern do
  let(:runtime_class) do
    Class.new do
      include CamaleonCms::SessionRuntimeConcern

      attr_reader :redirect_target

      def cama_root_path
        '/root'
      end

      def redirect_to(target)
        @redirect_target = target
      end
    end
  end

  let(:runtime) { runtime_class.new }

  it 'keeps auth session error redirect behavior' do
    runtime.auth_session_error

    expect(runtime.redirect_target).to eq('/root')
  end

  it 'keeps captcha methods available through the session runtime concern' do
    expect(runtime).to respond_to(
      :captcha_verify_if_under_attack,
      :cama_captcha_under_attack?,
      :cama_captcha_verified?,
      :cama_captcha_increment_attack,
      :cama_captcha_reset_attack,
      :cama_captcha_total_attacks,
      :cama_captcha_tags_if_under_attack
    )
  end
end
