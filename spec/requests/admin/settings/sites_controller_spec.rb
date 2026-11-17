# frozen_string_literal: true

RSpec.describe 'Admin::Settings::SitesController', type: :request do
  init_site

  let(:admin_user) { create(:user, role: 'admin', site: @site) }
  let(:draws) { [] }
  let(:url_helpers) { Rails.application.routes.url_helpers }

  def post_type_helpers(site)
    site.post_types.pluck(:id).map { |id| :"cama_post_type_#{id}_path" }
  end

  # The helpers of the list that the routes have.
  def helpers_in_routes(helpers)
    helpers.select { |helper| url_helpers.method_defined?(helper) }
  end

  # Each example counts the draws of its request. The reload makes the routes of the example the
  # routes of the last reload.
  def count_draws_from_here
    PluginRoutes.reload
    allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
      draws << :draw
      draw.call
    end
  end

  # With two sites, Camaleon finds the site of a request by its host. The cookie of the sign-in is for
  # that host too.
  before do
    host! @site.slug
    sign_in_as(admin_user, site: @site)
  end

  describe 'POST /admin/settings/sites' do
    before { count_draws_from_here }

    it 'draws the routes 3 times, and they have the route of each post type of the new site' do
      post '/admin/settings/sites', params: { site: { name: 'Second site', slug: 'second.example.test' } }

      expect(response).to redirect_to('/admin/settings/sites')
      expect(draws.size).to eq(3)
      helpers = post_type_helpers(CamaleonCms::Site.find_by!(slug: 'second.example.test'))
      expect(helpers).to be_present
      expect(helpers_in_routes(helpers)).to eq(helpers)
    end

    it 'does not draw the routes for a site that is not valid' do
      post '/admin/settings/sites', params: { site: { name: 'Copy', slug: @site.slug } }

      expect(draws).to be_empty
      expect(response.body).to include('id="new_site"')
    end
  end

  describe 'DELETE /admin/settings/sites/:id' do
    let(:other_site) { create(:site, slug: 'other.example.test', name: 'Other site') }

    it 'draws the routes one time for a site with a language that no other site has' do
      other_site.set_meta('languages_site', %w[en es])
      count_draws_from_here

      delete "/admin/settings/sites/#{other_site.id}"

      expect(response).to redirect_to('/admin/settings/sites')
      expect(draws.size).to eq(1)
      expect(PluginRoutes.all_locales).to eq('en')
    end

    it 'draws the routes one time, and they have no route of a post type of the site' do
      helpers = post_type_helpers(other_site)
      count_draws_from_here
      expect(helpers).to be_present
      expect(helpers_in_routes(helpers)).to eq(helpers)

      delete "/admin/settings/sites/#{other_site.id}"

      expect(response).to redirect_to('/admin/settings/sites')
      expect(draws.size).to eq(1)
      expect(helpers_in_routes(helpers)).to be_empty
    end
  end
end
