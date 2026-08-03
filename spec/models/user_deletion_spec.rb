# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User deletion content reassignment', type: :model do
  let(:site) { CamaleonCms::Site.first }
  let(:post_type) { site.post_types.find_by(slug: 'post') }
  let(:author) { create(:user) }
  let(:commenter) { create(:user) }
  let(:post_record) do
    post_type.add_post(title: 'Deletion fixture', slug: 'deletion-fixture-post', content: 'body',
                       user_id: author.id)
  end

  it "reassigns the deleted user's comments to the site's anonymous user" do
    comment = post_record.comments.create!(user_id: commenter.id, content: 'nice post', approved: 'approved')

    commenter.destroy!

    expect(comment.reload.user_id).to eq(site.get_anonymous_user.id)
  end

  it 'keeps comment rendering working after the author is deleted' do
    comment = post_record.comments.create!(user_id: commenter.id, content: 'nice post', approved: 'approved')

    commenter.destroy!

    expect(comment.reload.decorate.the_author_name).to include('Anonymous')
  end

  it "does not destroy the deleted user's widgets" do
    widget = site.widgets.create!(name: 'Deletion widget', slug: 'deletion-widget-x', user_id: commenter.id)

    commenter.destroy!

    expect(CamaleonCms::Widget::Main.exists?(widget.id)).to be(true)
  end

  it "moves the deleted user's posts to a surviving admin" do
    admin = site.users.admin_scope.first
    post_record

    author.destroy!

    expect(post_record.reload.user_id).to eq(admin.id)
  end

  describe 'orphan tolerance' do
    it 'renders a blank author instead of raising when the user is missing' do
      comment = post_record.comments.create!(user_id: commenter.id, content: 'orphan me', approved: 'approved')
      comment.update_column(:user_id, nil) # rubocop:disable Rails/SkipsModelValidations

      decorated = comment.reload.decorate

      expect { decorated.the_author_name }.not_to raise_error
      expect(decorated.the_user).to be_nil
    end
  end
end
