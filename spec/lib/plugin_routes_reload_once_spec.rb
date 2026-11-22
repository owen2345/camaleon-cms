# frozen_string_literal: true

RSpec.describe PluginRoutes do
  include CamaleonCms::PluginsHelper

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

    it 'leaves the draw to the end of the block for a language that a site loses' do
      @site.set_meta('languages_site', %w[en es])
      described_class.reload
      draws.clear

      described_class.reload_once do
        @site.set_meta('languages_site', %w[en])
        described_class.request_reload
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once for a language that replaces another language' do
      @site.set_meta('languages_site', %w[en es])
      described_class.reload
      draws.clear

      described_class.reload_once do
        @site.set_meta('languages_site', %w[en fr])
        described_class.request_reload
        expect(draws.size).to eq(1)
      end
    end

    it 'draws the routes at once for a theme that no site had at the last reload' do
      @site.set_option('_theme', 'camaleon_first')

      described_class.reload_once do
        described_class.request_reload
        expect(draws.size).to eq(1)
      end
    end

    it 'leaves the draw to the end of the block for a theme that another site has' do
      other_site = create(:site)
      @site.set_option('_theme', 'camaleon_first')
      described_class.reload
      draws.clear

      described_class.reload_once do
        other_site.set_option('_theme', 'camaleon_first')
        described_class.request_reload
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
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

    it 'draws the routes at once after a draw that raised an error' do
      allow(Rails.application).to receive(:reload_routes!).and_raise(ArgumentError, 'probe')
      expect { described_class.reload }.to raise_error(ArgumentError, 'probe')
      allow(Rails.application).to receive(:reload_routes!) { draws << :draw }

      described_class.reload_once do
        described_class.request_reload
        expect(draws.size).to eq(1)
      end
    end
  end

  describe 'the delete of a site' do
    let(:other_site) { create(:site) }

    # Makes the data of the example the data of the last reload.
    def count_draws_from_here
      described_class.reload
      draws.clear
    end

    it 'draws the routes one time outside a block' do
      other_site
      count_draws_from_here

      other_site.destroy

      expect(draws.size).to eq(1)
    end

    it 'leaves no route of a post type of the site after a delete outside a block' do
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
      helpers = other_site.post_types.pluck(:id).map { |id| :"cama_post_type_#{id}_path" }
      url_helpers = Rails.application.routes.url_helpers
      count_draws_from_here
      expect(helpers).to be_present
      expect(helpers.select { |helper| url_helpers.method_defined?(helper) }).to eq(helpers)

      other_site.destroy

      expect(draws.size).to eq(1)
      expect(helpers.select { |helper| url_helpers.method_defined?(helper) }).to be_empty
    end

    it 'draws the routes one time in a block when no site has the default theme' do
      [@site, other_site].each { |site| site.set_option('_theme', 'camaleon_first') }
      count_draws_from_here

      described_class.reload_once { other_site.destroy }

      expect(draws.size).to eq(1)
    end

    it 'draws the routes one time in a block when no site has the default language' do
      [@site, other_site].each { |site| site.set_meta('languages_site', %w[es]) }
      count_draws_from_here

      described_class.reload_once { other_site.destroy }

      expect(draws.size).to eq(1)
    end

    it 'draws the routes at once for a post type that is deleted with no delete of its site' do
      created = @site.post_types.create!(name: 'Books', slug: 'books')
      draws.clear

      created.destroy

      expect(draws.size).to eq(1)
    end
  end

  # A site asks for the reload after the commit of its transaction. A reload in the transaction reads
  # data that a rollback removes, and the list of get_sites keeps that data.
  describe 'a site that changes in a transaction' do
    let(:other_site) { create(:site) }

    def cached_site(site)
      described_class.get_sites.find { |cached| cached.id == site.id }
    end

    before do
      other_site
      described_class.reload
      draws.clear
    end

    it 'draws the routes one time for a new slug outside a transaction' do
      other_site.update!(slug: 'renamed.example.test')

      expect(draws.size).to eq(1)
      expect(cached_site(other_site).slug).to eq('renamed.example.test')
    end

    it 'draws no routes for a new slug that the transaction rolls back, and the list keeps the stored slug' do
      stored_slug = other_site.slug

      ActiveRecord::Base.transaction do
        other_site.update!(slug: 'renamed.example.test')
        raise ActiveRecord::Rollback
      end

      expect(draws).to be_empty
      expect(cached_site(other_site).slug).to eq(stored_slug)
    end

    it 'draws the routes one time, after the commit, when a second save follows the save of the new slug' do
      ActiveRecord::Base.transaction do
        other_site.update!(slug: 'renamed.example.test')
        other_site.update!(name: 'Renamed site')
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
      expect(cached_site(other_site)).to have_attributes(slug: 'renamed.example.test', name: 'Renamed site')
    end

    # For each row of a transaction, Rails runs the commit callbacks of one instance.
    it 'draws the routes one time when another instance saves the site after the save of the new slug' do
      ActiveRecord::Base.transaction do
        other_site.update!(slug: 'renamed.example.test')
        CamaleonCms::Site.find(other_site.id).update!(name: 'Renamed site')
      end

      expect(draws.size).to eq(1)
      expect(cached_site(other_site)).to have_attributes(slug: 'renamed.example.test', name: 'Renamed site')
    end

    it 'draws no routes for a second commit that changes no slug' do
      other_site.update!(slug: 'renamed.example.test')
      draws.clear

      other_site.update!(name: 'Renamed site')

      expect(draws).to be_empty
    end

    # The list is not loaded before the first read of get_sites in a process, or after a read that failed.
    it 'neither loads the list nor draws the routes for a new slug when the list is not loaded' do
      described_class.instance_variable_set(:@all_sites, nil)

      other_site.update!(slug: 'renamed.example.test')

      expect(draws).to be_empty
      expect(described_class.loaded_sites).to be_nil
      expect(cached_site(other_site).slug).to eq('renamed.example.test')
    end

    it 'draws no routes for a delete that the transaction rolls back, and the list keeps the site' do
      ActiveRecord::Base.transaction do
        other_site.destroy
        raise ActiveRecord::Rollback
      end

      expect(draws).to be_empty
      expect(cached_site(other_site)).to be_present
    end
  end

  # A new post type adds a route helper that a hook later in the transaction can call, so its draw
  # runs in the transaction. A new slug and a delete add no helper, so their draw waits for the commit.
  describe 'a post type that changes in a transaction' do
    it 'draws the routes one time, after the commit, for a new slug in a transaction' do
      ActiveRecord::Base.transaction do
        post_type.update!(slug: 'articles')
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end

    it 'draws the routes one time, right after the save, for a new slug outside a transaction' do
      post_type.update!(slug: 'articles')

      expect(draws.size).to eq(1)
    end

    it 'has the route of the new slug after the commit' do
      allow(Rails.application).to receive(:reload_routes!).and_call_original

      ActiveRecord::Base.transaction { post_type.update!(slug: 'articles') }

      route = Rails.application.routes.recognize_path('/articles')
      expect(route).to include(action: 'post_type', post_type_id: post_type.id)
    end

    it 'draws no routes for a new slug that the transaction rolls back' do
      ActiveRecord::Base.transaction do
        post_type.update!(slug: 'articles')
        raise ActiveRecord::Rollback
      end

      expect(draws).to be_empty
    end

    it 'draws no routes for a delete that the transaction rolls back, and the app keeps the route' do
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
      created = @site.post_types.create!(name: 'Books', slug: 'books')
      draws.clear

      ActiveRecord::Base.transaction do
        created.destroy
        raise ActiveRecord::Rollback
      end

      expect(draws).to be_empty
      expect(Rails.application.routes.url_helpers).to be_method_defined("cama_post_type_#{created.id}_path")
    end

    it 'draws the routes one time, after the commit, for a delete in a transaction' do
      created = @site.post_types.create!(name: 'Books', slug: 'books')
      draws.clear

      ActiveRecord::Base.transaction do
        created.destroy
        expect(draws).to be_empty
      end

      expect(draws.size).to eq(1)
    end
  end
end
