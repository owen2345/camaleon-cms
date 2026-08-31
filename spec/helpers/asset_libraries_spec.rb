# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #15, and the earlier I1): the on-demand asset library table
# (cama_load_libraries / add_asset_library) is declared TWICE -- in CamaleonCms::HtmlHelper and,
# byte-for-byte, in CamaleonCms::RuntimeHtmlContentConcern (the controller-side copy). Several
# entries pointed at logical paths Sprockets can never resolve (tinymce.min, form/jquery.form,
# bootstrap-select.js), so cama_load_libraries('tinymce'|'form_ajax'|'multiselect') -- reachable
# through the documented `[load_libraries data='...']` shortcode -- raised
# Sprockets::Rails::Helper::AssetNotFound from cama_draw_custom_assets. Pin that EVERY declared path
# in EVERY entry of BOTH copies resolves under its declared kind, so a rename cannot silently break
# one caller path while the suite stays green.
RSpec.describe 'on-demand asset libraries' do # rubocop:disable RSpec/DescribeClass -- spans HtmlHelper and the controller concern copy
  def unresolved_paths(libs)
    missing = []
    libs.each do |name, lib|
      Array(lib[:js]).each { |p| missing << "#{name} js:#{p}" unless Rails.application.assets["#{p}.js"] }
      Array(lib[:css]).each { |p| missing << "#{name} css:#{p}" unless Rails.application.assets["#{p}.css"] }
    end
    missing
  end

  before { CurrentRequest.reset }

  describe 'CamaleonCms::HtmlHelper#cama_assets_libraries', type: :helper do
    it 'declares only paths that resolve in the asset environment' do
      helper.cama_html_helpers_init
      expect(unresolved_paths(helper.send(:cama_assets_libraries))).to be_empty
    end
  end

  describe 'CamaleonCms::RuntimeHtmlContentConcern#cama_assets_libraries (controller copy)' do
    it 'declares only paths that resolve in the asset environment' do
      controller = CamaleonCms::FrontendController.new
      expect(unresolved_paths(controller.send(:cama_assets_libraries))).to be_empty
    end
  end
end
