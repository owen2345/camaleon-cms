# frozen_string_literal: true

require 'rails_helper'

# Pins the deliberate #1183 isolation (regression audit M30, kept by maintainer decision
# 2026-08-09): when an explicit `render prefixes:` list is ENTIRELY theme-scoped, the lookup is
# restricted to those prefixes and the controller/global `self.prefixes` are NOT merged, so a
# theme partial cannot reach another site's per-site-override or a plugin's views. A mixed list
# (theme + a non-theme prefix) still merges as before. The documented cost is that an
# explicit-prefix render whose template lives under a controller prefix raises MissingTemplate —
# this is intentional, not to be "fixed" by reopening the merge.
RSpec.describe 'ActionView theme-scoped lookup isolation', type: :model do
  let(:lookup_context) { ActionView::LookupContext.new([]) }
  let(:theme) { instance_double(CamaleonCms::Theme, slug: 'mytheme') }

  before { CurrentRequest.frontend_current_theme = theme }

  after { CurrentRequest.frontend_current_theme = nil }

  def scoped(prefixes)
    lookup_context.send(:cama_theme_scoped_prefixes, prefixes)
  end

  it 'restricts to the theme prefixes when the whole list is theme-scoped' do
    prefixes = ['themes/mytheme/views', 'camaleon_cms/default_theme']

    expect(scoped(prefixes)).to eq(prefixes)
  end

  it 'does not scope (merges as before) when a non-theme prefix is present' do
    prefixes = ['themes/mytheme/views', 'plugins/my_plugin/views']

    expect(scoped(prefixes)).to be_nil
  end

  it 'does not scope when there is no frontend theme' do
    CurrentRequest.frontend_current_theme = nil

    expect(scoped(['themes/mytheme/views'])).to be_nil
  end
end
