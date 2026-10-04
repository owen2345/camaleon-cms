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

    it "replaces an id naming another field with the slug's own field id" do
      own_id = CamaleonCms::CustomField.find_by!(slug: 'own_setting').id
      other_id = CamaleonCms::CustomField.find_by!(slug: 'other_setting').id
      controller.params = ActionController::Parameters.new(
        field_options: { '0' => { 'own_setting' => { 'id' => other_id.to_s, 'values' => { '0' => 'own' } } } }
      )
      permitted = controller.send(:cama_permitted_field_options, 'Plugin', field_groups: plugin.get_field_groups)

      expect(permitted['0']['own_setting']['id']).to eq(own_id)
    end

    # With two fields under the slug (a class-only call spans both plugins), the id the request names is
    # kept, whichever of the two it is, so set_field_values' fallback reaches the field actually submitted.
    it "keeps an id naming one of the slug's own fields" do
      shared = [plugin, other_plugin].map { |owner| register(owner.get_field_groups.first, 'shared_setting') }

      shared.each do |field|
        controller.params = ActionController::Parameters.new(
          field_options: { '0' => { 'shared_setting' => { 'id' => field.id.to_s, 'values' => { '0' => 'v' } } } }
        )

        expect(controller.send(:cama_permitted_field_options, 'Plugin')['0']['shared_setting']['id']).to eq(field.id)
      end
    end

    # The value row refuses a group number that is a list or a hash. The permit gives the shape to
    # the row and drops its content.
    context 'with a group number that is not a scalar' do
      def permitted_group_number(group_number)
        entry = { 'id' => '1', 'group_number' => group_number, 'values' => { '0' => 'own' } }
        controller.params = ActionController::Parameters.new(field_options: { '0' => { 'own_setting' => entry } })
        controller.send(:cama_permitted_field_options, 'Plugin')['0']['own_setting']['group_number']
      end

      it 'keeps a scalar' do
        expect(permitted_group_number('2')).to eq('2')
      end

      it 'gives a list as an empty list' do
        expect(permitted_group_number(%w[5 6])).to eq([])
      end

      it 'gives a hash as an empty hash' do
        expect(permitted_group_number({ 'a' => '5' })).to eq({})
      end

      it 'gives a list of hashes as a list of empty hashes' do
        expect(permitted_group_number([{ 'a' => '5' }])).to eq([{}])
      end
    end

    # The checkboxes field submits `values[]`, a list, where the other fields submit `values[<index>]`.
    context 'with values in both shapes' do
      def permitted_values(values)
        controller.params = ActionController::Parameters.new(
          field_options: { '0' => { 'own_setting' => { 'id' => '1', 'values' => values } } }
        )
        controller.send(:cama_permitted_field_options, 'Plugin')['0']['own_setting']['values']
      end

      it 'keeps a list of scalars' do
        expect(permitted_values(%w[1 3])).to eq(%w[1 3])
      end

      it 'drops a list of hashes' do
        expect(permitted_values([{ 'attr' => 'a' }])).to be_nil
      end

      it 'drops a list that holds a scalar and a hash' do
        expect(permitted_values(['1', { 'attr' => 'a' }])).to be_nil
      end

      it 'keeps a hash keyed by index' do
        expect(permitted_values({ '0' => 'own' })).to eq('0' => 'own')
      end

      # All groups share `group_filter`.
      it 'keeps both shapes in each group' do
        controller.params = ActionController::Parameters.new(
          field_options: {
            '0' => { 'own_setting' => { 'id' => '1', 'values' => %w[1 3] },
                     'other_setting' => { 'id' => '2', 'values' => { '0' => 'other' } } },
            '1' => { 'own_setting' => { 'id' => '1', 'values' => { '0' => 'own' } },
                     'other_setting' => { 'id' => '2', 'values' => %w[4 2] } },
            '2' => { 'own_setting' => { 'id' => '1', 'values' => %w[6 5] },
                     'other_setting' => { 'id' => '2', 'values' => { '0' => 'again' } } }
          }
        )
        permitted = controller.send(:cama_permitted_field_options, 'Plugin')

        expect(permitted['0']['own_setting']['values']).to eq(%w[1 3])
        expect(permitted['0']['other_setting']['values']).to eq('0' => 'other')
        expect(permitted['1']['own_setting']['values']).to eq('0' => 'own')
        expect(permitted['1']['other_setting']['values']).to eq(%w[4 2])
        expect(permitted['2']['own_setting']['values']).to eq(%w[6 5])
        expect(permitted['2']['other_setting']['values']).to eq('0' => 'again')
      end
    end
  end
end
