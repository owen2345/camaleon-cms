# frozen_string_literal: true

# delete_meta removed a key's rows through a separate query and left the metas the record already held in
# memory: an instance with eager-loaded metas kept reading the deleted value, and a meta still waiting for
# the record's save was stored by that save.
RSpec.describe CamaleonCms::Meta, type: :model do
  describe '#delete_meta' do
    it 'stops returning a meta deleted from eager-loaded metas' do
      site = CamaleonCms::Site.first
      site.set_meta('retired_setting', 'old')
      loaded = CamaleonCms::Site.includes(:metas).find(site.id)

      loaded.delete_meta('retired_setting')

      expect(loaded.get_meta('retired_setting')).to be_nil
      expect(CamaleonCms::Site.find(site.id).get_meta('retired_setting')).to be_nil
    end

    it 'does not store a meta deleted before the record was first saved' do
      user = build(:user)
      user.set_meta('slogan', 'hi')

      user.delete_meta('slogan')
      expect(user.get_meta('slogan')).to be_nil

      user.save!
      expect(user.class.find(user.id).get_meta('slogan')).to be_nil
    end

    it 'does not store a pending meta deleted by a Symbol key' do
      post = create(:post)
      post.metas.build(key: 'subtitle', value: 'draft')

      post.delete_meta(:subtitle)
      post.save!

      expect(post.metas.where(key: 'subtitle')).to be_empty
    end
  end
end
