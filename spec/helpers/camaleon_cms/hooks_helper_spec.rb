# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::HooksHelper do
  let(:helper_class) do
    Class.new do
      include CamaleonCms::HooksHelper

      attr_accessor :current_site, :current_theme
    end
  end

  let(:helper) { helper_class.new }
  let(:site) { instance_double(CamaleonCms::Site, get_theme_slug: 'camaleon_cms') }
  let(:theme) { instance_double(CamaleonCms::Theme, slug: 'cv') }
  let(:theme_plugin) { { 'key' => 'cv', 'hooks' => { 'front_before_load' => ['cv_front_before_load'] } } }

  before do
    helper.current_site = site
    helper.current_theme = theme
    allow(PluginRoutes).to receive(:enabled_apps).with(site, 'cv').and_return([theme_plugin])
    allow(PluginRoutes).to receive(:get_anonymous_hooks).and_return([])
    allow(helper).to receive(:send)
  end

  it 'loads hooks from the current preview theme' do
    expect(PluginRoutes).to receive(:enabled_apps).with(site, 'cv')

    helper.hooks_run('front_before_load')
  end
end
