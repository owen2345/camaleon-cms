# frozen_string_literal: true

# The draft autosave shares the post save's meta/option refusals. Two things must hold: a refused save
# writes nothing (draft create looked up the buffer and stamped draft_status through set_option before
# the check ran), and the check guards the same container the writer stores -- create wrote its options
# from params[:keywords] (always nil) while checking params[:options], so it refused options it never
# stored. Create now stores params[:options] like update, and both check before any write.
RSpec.describe 'Security: draft save refusals', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let!(:parent) { create(:post, post_type: post_type, owner: editor, status: 'published') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(editor, site: current_site)
  end

  def create_draft(extra = {})
    post "/admin/post_type/#{post_type.id}/drafts",
         params: { post_id: parent.id, post: { title: 'Draft title' } }.merge(extra)
    JSON.parse(response.body)
  end

  def buffer
    CamaleonCms::Post.find(post_type.posts.drafts.where(post_parent: parent.id).first.id)
  end

  it 'writes nothing when a create on an existing buffer is refused' do
    create_draft # a first autosave creates the buffer (draft_status unset)
    buffer_id = buffer.id

    body = create_draft(meta: { _x: '1' })

    expect(body['error']).to be_present
    expect(CamaleonCms::Post.find(buffer_id).get_option('draft_status')).to be_blank
  end

  it 'stores a submitted option on the buffer' do
    create_draft(options: { seo_title: 'SEO' })

    expect(buffer.get_option('seo_title')).to eq('SEO')
  end

  it 'refuses a reserved option on a draft update and stores nothing' do
    create_draft
    buffer_id = buffer.id

    patch "/admin/post_type/#{post_type.id}/drafts/#{buffer_id}",
          params: { post: { title: 'Draft title' }, options: { status_default: 'published' } }

    expect(JSON.parse(response.body)['error']).to be_present
    expect(CamaleonCms::Post.find(buffer_id).get_option('status_default')).to be_blank
  end
end
