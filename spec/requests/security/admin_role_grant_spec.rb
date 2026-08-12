# frozen_string_literal: true

require 'rails_helper'

# H10 — holding :manage, :users must not be a path to controlling admin accounts. role_grantor? only
# checked for the :manage, :users capability, so a non-admin user manager could set role: 'admin' on a
# created or edited account (admin? is exactly role == 'admin'), minting an admin and escalating
# themselves — and could equally strip an existing admin's role. Granting the admin role, or changing the
# role of a user who is already an admin, now requires being an admin; a user manager keeps every
# non-admin grant.
RSpec.describe 'Security: only admins may grant the admin role (H10)', type: :request do
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
end
