# frozen_string_literal: true

# H10 — holding :manage, :users must not be a path to controlling admin accounts. role_grantor? only
# checked for the :manage, :users capability, so a non-admin user manager could set role: 'admin' on a
# created or edited account (admin? is exactly role == 'admin'), minting an admin and escalating
# themselves — and could equally strip an existing admin's role. Granting the admin role, or changing the
# role of a user who is already an admin, now requires being an admin; a user manager keeps every
# non-admin grant.
#
# The same threat also has a non-role path: a user manager who could reset an admin's password would sign
# in as them, and one who could repoint an admin's email would hijack a password-reset link. Editing an
# admin's password or recovery identifiers (email/username) therefore requires being an admin too, via
# UserDecorator#may_edit_credentials? applied in #user_params and #updated_ajax. A manager keeps full
# control of non-admin accounts and of their own.
RSpec.describe 'Security: only admins may control admin accounts (H10)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  # a non-admin who can manage users but is not an admin
  let(:users_role) { current_site.user_roles.create!(name: 'User manager', slug: 'user-mgr-h10') }
  let(:manager) { create(:user, role: users_role.slug, site: current_site) }
  let(:admin) { create(:user_admin, site: current_site) }

  before { users_role.set_meta("_manager_#{current_site.id}", { 'users' => 1 }) }

  def create_user_as(actor, role:)
    sign_in_as(actor, site: current_site)
    tag = SecureRandom.hex(4)
    post cama_admin_users_path, params: { user: {
      first_name: 'New', last_name: 'User', email: "h10_#{tag}@tester.com", username: "h10_#{tag}",
      password: 'password123', password_confirmation: 'password123', role: role
    } }
    current_site.users.find_by(username: "h10_#{tag}")
  end

  it 'does not let a non-admin user manager mint an admin account' do
    created = create_user_as(manager, role: 'admin')

    expect(created).to be_present
    expect(created.role).not_to eq('admin')
  end

  it 'does not let a non-admin user manager promote an existing user to admin' do
    victim = create(:user, role: 'client', site: current_site)
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_path(victim), params: { user: { role: 'admin' } }

    expect(victim.reload.role).not_to eq('admin')
  end

  it 'does not let a non-admin user manager strip an existing admin of their role' do
    target_admin = create(:user_admin, site: current_site)
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_path(target_admin), params: { user: { role: 'client' } }

    expect(target_admin.reload.role).to eq('admin')
  end

  it 'still lets a non-admin user manager grant a non-admin role' do
    created = create_user_as(manager, role: users_role.slug)

    expect(created.role).to eq(users_role.slug)
  end

  it 'still lets an admin grant the admin role' do
    created = create_user_as(admin, role: 'admin')

    expect(created.role).to eq('admin')
  end

  it 'still lets an admin change another admin role' do
    target_admin = create(:user_admin, site: current_site)
    sign_in_as(admin, site: current_site)

    patch cama_admin_user_path(target_admin), params: { user: { role: 'client' } }

    expect(target_admin.reload.role).to eq('client')
  end

  # --- the non-role path to an admin account: password and recovery identifiers ---

  it 'does not let a non-admin user manager reset an existing admin password' do
    target_admin = create(:user_admin, site: current_site) # factory password is '12345678'
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_path(target_admin),
          params: { user: { password: 'pwned_password', password_confirmation: 'pwned_password' } }

    target_admin.reload
    expect(target_admin.authenticate('pwned_password')).to be_falsey
    expect(target_admin.authenticate('12345678')).to be_truthy
  end

  it 'does not let a non-admin user manager change an existing admin email' do
    target_admin = create(:user_admin, site: current_site)
    original_email = target_admin.email
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_path(target_admin), params: { user: { email: 'attacker@tester.com' } }

    expect(target_admin.reload.email).to eq(original_email)
  end

  it 'does not let a non-admin user manager reset an admin password through updated_ajax' do
    target_admin = create(:user_admin, site: current_site)
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_updated_ajax_path(target_admin),
          params: { password: { password: 'pwned_password', password_confirmation: 'pwned_password' } }

    expect(response).to have_http_status(:forbidden)
    expect(target_admin.reload.authenticate('pwned_password')).to be_falsey
  end

  it 'still lets a non-admin user manager reset a non-admin user password' do
    victim = create(:user, role: 'client', site: current_site)
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_updated_ajax_path(victim),
          params: { password: { password: 'new_secret', password_confirmation: 'new_secret' } }

    expect(response).to have_http_status(:no_content)
    expect(victim.reload.authenticate('new_secret')).to be_truthy
  end

  it 'still lets a user change their own password through updated_ajax' do
    sign_in_as(manager, site: current_site)

    patch cama_admin_user_updated_ajax_path(manager),
          params: { password: { password: 'my_new_secret', password_confirmation: 'my_new_secret' } }

    expect(response).to have_http_status(:no_content)
    expect(manager.reload.authenticate('my_new_secret')).to be_truthy
  end

  it 'still lets an admin reset another admin password' do
    target_admin = create(:user_admin, site: current_site)
    sign_in_as(admin, site: current_site)

    patch cama_admin_user_path(target_admin),
          params: { user: { password: 'new_secret', password_confirmation: 'new_secret' } }

    expect(target_admin.reload.authenticate('new_secret')).to be_truthy
  end

  # A malformed nested role param (user[role][x]=admin) makes params[:user][:role] an unpermitted
  # Parameters; without coercion it reaches mass-assignment and raises, 500-ing the request.
  it 'ignores a malformed nested role param instead of raising' do
    victim = create(:user, role: 'client', site: current_site)
    sign_in_as(admin, site: current_site)

    patch cama_admin_user_path(victim), params: { user: { role: { 'x' => 'admin' } } }

    expect(response).to have_http_status(:found) # a normal redirect, not a 500
    expect(victim.reload.role).to eq('client')
  end
end
