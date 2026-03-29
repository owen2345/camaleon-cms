require 'rails_helper'

describe 'Admin AJAX select_eval permission enforcement', :js do
  init_site

  let(:site) { Cama::Site.first }

  it 'denies toggling select_eval for user without permission' do
    # create a normal user without privileges
    user = create(:user, role: 'client', site: site)
    admin_sign_in(user.username, '12345678')

    # call ajax toggle path (GET) as this user
    visit "#{cama_root_relative_path}/admin/ajax?mode=toggle_select_eval&value=1&cama_ajax_request=true"

    # The toggle endpoint is now a no-op; ensure it does not expose admin errors
    # and that the site option remains unchanged (default false)
    expect(page).not_to have_content('Error')
    site.reload
    expect(site.get_option('show_select_eval_in_ui')).to be_falsey
  end
  # The ability to toggle select_eval via /admin/ajax is intentionally removed.
end
