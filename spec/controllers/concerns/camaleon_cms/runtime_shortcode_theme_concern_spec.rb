# frozen_string_literal: true

require 'rails_helper'

# The concern copy of shortcode_asset_reference / resolve_shortcode_theme_asset must stay in lockstep
# with the CamaleonCms::ShortCodeHelper twin. Two drifts had crept in (regression L17): the concern
# assigned the locals its rescue branch uses after the resolve call instead of first, and its path
# regex did not tolerate a leading slash.
RSpec.describe CamaleonCms::RuntimeShortcodeThemeConcern do
  let(:host) { Class.new { include CamaleonCms::RuntimeShortcodeThemeConcern }.new }

  describe '#shortcode_asset_reference' do
    it 'falls back through skip_pipeline when AssetNotFound is forced at the resolve step' do
      # Ordering-invariant guard, not a reproduction of a real failure:
      # resolve_shortcode_theme_asset never raises AssetNotFound itself (regex, string
      # interpolation and File.exist? only), so the stub forces the raise at the earliest
      # point to pin the rescue's locals being assigned first.
      allow(host).to receive(:resolve_shortcode_theme_asset)
        .and_raise(Sprockets::Rails::Helper::AssetNotFound)

      expect(host.shortcode_asset_reference('foo.png', as_path: true)).to eq('/foo.png')
    end
  end

  describe '#resolve_shortcode_theme_asset' do
    it 'tolerates a leading slash in the theme asset path (regex parity with the helper)' do
      allow(host).to receive_messages(current_theme: instance_double(CamaleonCms::Theme),
                                      theme_asset_path: 'themes/active/assets/img/a.png',
                                      theme_asset_file_path: '/tmp/a.png')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/a.png').and_return(true)

      expect(host.send(:resolve_shortcode_theme_asset, '/themes/orig/assets/img/a.png'))
        .to eq('themes/active/assets/img/a.png')
    end
  end
end
