# frozen_string_literal: true

# `set_metas` and `set_options` iterate whatever container they are handed key by key, and several
# admin saves pass request params to them unchecked. An array container (`meta[]=x`) reached
# `Array#to_sym` and 500ed the category, tag, site and theme saves, and a JSON array of pairs to the
# site settings was written row by row past every hash-shaped check. The writers now refuse a
# container that is not a set of fields, and an admin save answers with a message instead of a 500.
# The post save keeps refusing such a container before any write, now for `field_options` too.
RSpec.describe 'Security: meta and option containers outside the post save', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def refused
    I18n.t('camaleon_cms.admin.message.malformed_fields')
  end

  it 'answers a category save carrying an array meta with a message, storing no option' do
    post "/admin/post_type/#{post_type.id}/categories",
         params: 'category[name]=Probe+cat&category[slug]=probe-cat&meta[]=x',
         headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

    expect(response).to have_http_status(:found)
    expect(flash[:error]).to eq(refused)
    expect(post_type.categories.find_by(slug: 'probe-cat')&.options).to be_blank
  end

  it 'answers a site settings save carrying a JSON array of pairs with a message, storing none of them' do
    languages_before = CamaleonCms::Site.find(current_site.id).get_meta('languages_site')

    patch '/admin/settings/site_saved',
          params: { site: { name: current_site.name, slug: current_site.slug, description: 'd' },
                    metas: [%w[languages_site probe_lang]] }.to_json,
          headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:found)
    expect(flash[:error]).to eq(refused)
    expect(CamaleonCms::Site.find(current_site.id).get_meta('languages_site')).to eq(languages_before)
  end

  it 'refuses a post save whose field_options is not a set of fields, like meta and options' do
    published = create(:post, post_type: post_type, owner: admin, slug: 'container-post', status: 'published')

    patch "/admin/post_type/#{post_type.id}/posts/#{published.id}",
          params: 'post[title]=Changed&post[content]=body&post[status]=published&field_options=foo',
          headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('camaleon_cms.admin.post.message.malformed_group', group: 'field_options'))
    expect(published.reload.title).not_to eq('Changed')
  end
end
