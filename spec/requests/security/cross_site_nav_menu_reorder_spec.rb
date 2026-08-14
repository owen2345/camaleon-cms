# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M10): NavMenusController#reorder_items took the destination menu FK
# straight from params[:nav_menu_id] and wrote it as each item's parent_id. The items themselves are
# looked up through current_site, but the destination was not, so a manager of one site could re-home
# a menu item under another site's nav menu by posting that site's nav_menu_id. The destination is
# now resolved through current_site.nav_menus (like #add_items), so a foreign menu id is refused.
RSpec.describe 'Cross-site nav-menu item reorder', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }
  let(:admin) { create(:user, role: 'admin', site: current_site) }

  let!(:own_menu) { current_site.nav_menus.create!(name: 'Own Menu', slug: 'own-menu') }
  let!(:item) { own_menu.append_menu_item(label: 'A link', type: 'external', link: 'http://example.com') }
  let!(:victim_menu) { other_site.nav_menus.create!(name: 'Victim Menu', slug: 'victim-menu') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def reorder(menu)
    post "/admin/appearances/nav_menus/#{menu.id}/reorder_items",
         params: { items: { '0' => { 'id' => item.id.to_s } } }
  end

  it "refuses to move an item into another site's menu" do
    expect { reorder(victim_menu) }.to raise_error(ActiveRecord::RecordNotFound)

    expect(item.reload.parent_id).to eq(own_menu.id)
  end

  it "still reorders items within the current site's own menu" do
    reorder(own_menu)

    expect(response).to have_http_status(:ok)
    expect(item.reload.parent_id).to eq(own_menu.id)
  end
end
