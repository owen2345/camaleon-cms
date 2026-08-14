# frozen_string_literal: true

require 'rails_helper'

include CamaleonCms::PluginsHelper

# Security (audit 2026-08-11 M6, follow-up to #1252): state-changing admin endpoints were plain GET
# routes, so a forged <img>/link could trash or restore posts, flip comment moderation, toggle or
# upgrade plugins, switch an admin's session to another user (impersonate), send mail, or end a
# session -- Rails' CSRF protection exempts GET (and HEAD) entirely. Each endpoint now acts only
# over its proper verb, carried by jquery_ujs data-method links or button_to forms. A GET to the
# old paths no longer matches an admin route (it falls through to the frontend catch-all and
# renders not-found) and, decisively, performs no state change. Logout answers a GET with a
# confirmation page instead -- frontend themes across the ecosystem link that path -- and ends the
# session only on POST.
RSpec.describe 'Security: destructive admin actions are not reachable over GET (M6)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user_admin, site: current_site, password: 'longenough1', password_confirmation: 'longenough1')
  end
  let(:post_type) { current_site.post_types.find_by(slug: 'post') }

  before { sign_in_as(admin_user, site: current_site) }

  describe 'posts trash and restore' do
    let!(:post_record) { create(:post, post_type: post_type, owner: admin_user) }

    it 'performs no state change over GET' do
      get "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/trash"

      expect(response).not_to have_http_status(:redirect) # the admin action would redirect
      expect(post_record.reload.status).not_to eq('trash')
    end

    it 'trashes and restores over PATCH' do
      patch "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/trash"
      expect(post_record.reload.status).to eq('trash')

      patch "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/restore"
      expect(post_record.reload.status).not_to eq('trash')
    end
  end

  describe 'comment moderation toggle' do
    let!(:post_record) { create(:post, post_type: post_type, owner: admin_user) }
    let!(:comment) do
      post_record.comments.create!(content: 'a comment', author: 'Guest', author_email: 'guest@example.com',
                                   approved: 'pending')
    end

    it 'performs no state change over GET' do
      get "/admin/posts/#{post_record.id}/comments/#{comment.id}/toggle_status", params: { s: 'a' }

      expect(comment.reload.approved).to eq('pending')
    end

    it 'flips the status over PATCH' do
      patch "/admin/posts/#{post_record.id}/comments/#{comment.id}/toggle_status", params: { s: 'a' }

      expect(comment.reload.approved).to eq('approved')
    end
  end

  describe 'plugin toggle and upgrade' do
    before { plugin_install('attack') }

    it 'performs no state change over GET' do
      get '/admin/plugins/toggle', params: { id: 'attack', status: 'true' }

      expect(current_site.plugins.active.pluck(:slug)).to include('attack') # still active
    end

    it 'deactivates a plugin over PATCH' do
      patch '/admin/plugins/toggle', params: { id: 'attack', status: 'true' }

      expect(response).to redirect_to(action: :index)
      expect(current_site.plugins.active.pluck(:slug)).not_to include('attack')
    end
  end

  describe 'user impersonation' do
    let!(:target) { create(:user, site: current_site) }

    it 'performs no session switch over GET' do
      get "/admin/users/#{target.id}/impersonate"

      get '/admin/profile/edit'
      expect(response.body).to include(admin_user.username)
      expect(response.body).not_to include(">#{target.username}<")
    end

    it 'switches the session over POST' do
      post "/admin/users/#{target.id}/impersonate"
      follow_redirect!

      get '/admin/profile/edit'
      expect(response.body).to include(target.username)
    end
  end

  describe 'test email' do
    it 'sends nothing over GET' do
      expect do
        get '/admin/settings/test_email', params: { email: 'x@example.com' }
      end.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'sends over POST' do
      post '/admin/settings/test_email', params: { email: 'x@example.com' }

      expect(response).to have_http_status(:ok).or have_http_status(:bad_gateway)
    end
  end

  describe 'logout' do
    it 'keeps the session on GET and shows a confirmation instead' do
      get '/admin/logout'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('You are about to end your session')

      get '/admin/profile/edit'
      expect(response).to have_http_status(:ok) # still signed in
    end

    it 'ends the session over POST' do
      post '/admin/logout'
      follow_redirect!

      get '/admin/profile/edit'
      expect(response).to redirect_to(cama_admin_login_path)
    end

    # Ecosystem themes (e_shop, efashion) link logout with return_to; the confirmation must carry
    # it into the POST, where the safe-redirect check vets it as on any logout.
    it 'carries return_to through the confirmation form' do
      get '/admin/logout', params: { return_to: 'http://www.example.com/somewhere' }

      expect(response.body).to include('return_to=http%3A%2F%2Fwww.example.com%2Fsomewhere')
    end
  end
end
