# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security: XSS Vulnerabilities Fixes', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first_or_create!(name: 'Post') }
  let(:malicious_payload) { '<span>alert(1)</span>' }
  let(:escaped_payload) { ERB::Util.html_escape(malicious_payload) }
  let(:json_escaped_payload) { '\\u003cspan\\u003ealert(1)\\u003c/span\\u003e' }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
    current_site.set_option('custom_fields_show_shortcodes', true)
  end

  describe 'Custom Fields and Shortcodes' do
    it 'escapes field names and field options' do
      group = current_site
              .custom_field_groups.create!(
                name: malicious_payload, object_class: 'PostType_Post', objectid: post_type.id,
                slug: "malicious-group-#{SecureRandom.hex(4)}"
              )
      group.add_field({ name: malicious_payload, slug: 'test-field' }, { field_key: 'text_box' })

      get '/admin/settings/custom_fields/list', params: {
        post_type: post_type.id,
        field_options: {
          '0' => {
            'helper' => { 'values' => { '0' => malicious_payload } }
          }
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
      expect(response.body).to include(json_escaped_payload)

      # Test Finding 10: Custom Fields Index
      get '/admin/settings/custom_fields'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end

    it 'includes auto-select JavaScript attributes in shortcodes' do
      group = current_site
              .custom_field_groups.create!(
                name: 'Test Group', object_class: 'PostType_Post', objectid: post_type.id,
                slug: "test-group-#{SecureRandom.hex(4)}"
              )
      group.add_field({ name: 'Test Field', slug: 'test-field' }, { field_key: 'text_box' })

      get '/admin/settings/custom_fields/list', params: {
        post_type: post_type.id
      }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('onmousedown="this.clicked = 1;"')
      expect(response.body).to include('onfocus="if (!this.clicked) this.select(); else this.clicked = 2;"')
      expect(response.body).to include('onclick="if (this.clicked == 2) this.select(); this.clicked = 0;"')
      expect(response.body).to include('readonly="readonly"')
      expect(response.body).to match(/class="[^"]*code_style[^"]*"/)
    end
  end

  describe 'Comments' do
    it 'escapes author name' do
      my_post = post_type.posts.create!(title: 'Test Post', slug: 'test-post', user_id: admin.id)
      # Associate with admin user and set malicious first name
      admin.update!(first_name: malicious_payload, last_name: '')
      my_post.comments.create!(
        content: 'Test comment', author: 'Attacker', author_email: 'a@b.com', approved: 'approved', user_id: admin.id
      )

      get "/admin/posts/#{my_post.id}/comments"

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/#{Regexp.escape(escaped_payload)}/i)
    end
  end

  describe 'Taxonomies' do
    it 'escapes category and tag names' do
      cat = post_type.categories.create!(name: malicious_payload, slug: "malicious-cat-#{SecureRandom.hex(4)}")
      tag = post_type.post_tags.create!(name: malicious_payload, slug: "malicious-tag-#{SecureRandom.hex(4)}")
      my_post = post_type.posts.create!(
        title: 'Post with Malicious Cat', slug: "malicious-post-#{SecureRandom.hex(4)}", user_id: admin.id,
        categories: [cat], post_tags: [tag]
      )

      # Categories index (Finding 1)
      get "/admin/post_type/#{post_type.id}/categories"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)

      # Tags index (Finding 4)
      get "/admin/post_type/#{post_type.id}/post_tags"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)

      # Post list (Finding 6 - categories/tags shown in list)
      get "/admin/post_type/#{post_type.id}/posts"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)

      # Post edit sidebar (Finding 5)
      get "/admin/post_type/#{post_type.id}/posts/#{my_post.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end

    it 'escapes payload in search page (Finding 7)' do
      get '/admin/search', params: { q: malicious_payload }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end
  end

  describe 'User Management and Settings' do
    it 'escapes in users index (Finding 14)' do
      admin.update!(first_name: malicious_payload, last_name: '')
      get '/admin/users'
      expect(response).to have_http_status(:ok)
      # User name is titleized: <span>alert(1)</span> -> <Span>Alert(1)</Span>
      expect(response.body).to match(/#{Regexp.escape(ERB::Util.html_escape(malicious_payload))}/i)
    end

    it 'escapes in roles index (Finding 13)' do
      current_site.user_roles.create!(name: malicious_payload, slug: "malicious-role-#{SecureRandom.hex(4)}")
      get '/admin/user_roles'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end

    it 'escapes in sites index (Finding 12)' do
      current_site.update!(name: malicious_payload)
      get '/admin/settings/sites'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end

    it 'escapes in post types index (Finding 11)' do
      current_site.post_types.create!(name: malicious_payload, slug: "malicious-pt-#{SecureRandom.hex(4)}")
      get '/admin/settings/post_types'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(escaped_payload)
    end
  end
end
