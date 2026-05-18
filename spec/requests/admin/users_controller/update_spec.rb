# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'users update request', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) { create(:user_admin, site: current_site, password: 'secret', password_confirmation: 'secret') }
  let(:target_user) { create(:user, site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::Admin::UsersController).to receive(:validate_role).and_return(true)

    sign_in_as(admin_user, site: current_site)
  end

  it 'updates avatar meta when a legacy demodulized owner type already exists' do
    CamaleonCms::Meta.new(
      key: 'avatar',
      value: '/uploads/original-avatar.jpg',
      object_class: 'User',
      objectid: target_user.id
    ).save!(validate: false)

    patch "/admin/users/#{target_user.id}",
          params: {
            user: {
              username: target_user.username,
              email: target_user.email,
              first_name: target_user.first_name,
              last_name: target_user.last_name
            },
            meta: {
              avatar: '/uploads/new-avatar.jpg',
              slogan: 'Updated slogan'
            }
          }

    expect(response).to redirect_to(action: :index)
    expect(target_user.reload.get_meta('avatar')).to eq('/uploads/new-avatar.jpg')
    expect(target_user.get_meta('slogan')).to eq('Updated slogan')
  end
end
