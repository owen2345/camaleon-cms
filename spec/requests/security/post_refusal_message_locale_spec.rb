# frozen_string_literal: true

# The refusal messages embed the submitted key name. Under an admin language other than English (whose
# locale file lacks these keys), the message resolves through the English fallback. That fallback was
# interpolated with the vars and then interpolated again, so a submitted key carrying a `%{...}` token
# (e.g. `meta[_%{x}]`, which the `_` rule refuses) raised I18n::MissingInterpolationArgument -- a 500
# instead of the refusal. The fallback must be interpolated once.
RSpec.describe 'Security: refusal message under a non-English admin locale', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let!(:published_post) do
    create(:post, post_type: post_type, owner: editor, slug: 'published-post', status: 'published')
  end
  # A reserved (`_`-prefixed) key whose name carries a format token; a literal key, not a template.
  let(:reserved_key) { '_%{x}' } # rubocop:disable Style/FormatStringToken
  let(:expected_message) { "meta[#{reserved_key}] is maintained by Camaleon CMS and cannot be submitted." }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    current_site.set_option('_admin_theme', 'es') # admin language with no translation for the refusal keys
  end

  after { I18n.locale = :en }

  it 'refuses a placeholder-bearing reserved key without raising' do
    sign_in_as(editor, site: current_site)

    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                    meta: { reserved_key => '1' } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(expected_message)
  end
end
