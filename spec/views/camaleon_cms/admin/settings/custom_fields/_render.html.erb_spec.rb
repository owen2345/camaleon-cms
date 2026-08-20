# frozen_string_literal: true

require 'rails_helper'

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

  def build_field(slug)
    instance_double(
      CamaleonCms::CustomField,
      slug: slug,
      id: 12,
      name: slug.to_s.humanize,
      description: nil,
      options: { 'field_key' => 'text_area', 'required' => false, 'multiple' => false, 'default_value' => '' }
    ).tap do |field|
      allow(field).to receive(:get_option).and_return(nil)
      allow(field).to receive(:get_option).with('field_key').and_return('text_area')
      allow(field).to receive(:get_option).with('render').and_return(nil)
      allow(field).to receive(:get_option).with('disabled').and_return(nil)
      allow(field).to receive(:get_option).with('readonly').and_return(nil)
      allow(field).to receive(:get_option).with('required').and_return(false)
      allow(field).to receive(:get_option).with('multiple').and_return(false)
      allow(field).to receive(:get_option).with('default_value').and_return('')
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
