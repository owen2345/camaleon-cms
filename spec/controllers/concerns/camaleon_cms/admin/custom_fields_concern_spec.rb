# frozen_string_literal: true

# The allow-list behind every admin custom-field save. Without field_groups it spans every group
# placed with the object_class, on any record and any site: the contract released plugin controllers
# (and the generated plugin template through 2.9.4) call it under, kept so they do not change. With
# field_groups, the relation a save's form renders, it is confined to those groups' fields.
RSpec.describe CamaleonCms::Admin::CustomFieldsConcern do
  # The block is evaluated on the anonymous controller, where described_class does not resolve.
  controller(CamaleonCms::AdminController) { include CamaleonCms::Admin::CustomFieldsConcern } # rubocop:disable RSpec/DescribedClass

  let(:site) { CamaleonCms::Site.first }
  let(:plugin) { site.get_plugin('own_plugin') }
  let(:other_plugin) { site.get_plugin('other_plugin') }

  def register(group, slug)
    group.add_manual_field({ 'name' => slug.humanize, 'slug' => slug }, { 'field_key' => 'text_box' })
  end

  before do
    register(plugin.add_custom_field_group(name: 'Own', slug: 'own-settings'), 'own_setting')
    register(other_plugin.add_custom_field_group(name: 'Other', slug: 'other-settings'), 'other_setting')
  end

  def allowed_slugs(**options)
    controller.send(:cama_custom_field_allowed_slugs, 'Plugin', **options)
  end

  describe '#cama_custom_field_allowed_slugs' do
    it "spans every group of the class when no field_groups are given, another plugin's included" do
      expect(allowed_slugs).to contain_exactly('own_setting', 'other_setting')
    end

    it "is confined to the given groups' fields" do
      expect(allowed_slugs(field_groups: plugin.get_field_groups)).to contain_exactly('own_setting')
    end

    it 'keeps object_class as the intersect: groups of another class contribute nothing' do
      site_group = site.custom_field_groups.create!(name: 'Site', slug: '_site-settings', object_class: 'Site',
                                                    objectid: site.id)
      register(site_group, 'site_setting')

      expect(allowed_slugs(field_groups: site.get_field_groups)).to be_empty
    end
  end

  describe '#cama_permitted_field_options' do
    let(:payload) do
      { field_options: { '0' => {
        'own_setting' => { 'id' => '1', 'values' => { '0' => 'own' } },
        'other_setting' => { 'id' => '2', 'values' => { '0' => 'other' } }
      } } }
    end

    before { controller.params = ActionController::Parameters.new(payload) }

    it "permits another plugin's slug for a caller naming only the class" do
      permitted = controller.send(:cama_permitted_field_options, 'Plugin')

      expect(permitted['0'].keys).to contain_exactly('own_setting', 'other_setting')
    end

    it "drops another plugin's slug for a caller passing its own groups" do
      permitted = controller.send(:cama_permitted_field_options, 'Plugin', field_groups: plugin.get_field_groups)

      expect(permitted['0'].keys).to contain_exactly('own_setting')
    end
  end
end
