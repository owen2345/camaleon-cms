# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::ApplicationDecorator do
  init_site

  let(:decorated_post) { @post }
  let(:helper_context_class) do
    Class.new do
      def initialize(frontend_locale)
        @frontend_locale = frontend_locale
      end

      def cama_get_i18n_frontend
        @frontend_locale
      end
    end
  end
  let(:helper_context) { helper_context_class.new(:es) }

  around do |example|
    original_locale = I18n.locale
    example.run
    I18n.locale = original_locale
  end

  before do
    allow(decorated_post).to receive(:h).and_return(helper_context)
  end

  describe '#get_locale' do
    it 'uses an explicit locale when provided' do
      expect(decorated_post.get_locale(:es)).to eq(:es)
    end

    it 'uses the decoration locale before helper or I18n fallbacks' do
      decorated_post.set_decoration_locale(:fr)
      I18n.locale = :en

      expect(decorated_post.get_locale).to eq(:fr)
    end

    it 'uses the admin request frontend locale before I18n.locale' do
      I18n.locale = :en

      expect(decorated_post.get_locale).to eq(:es)
    end

    it 'falls back to I18n.locale when no frontend locale helper is exposed' do
      allow(decorated_post).to receive(:h).and_return(Object.new)
      I18n.locale = :en

      expect(decorated_post.get_locale).to eq(:en)
    end
  end

  describe '#_calc_locale' do
    it 'uses the admin request frontend locale when building route prefixes' do
      I18n.locale = :en

      expect(decorated_post.send(:_calc_locale, nil)).to eq('_es')
    end
  end

  describe CamaleonCms::AdminController do
    let(:controller_instance) { described_class.new }
    let(:site) { instance_double(CamaleonCms::Site, get_admin_language: :en, get_languages: %i[es en]) }

    it 'caches the frontend locale for admin helpers and decorators' do
      allow(controller_instance).to receive(:current_site).and_return(site)

      controller_instance.send(:admin_init_actions)

      expect(controller_instance.cama_get_i18n_frontend).to eq(:es)
    end
  end
end
