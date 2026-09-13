# frozen_string_literal: true

RSpec.describe CamaleonCms::Meta, type: :model do
  describe 'value preservation' do
    it 'preserves angle brackets in Meta#value' do
      site = create(:site)
      meta = described_class.create!(objectid: site.id, object_class: 'Site', key: 'test_key', value: 'count < 10')
      expect(meta.reload.value).to eq('count < 10')
    end

    it 'preserves email addresses with angle brackets through set_option/get_option round-trip' do
      site = create(:site)
      site.set_option('email_from', 'My Name <myemail@domain.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('My Name <myemail@domain.com>')
    end

    it 'preserves angle brackets in JSON-serialized meta values' do
      site = create(:site)
      site.set_options(email_from: 'Admin <admin@test.com>', email_cc: 'Support <support@test.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('Admin <admin@test.com>')
      expect(fresh_site.get_option('email_cc')).to eq('Support <support@test.com>')
    end
  end

  describe '#get_meta with an eager-loaded metas association' do
    # PluginRoutes.get_sites eager-loads :metas, so route-draw reads take get_meta's in-memory
    # branch. That branch must normalize a Symbol key the same way the DB branch does, otherwise
    # 'a_key' == :a_key is always false and the stored value is silently replaced by the default.
    it 'resolves a Symbol key against the loaded metas instead of returning the default' do
      site = create(:site)
      site.set_meta('languages_site', %w[en es])

      loaded = CamaleonCms::Site.includes(:metas).find(site.id)
      expect(loaded.metas).to be_loaded

      expect(loaded.get_meta(:languages_site)).to eq(%w[en es])
    end
  end

  describe 'hash metas read back on the instance that wrote them' do
    # A fresh load parses a stored hash into an indifferent hash, so the instance that wrote it must
    # read it back the same way. A post type's after_create writes its defaults with Symbol keys; a
    # String-keyed set_option on that instance must replace :has_category, not add "has_category"
    # beside it (json 3 refuses to generate the duplicate, json 2 stored both).
    it 'stores a String-keyed option once after Symbol-keyed defaults' do
      post_type = create(:post_type)
      post_type.set_option('has_category', true)

      stored = post_type.metas.find_by!(key: '_default').value
      expect(stored.scan('"has_category"').size).to eq(1)
      expect(post_type.get_option(:has_category)).to be(true)
      expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_category)).to be(true)
    end

    it 'returns the hash a fresh load returns' do
      post_type = create(:post_type)
      post_type.set_meta('probe_settings', { color: 'red' })

      expect(post_type.get_meta('probe_settings')).to eq(CamaleonCms::PostType.find(post_type.id).get_meta('probe_settings'))
    end
  end
end
