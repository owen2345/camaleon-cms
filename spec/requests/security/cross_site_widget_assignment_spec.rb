# frozen_string_literal: true

# H9: a widget assignment is loaded scoped to the current site's sidebar (the route's :sidebar_id runs
# through current_site.sidebars.find), but assign#update mass-assigned `sidebar_id` (post_parent) and
# `widget_id` (visibility) straight from the request body. A widget manager could therefore re-point
# their own assignment into another site's sidebar, or at another site's widget, with attacker
# content. The form submits neither key for a move; reordering has its own current-site-scoped action.
RSpec.describe 'Cross-site widget assignment', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }
  let(:admin) { create(:user, role: 'admin', site: current_site) }

  let(:sidebar) { current_site.sidebars.create!(name: 'Main Sidebar', slug: 'main-sidebar') }
  let(:widget) { current_site.widgets.create!(name: 'Text Widget', slug: 'text-widget') }
  let(:assigned) { sidebar.assigned.create!(title: 'Hello', widget_id: widget.id) }

  let(:victim_sidebar) { other_site.sidebars.create!(name: 'Victim Sidebar', slug: 'victim-sidebar') }
  let(:victim_widget) { other_site.widgets.create!(name: 'Victim Widget', slug: 'victim-widget') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def patch_assign(attrs)
    patch "/admin/appearances/widgets/sidebar/#{sidebar.id}/assign/#{assigned.id}", params: { assign: attrs }
  end

  it "ignores a submitted sidebar_id and keeps the assignment in the manager's own sidebar" do
    patch_assign(title: 'Edited', sidebar_id: victim_sidebar.id)

    expect(assigned.reload.sidebar_id.to_s).to eq(sidebar.id.to_s)
  end

  it 'ignores a submitted widget_id and keeps the assignment pointed at its own widget' do
    patch_assign(title: 'Edited', widget_id: victim_widget.id)

    expect(assigned.reload.widget_id.to_s).to eq(widget.id.to_s)
  end

  it 'still applies edits to the fields the form owns' do
    patch_assign(title: 'Edited title', content: 'Edited content')

    expect(assigned.reload.title).to eq('Edited title')
  end
end
