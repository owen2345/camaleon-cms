# frozen_string_literal: true

# M6: `custom_fields#list` is a read-named action routed as GET, but it also writes — it calls
# `post.update_categories(params[:categories])`. With `categories` omitted, that resolves to `[]` and
# `update_categories` destroys every one of the post's category relationships. Because CSRF protection
# does not cover GET and the SameSite=Lax auth cookie rides a top-level navigation, a bare
# `GET /admin/settings/custom_fields/list?post_id=42` from an attacker page wipes post 42's categories.
# The category write is now performed only on a POST — the sole verb on this route that Rails' CSRF
# verification covers, since verified_request? exempts HEAD exactly like GET.
RSpec.describe 'Security: custom_fields#list category write requires a CSRF-verified POST (M6)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:category) { post_type.categories.create!(name: 'Cat A', slug: 'cat-a') }
  let!(:the_post) do
    post_type.posts.create!(title: 'Sample', slug: 'sample-m6', user_id: admin.id, categories: [category])
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  it "does not strip a post's categories on a bare GET" do
    expect(the_post.categories.pluck(:id)).to eq([category.id])

    get '/admin/settings/custom_fields/list', params: { post_id: the_post.id }

    expect(the_post.reload.categories.pluck(:id)).to eq([category.id])
  end

  it "does not strip a post's categories on a HEAD, which Rails also exempts from CSRF verification" do
    expect(the_post.categories.pluck(:id)).to eq([category.id])

    head '/admin/settings/custom_fields/list', params: { post_id: the_post.id }

    expect(the_post.reload.categories.pluck(:id)).to eq([category.id])
  end

  it 'still updates the categories on a POST' do
    other = post_type.categories.create!(name: 'Cat B', slug: 'cat-b')

    post '/admin/settings/custom_fields/list', params: { post_id: the_post.id, categories: [other.id] }

    expect(the_post.reload.categories.pluck(:id)).to eq([other.id])
  end
end
