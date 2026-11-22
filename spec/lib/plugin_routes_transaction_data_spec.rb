# frozen_string_literal: true

# PluginRoutes keeps the site list and the values of cache_variable for all threads. A read in a
# transaction can give data that is not committed. That data stays with the thread of the transaction,
# and a rollback leaves nothing of it behind.
RSpec.describe PluginRoutes do
  init_site

  let(:url_helpers) { Rails.application.routes.url_helpers }

  # The site list as another thread reads it, with no load: the list that all threads share.
  def shared_sites
    Thread.new { described_class.loaded_sites }.value
  end

  def post_type_ids(sites)
    sites.flat_map { |site| site.post_types.map(&:id) }
  end

  def route_helper(post_type_id)
    :"cama_post_type_#{post_type_id}_path"
  end

  before { described_class.reload }

  describe 'a post type that a transaction creates' do
    it 'is in the list of its thread, and not in the list of the other threads, until the commit' do
      created = nil

      ActiveRecord::Base.transaction do
        created = @site.post_types.create!(name: 'Books', slug: 'books')

        expect(url_helpers).to be_method_defined(route_helper(created.id))
        expect(post_type_ids(described_class.get_sites)).to include(created.id)
        expect(post_type_ids(shared_sites)).not_to include(created.id)
      end

      expect(post_type_ids(described_class.get_sites)).to include(created.id)
      expect(post_type_ids(shared_sites)).to include(created.id)
    end

    it 'leaves no route and no entry of the list after a rollback' do
      created_id = nil

      ActiveRecord::Base.transaction do
        created_id = @site.post_types.create!(name: 'Books', slug: 'books').id
        expect(url_helpers).to be_method_defined(route_helper(created_id))
        raise ActiveRecord::Rollback
      end

      expect(url_helpers).not_to be_method_defined(route_helper(created_id))
      expect(post_type_ids(described_class.get_sites)).not_to include(created_id)
    end
  end

  describe 'a site that a transaction creates' do
    it 'leaves no site in the list and no route of its post types after a rollback' do
      site_id = nil
      post_type_ids = nil

      ActiveRecord::Base.transaction do
        site = create(:site)
        site_id = site.id
        post_type_ids = site.post_types.pluck(:id)
        raise ActiveRecord::Rollback
      end

      expect(post_type_ids).to be_present
      expect(post_type_ids.select { |id| url_helpers.method_defined?(route_helper(id)) }).to be_empty
      expect(described_class.get_sites.map(&:id)).not_to include(site_id)
    end
  end

  describe 'a read of the list while it is not loaded' do
    let(:other_site) { create(:site) }

    def slug_in(sites)
      sites.find { |site| site.id == other_site.id }.slug
    end

    it 'stays with the thread of the transaction, and a rollback leaves the stored slug' do
      stored_slug = other_site.slug
      described_class.instance_variable_set(:@all_sites, nil)

      ActiveRecord::Base.transaction do
        other_site.update!(slug: 'renamed.example.test')

        expect(slug_in(described_class.get_sites)).to eq('renamed.example.test')
        expect(shared_sites).to be_nil
        raise ActiveRecord::Rollback
      end

      expect(slug_in(described_class.get_sites)).to eq(stored_slug)
    end
  end

  describe '.cache_variable' do
    it 'keeps a value that a transaction stores with the thread of the transaction' do
      ActiveRecord::Base.transaction do
        described_class.cache_variable('probe', 'in the transaction')

        expect(described_class.cache_variable('probe')).to eq('in the transaction')
        expect(Thread.new { described_class.cache_variable('probe') }.value).to be_nil
      end

      expect(described_class.cache_variable('probe')).to be_nil
    end

    it 'reads a value from before the transaction in the transaction' do
      described_class.cache_variable('probe', 'before')

      ActiveRecord::Base.transaction do
        expect(described_class.cache_variable('probe')).to eq('before')
      end
    end
  end

  describe '.reload_after_commit' do
    let(:draws) { [] }

    before do
      allow(Rails.application).to receive(:reload_routes!) { draws << :draw }
      described_class.reload
      draws.clear
    end

    it 'reloads the routes at once when no transaction is open' do
      described_class.reload_after_commit

      expect(draws.size).to eq(1)
    end

    # No site and no post type is saved here, so the next call of PluginRoutes does the reload.
    it 'draws the routes one time, after the commit, for two requests in a transaction' do
      ActiveRecord::Base.transaction do
        2.times { described_class.reload_after_commit }
        expect(draws).to be_empty
      end

      described_class.get_sites

      expect(draws.size).to eq(1)
    end

    it 'asks for no reload when the transaction rolls back' do
      ActiveRecord::Base.transaction do
        described_class.reload_after_commit
        raise ActiveRecord::Rollback
      end

      described_class.get_sites

      expect(draws).to be_empty
    end

    it 'clears the cached data of the thread at once' do
      described_class.cache_variable('probe', 'old')

      ActiveRecord::Base.transaction do
        described_class.reload_after_commit

        expect(described_class.cache_variable('probe')).to be_nil
      end
    end
  end
end
