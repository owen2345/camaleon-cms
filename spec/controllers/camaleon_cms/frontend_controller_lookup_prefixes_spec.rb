# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::FrontendController do
  describe '#configure_frontend_lookup_prefixes' do
    let(:controller) { described_class.new }
    let(:site) { instance_double(CamaleonCms::Site, id: 132) }
    let(:theme) { instance_double(CamaleonCms::Theme, slug: 'camaleon_cms') }
    let(:lookup_context) do
      Class.new do
        attr_accessor :prefixes, :use_camaleon_partial_prefixes
      end.new
    end

    before do
      lookup_context.prefixes = ['frontend', 'application', 'themes/old/views']
      allow(controller).to receive_messages(current_site: site, current_theme: theme, lookup_context: lookup_context)
      allow(Dir).to receive(:exist?).and_return(true)
    end

    it 'only keeps the active theme and default fallback prefixes' do
      controller.send(:configure_frontend_lookup_prefixes)

      expect(lookup_context.prefixes).to include('themes/camaleon_cms/views')
      expect(lookup_context.prefixes).not_to include('themes/132/views')
      expect(lookup_context.prefixes.last).to eq('camaleon_cms/default_theme')
    end
  end

  describe '#ensure_preview_site_defaults' do
    let(:controller) { described_class.new }
    let(:site) { instance_double(CamaleonCms::Site) }
    let(:nav_menus) { instance_double(ActiveRecord::Relation) }
    let(:main_menu_scope) { instance_double(ActiveRecord::Relation) }
    let(:footer_menu_scope) { instance_double(ActiveRecord::Relation) }

    before do
      allow(controller).to receive_messages(current_site: site,
                                            preview_required_menu_slugs: %w[
                                              main_menu eshop_footer_main_menu
                                            ])
      allow(site).to receive(:nav_menus).and_return(nav_menus)
      allow(nav_menus).to receive(:where).with(slug: 'main_menu').and_return(main_menu_scope)
      allow(nav_menus).to receive(:where).with(slug: 'eshop_footer_main_menu').and_return(footer_menu_scope)
      allow(main_menu_scope).to receive(:first_or_create!)
      allow(footer_menu_scope).to receive(:first_or_create!)
    end

    it 'ensures required preview menus exist' do
      expect(main_menu_scope).to receive(:first_or_create!)
      expect(footer_menu_scope).to receive(:first_or_create!)

      controller.send(:ensure_preview_site_defaults)
    end
  end

  describe '#extract_menu_slugs_from_template' do
    let(:controller) { described_class.new }

    it 'extracts menu slugs declared as strings and arrays' do
      template = <<~ERB
        <% current_site.nav_menus.where(slug: 'eshop_footer_main_menu').first.children %>
        <% current_site.nav_menus.where(slug: [\"eshop_header_main_menu\", 'main_menu']).last.children %>
      ERB

      slugs = controller.send(:extract_menu_slugs_from_template, template)

      expect(slugs).to include('eshop_footer_main_menu', 'eshop_header_main_menu', 'main_menu')
    end
  end
end
