# frozen_string_literal: true

# `restore` wrote the post's stored `status_default` straight into its status, whatever that value was
# and whatever the post's state, checking only that the user may update the post. A contributor without
# the publish permission could store `options[status_default]=published` through the post save and
# then restore the post to publish it.
RSpec.describe 'Security: post restore status', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:contributor) { create(:user, role: 'contributor', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def post_owned_by(user, status:, status_default: nil)
    record = post_type.posts.create!(title: "Post of #{user.username}", slug: "post-#{user.id}-#{status}",
                                     content: 'body', user_id: user.id, status: status)
    record.set_option('status_default', status_default) if status_default
    record
  end

  def restore(record)
    patch "/admin/post_type/#{post_type.id}/posts/#{record.id}/restore"
  end

  it 'does not let a contributor publish by saving a restore status and restoring' do
    sign_in_as(contributor, site: current_site)
    post "/admin/post_type/#{post_type.id}/posts",
         params: { post: { title: 'Contributor post', slug: 'contributor-post', content: 'body', status: 'published' },
                   options: { status_default: 'published' } }
    record = post_type.posts.find_by(slug: 'contributor-post')

    restore(record) if record

    expect(post_type.posts.published.where(slug: 'contributor-post')).to be_empty
  end

  it "returns a non-publisher's trashed post as pending, whatever its stored status" do
    sign_in_as(contributor, site: current_site)
    record = post_owned_by(contributor, status: 'trash', status_default: 'published')

    restore(record)

    expect(record.reload.status).to eq('pending')
  end

  it "returns a publisher's trashed post to its published status" do
    sign_in_as(editor, site: current_site)
    record = post_owned_by(editor, status: 'trash', status_default: 'published')

    restore(record)

    expect(record.reload.status).to eq('published')
  end

  it 'leaves a post outside the trash untouched and says so' do
    sign_in_as(editor, site: current_site)
    record = post_owned_by(editor, status: 'pending', status_default: 'published')

    restore(record)

    expect(record.reload.status).to eq('pending')
    expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.post.message.restore_not_in_trash',
                                       post_type: post_type.decorate.the_title))
  end

  it 'restores a missing or unrecognised stored status as pending' do
    sign_in_as(editor, site: current_site)
    unrecognised = post_owned_by(editor, status: 'trash', status_default: 'bogus')
    missing = post_type.posts.create!(title: 'No stored status', slug: 'no-stored-status', content: 'body',
                                      user_id: editor.id, status: 'trash')

    restore(unrecognised)
    restore(missing)

    expect(unrecognised.reload.status).to eq('pending')
    expect(missing.reload.status).to eq('pending')
  end
end
