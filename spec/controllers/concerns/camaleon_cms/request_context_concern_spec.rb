# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::RequestContextConcern do
  let(:runtime_class) do
    Class.new do
      include CamaleonCms::RequestContextConcern

      attr_reader :prepended_paths

      def initialize
        @prepended_paths = []
      end

      def request
        @request ||= Struct.new(:env).new({ 'HTTP_X_FORWARDED_HOST' => 'evil.example' })
      end

      def prepend_view_path(path)
        @prepended_paths << path
      end

      def cama_current_user
        :user
      end

      def current_site
        :site
      end
    end
  end

  let(:runtime) { runtime_class.new }

  it 'assigns @current_site for legacy theme template compatibility' do
    runtime.send(:configure_runtime_request_context)

    expect(runtime.instance_variable_get(:@current_site)).to eq(:site)
  end
end
