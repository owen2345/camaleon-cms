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
end
