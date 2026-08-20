# frozen_string_literal: true

require 'rails_helper'

# Regression: sprockets-rails >= 3.5 registers `Sprockets::Rails::AssetUrlProcessor`, which rewrites
# relative `url(...)` references in CSS to digested asset paths. TinyMCE's bundled skin references its
# icon font with directory-relative urls (e.g. `url('fonts/tinymce.woff')`). Sprockets resolves
# `url()` paths against the asset load roots (not the referencing file's own directory), so the
# default processor cannot find them and rewrites them to an invalid root path (`/fonts/...`) that
# 404s, breaking the editor toolbar icons in development.
#
# We cannot disable the processor globally because other stylesheets (e.g. Bootstrap glyphicons) rely
# on it. `config/initializers/assets.rb` swaps it for a subclass that, for the TinyMCE skin only,
# expands the directory-relative font urls into full logical asset paths before delegating to the
# original processor, so they resolve to proper digested paths while every other stylesheet is
# processed unchanged.
RSpec.describe 'TinyMCE skin asset urls', type: :request do
  let(:skin_css) { Rails.application.assets&.find_asset('tinymce/skins/lightgray/skin.min.css') }

  before { skip('Sprockets is not serving assets in this environment') if skin_css.nil? }

  it 'replaces the default AssetUrlProcessor with the tinymce-safe subclass' do
    expect(Rails.application.config.assets.compile).to be(true)
    registered = (Sprockets.postprocessors['text/css'] || []).map(&:to_s)
    expect(registered).to include(a_string_matching(/TinymceSkinSafeAssetUrlProcessor/))
    expect(registered).not_to include('Sprockets::Rails::AssetUrlProcessor')
  end

  it 'rewrites the skin font urls to resolvable digested asset paths (icons load in development)' do
    # The relative reference must be gone, replaced by a digested path under the skin directory.
    expect(skin_css.source).not_to match(%r{url\(["']?(?:\./)?fonts/tinymce\.woff})
    expect(skin_css.source).not_to match(%r{url\(["']?/fonts/tinymce\.woff})
    expect(skin_css.source)
      .to match(%r{url\(/assets/tinymce/skins/lightgray/fonts/tinymce-[0-9a-f]+\.woff\)})
  end

  it 'exposes the icon font as a resolvable asset' do
    expect(Rails.application.assets.find_asset('tinymce/skins/lightgray/fonts/tinymce.woff')).not_to be_nil
  end

  it 'expands directory-relative skin font urls to full logical paths before delegating' do
    env = Rails.application.assets
    css = 'a{src:url("fonts/tinymce.woff")}'
    input = { environment: env, filename: skin_css.filename, data: css,
              name: skin_css.logical_path, content_type: 'text/css', metadata: {} }
    out = TinymceSkinSafeAssetUrlProcessor.call(input)
    expect(out[:data]).to match(%r{url\(/assets/tinymce/skins/lightgray/fonts/tinymce-[0-9a-f]+\.woff\)})
  end
end
