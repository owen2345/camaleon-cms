# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::FrontendController do
  describe 'frontend application helper compatibility' do
    let(:controller) { described_class.new }
    let(:plugin_controller_class) { Class.new(described_class) }

    it 'calls cama_url_to_fixed from the frontend controller' do
      allow(controller).to receive_messages(current_site: nil, request: nil, cama_current_site_host_port: nil)
      controller.define_singleton_method(:compatibility_path) { |_options = {}| '/compatibility' }

      expect { controller.cama_url_to_fixed('compatibility_path') }.not_to raise_error
      expect(controller.cama_url_to_fixed('compatibility_path')).to eq('/compatibility')
    end

    it 'calls verify_front_visibility from an inheriting plugin-style controller' do
      plugin_controller = plugin_controller_class.new
      relation = double(visible_frontend: :visible)
      allow(plugin_controller).to receive(:hooks_run)

      expect { plugin_controller.verify_front_visibility(relation) }.not_to raise_error
      expect(plugin_controller.verify_front_visibility(relation)).to eq(:visible)
    end
  end

  describe 'frontend visited-state concern integration' do
    let(:controller) { described_class.new }
    let(:post) { instance_double(CamaleonCms::Post) }
    let(:user) { instance_double(CamaleonCms::User) }

    before do
      CurrentRequest.reset
      if described_class.instance_variable_defined?(:@_warned_frontend_legacy_visited_ivars)
        described_class.remove_instance_variable(:@_warned_frontend_legacy_visited_ivars)
      end
    end

    after do
      CurrentRequest.reset
      if described_class.instance_variable_defined?(:@_warned_frontend_legacy_visited_ivars)
        described_class.remove_instance_variable(:@_warned_frontend_legacy_visited_ivars)
      end
    end

    it 'stores visited post in CurrentRequest and legacy ivar' do
      expect(ActiveSupport::Deprecation._instance).to receive(:warn).with(
        include('Controller compatibility ivar @cama_visited_post is deprecated')
      )
      controller.send(:mark_frontend_post_visited, post)

      expect(CurrentRequest.frontend_visited_post).to eq(post)
      expect(controller.instance_variable_get(:@cama_visited_post)).to eq(post)
    end

    it 'stores visited profile and frontend user context' do
      expect(ActiveSupport::Deprecation._instance).to receive(:warn).with(
        include('Controller compatibility ivar @cama_visited_profile is deprecated')
      )
      controller.send(:mark_frontend_profile_visited, user)

      expect(CurrentRequest.frontend_visited_profile).to be(true)
      expect(CurrentRequest.frontend_user).to eq(user)
      expect(controller.instance_variable_get(:@cama_visited_profile)).to be(true)
    end

    it 'warns once per legacy compatibility ivar per controller class' do
      expect(ActiveSupport::Deprecation._instance).to receive(:warn).once.with(
        include('Controller compatibility ivar @cama_visited_post is deprecated')
      )

      controller.send(:mark_frontend_post_visited, post)
      controller.send(:mark_frontend_post_visited, post)
    end

    it 'stores frontend breadcrumbs in request state' do
      controller.breadcrumb_add('Search', '/search')

      expect(CurrentRequest.theme_helper_state[:front_breadcrumb]).to eq([['Search', '/search']])
    end
  end

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

    it 'keeps the active theme, per-site override and default fallback prefixes' do
      controller.send(:configure_frontend_lookup_prefixes)

      expect(lookup_context.prefixes).to include('themes/camaleon_cms/views')
      expect(lookup_context.prefixes).to include('themes/132/views')
      expect(lookup_context.prefixes.last).to eq('camaleon_cms/default_theme')
    end

    it 'gives the per-site override precedence over the active theme views' do
      controller.send(:configure_frontend_lookup_prefixes)

      expect(lookup_context.prefixes.index('themes/132/views'))
        .to be < lookup_context.prefixes.index('themes/camaleon_cms/views')
    end

    it 'skips the per-site override prefix when the site folder does not exist' do
      allow(Dir).to receive(:exist?).and_return(false)

      controller.send(:configure_frontend_lookup_prefixes)

      expect(lookup_context.prefixes).not_to include('themes/132/views')
      expect(lookup_context.prefixes).to include('themes/camaleon_cms/views')
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
