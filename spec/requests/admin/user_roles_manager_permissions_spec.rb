# frozen_string_literal: true

require 'rails_helper'

# `set_default_user_roles` writes every `ROLES` key into the admin role's `_post_type_` and
# `_manager_` metas, but only when the site is created. A key added to `ROLES` afterwards is
# therefore absent from those metas on every site seeded earlier, and the role editor used to render
# an absent key as an unchecked box — so `contact_form_unfiltered_html` read as "denied to
# administrators".
#
# It never was. `Ability#initialize` answers `can :manage, :all` for any user whose role is `admin`
# and returns before either meta is read, and `Admin::UserRolesController#update` writes them only
# `if @user_role.editable?` — false for the default admin role, whose `term_group` is `-1`. Those
# metas are neither read nor writable for that role: they are display state, and the display was
# wrong.
#
# Deriving the checked state from the role rather than from the meta is what keeps this true for keys
# added later. The alternative — a backfill task per new key, of which there are already two —
# mutates data nothing consults, and only helps operators who know to run it.
RSpec.describe 'Admin::UserRolesController permission rendering', type: :request do
  init_site

  let(:admin_user) do
    create(:user, username: 'admin', password: 'admin123', password_confirmation: 'admin123',
                  role: 'admin', site: @site)
  end

  before { sign_in_as(admin_user, site: @site) }

  def manager_box(doc, key)
    doc.at_css(%(input[name="rol_values[manager][#{key}]"]))
  end

  # `post_content_unfiltered_html` lives in ROLES[:post_type], not ROLES[:manager] — it is granted
  # per post type, so it renders as one checkbox per post type rather than a single box.
  def post_type_boxes(doc, key)
    doc.css(%(input[name="rol_values[post_type][#{key}][]"]))
  end

  def edit_role(role)
    get "/admin/user_roles/#{role.id}/edit"
    Nokogiri::HTML5.parse(response.body)
  end

  def checked?(node)
    node.attributes.key?('checked')
  end

  describe 'the default admin role' do
    let(:default_admin) { @site.user_roles.find_by(slug: 'admin', term_group: -1) }

    # Exactly the shape of a site seeded before these keys existed.
    before do
      default_admin.set_meta("_manager_#{@site.id}", { themes: 1 })
      default_admin.set_meta("_post_type_#{@site.id}", { edit: [] })
    end

    it 'renders every manager permission checked even when the stored meta predates the key' do
      doc = edit_role(default_admin)

      CamaleonCms::UserRole::ROLES[:manager].each do |permission|
        box = manager_box(doc, permission[:key])
        expect(box).to be_present, "no checkbox rendered for #{permission[:key]}"
        expect(checked?(box)).to be(true), "#{permission[:key]} rendered unchecked for the admin role"
      end
    end

    it 'renders every post-type permission checked on the same terms' do
      doc = edit_role(default_admin)

      CamaleonCms::UserRole::ROLES[:post_type].each do |permission|
        boxes = post_type_boxes(doc, permission[:key])
        next if boxes.empty? # manage_categories/manage_tags are hidden for post types that lack them

        expect(boxes.all? { |b| checked?(b) }).to be(true),
                                                  "#{permission[:key]} rendered unchecked for the admin role"
      end
    end

    it 'covers the two permissions this release adds, which no existing site has in its meta' do
      doc = edit_role(default_admin)

      expect(checked?(manager_box(doc, 'contact_form_unfiltered_html'))).to be(true)

      boxes = post_type_boxes(doc, 'post_content_unfiltered_html')
      expect(boxes).not_to be_empty
      expect(boxes.all? { |b| checked?(b) }).to be(true)
    end

    # The boxes were already inert for this role — the controller refuses to write its meta — so the
    # rendering now says what `can :manage, :all` already does, rather than inviting an edit that is
    # silently discarded.
    it 'keeps the permissions non-editable' do
      doc = edit_role(default_admin)

      expect(manager_box(doc, 'contact_form_unfiltered_html').attributes).to have_key('disabled')
    end

    it 'hides the bulk selection actions, which would drive locked checkboxes' do
      doc = edit_role(default_admin)

      expect(doc.at_css('#checked-actions')).to be_nil
    end

    it 'explains why the permissions cannot be changed' do
      doc = edit_role(default_admin)

      expect(doc.text).to include('administrators')
    end
  end

  # An `admin`-slugged role that IS editable (`term_group: nil`) is the case that used to be
  # half-right: it rendered everything checked but stayed editable, so an operator could untick a box
  # that `can :manage, :all` would go on granting anyway. It is now locked on the same terms as the
  # default admin role — and locked in the controller too, because a disabled checkbox is not
  # submitted, so locking the view alone would have made the next save clear the stored meta.
  describe 'an editable role slugged admin' do
    let(:editable_admin) do
      @site.user_roles.create!(name: 'Editable Admin', slug: 'admin', term_group: nil)
    end

    before { editable_admin.set_meta("_manager_#{@site.id}", { themes: 1 }) }

    it 'renders its permissions checked and locked' do
      doc = edit_role(editable_admin)

      box = manager_box(doc, 'contact_form_unfiltered_html')
      expect(checked?(box)).to be(true)
      expect(box.attributes).to have_key('disabled')
    end

    it 'does not clear the stored permissions when the role is saved' do
      # Exactly what the browser sends for a form whose permission boxes are all disabled.
      patch "/admin/user_roles/#{editable_admin.id}",
            params: { user_role: { name: 'Editable Admin', slug: 'admin', description: 'x' } }

      # Asserted key-agnostically: `get_meta` yields indifferent access when it parses stored JSON,
      # but the raw hash as written when the value is still cached in this process.
      stored = editable_admin.reload.get_meta("_manager_#{@site.id}")
      expect(stored.to_h.transform_keys(&:to_s)).to eq('themes' => 1)
    end

    it 'still saves the role attributes themselves' do
      patch "/admin/user_roles/#{editable_admin.id}",
            params: { user_role: { name: 'Renamed', slug: 'admin', description: 'x' } }

      expect(editable_admin.reload.name).to eq('Renamed')
    end
  end

  describe 'a non-admin role' do
    let(:editor) { @site.user_roles.create!(name: 'Editor', slug: 'editor') }

    it 'still renders from its own stored meta' do
      editor.set_meta("_manager_#{@site.id}", { themes: 1 })

      doc = edit_role(editor)

      expect(checked?(manager_box(doc, 'themes'))).to be(true)
      expect(checked?(manager_box(doc, 'contact_form_unfiltered_html'))).to be(false)
      expect(post_type_boxes(doc, 'post_content_unfiltered_html').any? { |b| checked?(b) }).to be(false)
    end

    it 'renders a granted permission as checked' do
      editor.set_meta("_manager_#{@site.id}", { contact_form_unfiltered_html: 1 })

      doc = edit_role(editor)

      expect(checked?(manager_box(doc, 'contact_form_unfiltered_html'))).to be(true)
    end
  end
end
