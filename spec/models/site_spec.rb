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
end
