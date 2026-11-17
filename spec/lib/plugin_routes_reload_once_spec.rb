# frozen_string_literal: true

include CamaleonCms::PluginsHelper

RSpec.describe PluginRoutes do
  init_site

  let(:draws) { [] }
  let(:post_type) { @site.post_types.find_by!(slug: 'post') }

  # Each example counts the draws, and the draw itself is a stub. The reload of this hook makes the
  # data of the example the data of the last reload.
  before do
    current_site(@site)
    allow(Rails.application).to receive(:reload_routes!) { draws << :draw }
    described_class.reload
    draws.clear
  end

  describe '.request_reload' do
    it 'reloads the routes at once outside a block' do
      described_class.request_reload

      expect(draws.size).to eq(1)
    end
  end

  describe '.reload_once' do
    it 'returns the value of the block' do
      expect(described_class.reload_once { :value }).to eq(:value)
    end

    it 'does not draw the routes when no call asks for a draw' do
      described_class.reload_once { nil }

      expect(draws).to be_empty
    end

    it 'draws the routes one time at the end of the block for two calls that add no route' do
      described_class.reload_once do
        2.times { described_class.request_reload }
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end

    it 'clears the caches at once' do
      described_class.cache_variable('probe', 'old')

      described_class.reload_once do
        described_class.request_reload
        expect(described_class.cache_variable('probe')).to be_nil
      end
    end

    it 'draws the routes at once for a new post type, and its route helper exists in the block' do
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end

      described_class.reload_once do
        created = @site.post_types.create!(name: 'Books', slug: 'books')
        expect(draws.size).to eq(1)
        expect(Rails.application.routes.url_helpers).to be_method_defined("cama_post_type_#{created.id}_path")
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once for a new slug of a post type' do
      post_type.update_column(:slug, 'articles') # rubocop:disable Rails/SkipsModelValidations

      described_class.reload_once do
        described_class.request_reload
        expect(draws.size).to eq(1)
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once for a new language of a site' do
      @site.set_meta('languages_site', %w[en es])

      described_class.reload_once do
        described_class.request_reload
        expect(draws.size).to eq(1)
      end
    end

    it 'leaves the draw to the end of the block for a post type that the block deletes' do
      described_class.reload_once do
        post_type.delete
        described_class.request_reload
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes before the hooks of a plugin that no site had at the last reload' do
      draws_before_hooks = nil
      allow(self).to receive(:hook_run) { draws_before_hooks ||= draws.size }

      described_class.reload_once { plugin_install('visibility_post') }

      expect(draws_before_hooks).to eq(1)
      expect(draws.size).to eq(1)
    end

    it 'leaves the draw to the end of the block for a plugin that the last reload had' do
      @site.plugins.find_by!(slug: 'attack').inactive
      draws_before_hooks = nil
      allow(self).to receive(:hook_run) { draws_before_hooks ||= draws.size }

      described_class.reload_once { plugin_install('attack') }

      expect(draws_before_hooks).to eq(0)
      expect(draws.size).to eq(1)
    end

    it 'does not draw again at the end of the block after a PluginRoutes.reload in the block' do
      described_class.reload_once do
        described_class.request_reload
        described_class.reload
        expect(draws.size).to eq(1)
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes one time when the block raises an error, and the caller gets the error' do
      expect do
        described_class.reload_once do
          described_class.request_reload
          raise ArgumentError, 'probe'
        end
      end.to raise_error(ArgumentError, 'probe')

      expect(draws.size).to eq(1)
    end

    it 'leaves the draw of an inner block to the outer block' do
      described_class.reload_once do
        described_class.reload_once { described_class.request_reload }
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once for a call on another thread' do
      described_class.reload_once do
        Thread.new { described_class.request_reload }.join
        expect(draws.size).to eq(1)
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once before the first reload of the process' do
      described_class.instance_variable_set(:@drawn_route_inputs, nil)

      described_class.reload_once do
        described_class.request_reload
        expect(draws.size).to eq(1)
      end
    end
  end
end
