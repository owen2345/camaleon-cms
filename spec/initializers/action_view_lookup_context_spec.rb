# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionView::LookupContext do
  let(:lookup_context) { described_class.new(ActionController::Base.view_paths) }
  let(:view_paths) { instance_double(ActionView::PathSet) }

  before do
    lookup_context.use_camaleon_partial_prefixes = true
    lookup_context.prefixes = ['themes/132/views', 'themes/camaleon_cms/views']
    lookup_context.instance_variable_set(:@view_paths, view_paths)
    allow(CurrentRequest).to receive(:frontend_current_theme).and_return(instance_double(CamaleonCms::Theme,
                                                                                         slug: 'camaleon_cms'))
    allow(lookup_context).to receive(:cama_args_for_lookup) do |name, prefixes, partial, keys, _options|
      [name, prefixes, partial, {}, nil, keys]
    end
  end

  it 'keeps explicit prefixes first when finding partials' do
    expect(view_paths).to receive(:find) do |_name, prefixes, _partial, _details, _details_key, _keys|
      expect(prefixes.first).to eq('themes/camaleon_cms/views/home')
      expect(prefixes).not_to include('themes/132/views')
    end

    lookup_context.find('home/banner', ['themes/camaleon_cms/views/home'], true, [], {})
  end

  it 'adds global prefixes when no explicit prefixes are provided' do
    expect(view_paths).to receive(:find) do |_name, prefixes, _partial, _details, _details_key, _keys|
      expect(prefixes).to include('themes/132/views')
      expect(prefixes).to include('themes/camaleon_cms/views')
    end

    lookup_context.find('index', [], false, [], {})
  end

  it 'merges global prefixes (incl. the plugin views prefix) when a plugin renders its own template' do
    # Mirrors the runtime lookup for `/store/plugins/<id>` => `render 'detail'`: the explicit
    # prefixes Rails passes are a *mix* of the plugin's controller prefixes and the theme
    # prefixes (so the lookup is NOT entirely theme-scoped), while `self.prefixes` also holds
    # the `plugins/store/views/plugins` prefix that `init_plugin` prepends. That prefix must
    # survive so the plugin template is found (instead of raising MissingTemplate).
    lookup_context.prefixes = ['plugins/store/views/plugins', 'plugins/store/plugins', 'plugins/store/front',
                               'themes/132/views', 'themes/camaleon_cms/views', 'camaleon_cms/default_theme']
    passed = ['plugins/store/plugins', 'plugins/store/front', 'themes/132/views', 'themes/camaleon_cms/views',
              'camaleon_cms/default_theme']

    expect(view_paths).to receive(:find) do |_name, prefixes, _partial, _details, _details_key, _keys|
      expect(prefixes).to include('plugins/store/views/plugins')
      expect(prefixes).to include('themes/camaleon_cms/views')
    end

    lookup_context.find('detail', passed, false, [], {})
  end
end
