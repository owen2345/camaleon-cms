# frozen_string_literal: true

# get_meta memoizes each meta a record reads. For a meta with no value it memoized the default of the first
# read, so later reads on the same instance returned that default, or the caller's in-place changes to it,
# instead of their own, while a freshly loaded record returned each read's own default.
RSpec.describe CamaleonCms::Post, type: :model do
  # the shared site's installed post type: a post created for it skips a post type's creation and route reload
  let(:post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }

  describe '#get_meta for a meta with no value' do
    it 'returns the default each read passes' do
      post = create(:post, post_type: post_type)

      expect(post.get_meta('gallery')).to be_nil
      expect(post.get_meta('gallery', [])).to eq([])
    end

    it 'returns the default each read passes from eager-loaded metas, without querying' do
      loaded = described_class.includes(:metas).find(create(:post, post_type: post_type).id)
      expect(loaded.metas).to be_loaded

      reads = nil
      selects = metas_selects { reads = [loaded.get_meta('gallery'), loaded.get_meta('gallery', [])] }

      expect(reads).to eq([nil, []])
      expect(selects).to be_empty
    end

    it 'does not return a default a caller changed in place' do
      post = create(:post, post_type: post_type)
      post.get_meta('gallery', []) << 'photo.jpg'

      expect(post.get_meta('gallery', [])).to eq([])
    end

    it 'returns the default each read passes for a meta stored as an empty string' do
      post = create(:post, post_type: post_type)
      post.metas.create!(key: 'gallery', value: '')
      stored = described_class.find(post.id)

      expect(stored.get_meta('gallery')).to be_nil
      expect(stored.get_meta('gallery', [])).to eq([])
    end

    it 'returns the default each read passes for a meta stored as null' do
      post = create(:post, post_type: post_type)
      post.metas.create!(key: 'gallery', value: nil)
      stored = described_class.find(post.id)

      expect(stored.get_meta('gallery')).to be_nil
      expect(stored.get_meta('gallery', [])).to eq([])
    end

    # The admin role form stores a null post-type permission meta when only manager boxes are checked, and
    # the next post type created on the site seeds that meta with a Hash default.
    it 'lets a post type be created for a site whose editor role stored a null post-type meta' do
      site = CamaleonCms::Site.first
      site.user_roles.find_by!(slug: 'editor').set_meta("_post_type_#{site.id}", nil)

      post_type = create(:post_type, site: site)

      permissions = site.user_roles.find_by!(slug: 'editor').get_meta("_post_type_#{site.id}", {})
      expect(permissions[:edit]).to eq([post_type.id])
    end

    it 'reads a missing meta from the database once per key' do
      post = described_class.find(create(:post, post_type: post_type).id)

      queries = metas_selects do
        post.get_meta('gallery')
        post.get_meta('gallery', [])
        post.get_meta('gallery', {})
        post.get_meta('thumb')
      end

      expect(queries.size).to eq(2)
    end
  end

  describe '#set_meta with nil or an empty string' do
    [nil, ''].each do |written|
      it "reads back #{written.inspect} as the default on the writing instance, as after a reload" do
        post = create(:post, post_type: post_type)
        post.set_meta('gallery', 'old.jpg')
        post.set_meta('gallery', written)

        expect(post.get_meta('gallery', [])).to eq([])
        expect(described_class.find(post.id).get_meta('gallery', [])).to eq([])
        expect(post.metas.pluck(:key, :value)).to eq([['gallery', written]])
      end
    end
  end

  describe '#get_option for an option with no value' do
    it 'returns the default for an option stored as null, as for an empty string' do
      post = create(:post, post_type: post_type)
      post.set_meta('_default', { color: nil, size: '' })
      stored = described_class.find(post.id)

      expect([post.get_option(:color, 'none'), post.get_option(:size, 'none')]).to eq(%w[none none])
      expect([stored.get_option(:color, 'none'), stored.get_option(:size, 'none')]).to eq(%w[none none])
    end
  end
end
