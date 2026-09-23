# frozen_string_literal: true

# A meta set on a record before its first save is only built in memory, and the metas autosave inserts
# it after the record's after_create callbacks. The after-create save of data_options must update that
# pending meta, not insert a second row with the same key beside it.
RSpec.describe CamaleonCms::Post, type: :model do
  let(:post_type) { create(:post_type) }

  it 'stores one options row for options set before and while creating the record' do
    post = build(:post, post_type: post_type, data_options: { has_comments: true })
    post.set_option('has_picture', false)
    post.save!

    expect(post.metas.where(key: '_default').count).to eq(1)
    stored = described_class.find(post.id)
    expect(stored.get_option(:has_picture)).to be(false)
    expect(stored.get_option(:has_comments)).to be(true)
  end

  # A record not saved yet has no stored rows, so the metas built on it are all it holds: they are read, not
  # looked for in the database, which cannot hold them.
  it 'reads the metas built on a record not saved yet' do
    post = build(:post, post_type: post_type)
    post.metas.build(key: 'subtitle', value: 'built')

    expect(post.get_meta('subtitle', 'none')).to eq('built')
  end

  # A write on a record not saved yet looks the key's meta up by loading the association, which holds every meta
  # such a record has, so once saved the record reads its metas from memory instead of querying for each key.
  it 'reads its metas from memory after a first save that followed a write' do
    post = build(:post, post_type: post_type)
    post.set_meta('subtitle', 'written')
    post.save!

    selects = metas_selects { expect([post.get_meta('subtitle'), post.get_meta('absent')]).to eq(['written', nil]) }

    expect(selects).to be_empty
  end

  # A creation rolled back leaves the record unsaved, with the metas it wrote built again for its next save.
  it 'reads the metas built again once its creation is rolled back' do
    created = build(:post_type, data_metas: { icon_color: 'queued' }, data_options: { has_category: true })
    rolled_back_transaction { created.save! }

    expect(created).to be_new_record
    expect([created.get_meta('icon_color', 'none'), created.get_option(:has_category, 'none')]).to eq(['queued', true])
  end
end
