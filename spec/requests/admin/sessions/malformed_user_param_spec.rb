# frozen_string_literal: true

# A scalar `user` param (`?user=foo`) is not a form submission; every session action must treat it
# as an empty submission instead of raising (String has no `permit`/`[]=` — previously a 500 on
# login, on the forgot send-email branch, and on register). Login and register re-render; forgot
# answers its uniform neutral redirect (M13), the same as any unmatched email.
RSpec.describe 'Malformed user param on session actions', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  it 'login re-renders with an error instead of failing' do
    post cama_admin_login_path, params: { user: 'foo' }

    expect(response).to have_http_status(:ok)
    expect(flash[:error]).to be_present
  end

  it 'forgot (send-email branch) answers the neutral redirect instead of failing' do
    post cama_admin_forgot_path, params: { user: 'foo' }

    expect(response).to redirect_to(cama_admin_login_path)
    expect(flash[:notice]).to be_present
    expect(flash[:error]).to be_blank
  end

  it 'register treats it as no submission instead of failing' do
    current_site.set_option('permit_create_account', true)

    post cama_admin_register_path, params: { user: 'foo' }

    expect(response).to have_http_status(:ok)
  end
end
