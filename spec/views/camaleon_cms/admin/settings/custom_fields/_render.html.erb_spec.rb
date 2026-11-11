# frozen_string_literal: true

RSpec.describe 'camaleon_cms/admin/settings/custom_fields/_render.html.erb', type: :view do
  let(:site) { instance_double(CamaleonCms::Site) }
  let(:post_types_relation) { instance_double(ActiveRecord::Relation) }
  let(:record) { instance_double(CamaleonCms::Site, new_record?: false, id: 9) }
  let(:field_slug) { 'footer_description' }
  let(:fields) { [build_field(field_slug)] }
  let(:fields_relation_class) do
    Class.new do
      def initialize(fields)
        @fields = fields
      end

      def where(...)
        self
      end

      def not(...)
        self
      end

      def eager_load(...)
        self
      end

      def size
        @fields.size
      end

      def decorate
        @fields
      end

      def pluck(attribute)
        @fields.map { |field| field.public_send(attribute) }
      end
    end
  end
  let(:fields_relation) { fields_relation_class.new(fields) }
  let(:group) do
    instance_double(
      CamaleonCms::CustomFieldGroup,
      id: 4,
      slug: '_default',
      name: 'Custom Configurations',
      description: nil,
      is_repeat: false,
      fields: fields_relation
    )
  end

  before do
    allow(site).to receive_messages(get_option: false, post_types: post_types_relation)
    allow(post_types_relation).to receive(:pluck).with(:id, :name).and_return([])
    allow(view).to receive(:current_site).and_return(site)
    allow(view).to receive(:hooks_run)

    allow(record).to receive(:get_option).with('skip_fields', []).and_return([])
    allow(record).to receive(:get_fields_grouped).with([field_slug]).and_return({})
  end

  # get_option reads the same options as field.options, so the two agree for each key that a caller sets.
  def build_field(slug, field_key: 'text_area', options: {})
    field_options = { 'field_key' => field_key, 'required' => false, 'multiple' => false, 'default_value' => '' }
                    .merge(options).with_indifferent_access
    instance_double(
      CamaleonCms::CustomField,
      slug: slug,
      id: 12,
      name: slug.to_s.humanize,
      description: nil,
      options: field_options
    ).tap do |field|
      allow(field).to receive(:get_option) { |key| field_options[key] }
    end
  end

  context 'when a new record renders with the fields_name local' do
    let(:record) { instance_double(CamaleonCms::Site, new_record?: true, id: nil) }
    let(:field_slug) { 'colors' }
    let(:fields) do
      multiple_options = [{ 'title' => 'Option 1', 'value' => '1', 'default' => '1' },
                          { 'title' => 'Option 2', 'value' => '2' }]
      [build_field(field_slug, field_key: 'checkboxes', options: { 'multiple_options' => multiple_options })]
    end

    def render_fields(submitted = {})
      allow(view).to receive(:params).and_return(ActionController::Parameters.new(submitted))
      render partial: 'camaleon_cms/admin/settings/custom_fields/render',
             locals: { record: record, field_groups: [group], fields_name: 'item_fields' }
    end

    it 'checks the default options when the request submits no field values' do
      render_fields

      expect(rendered).to have_css("input[name='item_fields[colors][values][]'][value='1'][checked]")
    end

    it 'shows the submitted values and no default option after a failed save' do
      render_fields(item_fields: { '0' => { 'colors' => { 'id' => '12', 'values' => ['2'] } } })

      expect(rendered).to have_no_css("input[name='item_fields[colors][values][]'][checked]")
      expect(rendered).to include('[{"colors":["2"]}]')
    end
  end

  context 'when rendering footer description field' do
    let(:field_slug) { 'footer_description' }

    it 'does not render missing partial errors' do
      render partial: 'camaleon_cms/admin/settings/custom_fields/render',
             locals: { record: record, field_groups: [group] }

      expect(rendered).not_to include('Missing partial')
    end
  end

  context 'when rendering seo site field' do
    let(:field_slug) { 'seo_site' }

    it 'does not render missing partial errors' do
      render partial: 'camaleon_cms/admin/settings/custom_fields/render',
             locals: { record: record, field_groups: [group] }

      expect(rendered).not_to include('Missing partial')
    end
  end
end
