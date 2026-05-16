# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Decorator i18n locale resolution', type: :feature do
  let!(:site) { create(:site) }
  let!(:post) { create(:post, site: site) }

  describe 'ApplicationDecorator#get_locale priority chain' do
    let(:decorated_post) { post.decorate }

    it 'uses explicit locale when provided' do
      expect(decorated_post.get_locale(:es)).to eq(:es)
    end

    it 'uses set_decoration_locale when explicit not provided' do
      decorated_post.set_decoration_locale(:fr)
      expect(decorated_post.get_locale).to eq(:fr)
    end

    it 'falls back to I18n.locale as last resort' do
      expect(decorated_post.get_locale).to eq(I18n.locale)
    end
  end

  describe 'decorator locale usage: admin vs frontend contexts' do
    describe 'in frontend context' do
      it 'renders correct frontend language in page output (via I18n.locale)' do
        # Set site frontend language to 'es'
        site.set_meta('languages_site', ['es'])
        # Refresh cache to pick up new language
        site.instance_variable_set(:@_languages, nil)

        # Set I18n.locale to different value 'en' initially
        original_locale = I18n.locale
        begin
          I18n.locale = :en

          # Visit frontend - init_frontent will set I18n.locale to site's frontend language (:es)
          visit '/'
          expect(page.status_code).to eq(200)

          # Verify the page head renders correct locale (via the_head method)
          # This confirms I18n.locale was set to site's frontend language, not :en
          expect(page.html).to include('var LANGUAGE = "es";'),
                               "Expected page head to render LANGUAGE='es' (site's frontend language)"
        ensure
          I18n.locale = original_locale
        end
      end
    end
  end

  describe 'POST decorator URL generation' do
    it 'generates a valid URL without raising an error' do
      decorated_post = post.decorate
      url = decorated_post.the_url

      expect(url).to be_a(String)
      expect(url).not_to be_empty
    end

    context 'with site having specific frontend language' do
      it 'generates URL using available site languages' do
        site.get_languages

        decorated = post.decorate
        url = decorated.the_url

        # URL should be generated successfully
        expect(url).to be_a(String)
        # URL should exist
        expect(url.length).to be > 0
      end
    end
  end

  describe 'decorator locale resolution: verified via rendered output' do
    it 'renders correct I18n.locale in frontend page head (set to site frontend language)' do
      # Set the existing site to have English and Spanish as frontend languages
      site.set_meta('languages_site', [I18n.default_locale, :es])

      original_locale = I18n.locale
      begin
        # Set I18n.locale to English (site's first language)
        I18n.locale = :en

        # Visit the frontend home page - this triggers the controller's `before_action :init_frontent`,
        # which, if no params[:locale] || session[:cama_current_language] are present, initializes I18n.locale to the
        # site's first language (:en in this case)
        visit '/'

        # Verify page loaded successfully
        expect(page.status_code).to eq(200)

        # Verify the rendered output: the_head method renders var LANGUAGE = 'I18n.locale' in JavaScript
        # See: app/helpers/camaleon_cms/frontend/site_helper.rb line 63
        # This proves I18n.locale is set correctly to site's frontend language
        expected_language = site.get_languages.first.to_s
        expect(page.html).to include("var LANGUAGE = \"#{expected_language}\";"),
                             "Expected page head to render LANGUAGE='#{expected_language}' (site's frontend language)"

        # Additional verification: direct decorator test
        frontend_language = site.get_languages.first
        decorated = site.post_types.first&.posts&.first&.decorate
        if decorated.present?
          actual_locale = decorated.get_locale
          expect(actual_locale)
            .to eq(frontend_language),
                "Expected decorator to use site's frontend language (#{frontend_language}), but got #{actual_locale}"
        end
      ensure
        I18n.locale = original_locale
      end
    end

    it 'renders correct I18n.locale when user explicitly switches language' do
      site.set_meta('languages_site', [I18n.default_locale, :es])

      original_locale = I18n.locale
      begin
        # User clicks language switcher to switch to Spanish
        visit '/?cama_set_language=es'

        # Verify page loaded
        expect(page.status_code).to eq(200)

        # Verify the rendered head shows Spanish locale
        # This proves I18n.locale was set to user's chosen language
        expect(page.html).to include('var LANGUAGE = "es";'),
                             "Expected page head to render LANGUAGE='es' after user switched to Spanish"
      ensure
        I18n.locale = original_locale
      end
    end
  end
end
