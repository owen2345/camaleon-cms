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
end
