# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review): the :post asset library declared
# "camaleon_cms/admin/jquery.tagsinput.min" — a logical path Sprockets can
# never resolve to the underscore-prefixed files this engine ships, and a name
# that went stale for good once the minified bundle was replaced by the
# vendored source. Downstream callers of cama_load_libraries('post') would hit
# Sprockets::FileNotFound from cama_draw_custom_assets.
# Every logical path the library declares must resolve in the asset
# environment under its declared kind.
RSpec.describe CamaleonCms::HtmlHelper, type: :helper do
  describe ':post library' do
    it 'declares the vendored tagsinput and post assets' do
      helper.cama_html_helpers_init
      library = helper.send(:cama_assets_libraries)[:post]

      expect(library).to include(
        js: %w[camaleon_cms/admin/_jquery.tagsinput camaleon_cms/admin/_post],
        css: ['camaleon_cms/admin/_jquery.tagsinput']
      )
    end

    it 'resolves every declared asset in the Sprockets environment' do
      helper.cama_html_helpers_init
      library = helper.send(:cama_assets_libraries)[:post]

      resolved = (library[:js].map { |p| "#{p}.js" } + library[:css].map { |p| "#{p}.css" }).map do |path|
        Rails.application.assets[path]
      end

      expect(resolved).to all(be_present),
                          'unresolvable logical paths would raise Sprockets::FileNotFound at render'
    end
  end
end
