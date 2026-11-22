# frozen_string_literal: true

require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::Site, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[description]

  describe 'check metas relationships' do
    let!(:site) { create(:site).decorate }

    it 'creates metas with correct `object_class`' do
      front_cache_elements = site.metas.where(key: 'front_cache_elements').first

      expect(front_cache_elements.object_class).to eql('Site')
    end

    it 'does not leak metas from other object classes sharing the same object id' do
      # This guards against associations that only scope by objectid and ignore object_class.
      CamaleonCms::Meta.create!(
        objectid: site.id,
        object_class: 'UserRole',
        key: "leak-check-#{SecureRandom.hex(4)}",
        value: 'x'
      )

      expect(site.metas.where(object_class: 'UserRole')).to be_empty
    end
  end

  # get_languages kept its own memo of the languages_site meta, outside the record's memoized reads, so
  # a reload, a write on the same instance, and a copy all kept the list read first.
  describe '#get_languages' do
    let(:site) { create(:site) }

    it 'reads the languages stored through another instance after a reload' do
      expect(site.get_languages).not_to include(:fr)
      described_class.find(site.id).set_meta('languages_site', %w[en fr])

      expect(site.reload.get_languages).to eq(%i[en fr])
    end

    it 'reads the languages the same instance stores' do
      site.get_languages
      site.set_meta('languages_site', %w[en de])

      expect(site.get_languages).to eq(%i[en de])
    end

    it 'gives each caller its own list' do
      site.get_languages << :xx

      expect(site.get_languages).not_to include(:xx)
    end
  end

  # The memo of main_site stayed for the life of the process. After a new slug of the main site it
  # returned the old slug, and a read in a transaction kept a site that a rollback removed.
  describe '.main_site' do
    it 'returns the new slug of the main site after its save' do
      main = described_class.reorder(id: :asc).first || create(:site)
      expect(described_class.main_site.slug).to eq(main.slug)

      main.update!(slug: 'renamed-main.example.test')

      expect(described_class.main_site.slug).to eq('renamed-main.example.test')
    end

    # The routes hold the slug of the main site as their default host. A draw in the transaction reads
    # the old slug: from the memo, or before the save of the new slug. So the commit draws again.
    describe 'the default host of the routes' do
      let(:main) { described_class.reorder(id: :asc).first || create(:site) }
      let(:default_host) { Rails.application.routes.default_url_options[:host] }

      before do
        main
        PluginRoutes.reload
      end

      it 'is the new slug after a transaction that saves the slug and then draws the routes' do
        ActiveRecord::Base.transaction do
          main.update!(slug: 'renamed-main.example.test')
          main.post_types.create!(name: 'Books', slug: 'books')
        end

        expect(default_host).to eq('renamed-main.example.test')
      end

      it 'is the new slug after a transaction that draws the routes and then saves the slug' do
        ActiveRecord::Base.transaction do
          main.post_types.create!(name: 'Books', slug: 'books')
          main.update!(slug: 'renamed-main.example.test')
        end

        expect(default_host).to eq('renamed-main.example.test')
      end
    end

    it 'is the site with the lowest id, also when no site has the id 1' do
      described_class.delete_all
      described_class.instance_variable_set(:@main_site, nil)
      create(:site, id: 1_000_140)
      create(:site, id: 1_000_132)

      expect(described_class.main_site.id).to eq(1_000_132)
      expect(PluginRoutes.get_sites.first.id).to eq(1_000_132)
    end

    it 'returns nil after the create of the first site rolls back' do
      described_class.delete_all
      described_class.instance_variable_set(:@main_site, nil)

      ActiveRecord::Base.transaction do
        create(:site)
        expect(described_class.main_site).to be_present
        raise ActiveRecord::Rollback
      end

      expect(described_class.main_site).to be_nil
    end
  end
end
