# frozen_string_literal: true

# Rows whose taxonomy value maps to no STI subclass instantiate as the base
# CamaleonCms::TermTaxonomy — find_sti_class falls back to base_class by design.
# The base class does not include CommonRelationships (only subclasses receive it
# through the inherited hook), so it has no custom_field_groups association, and
# CustomFieldsRead#_destroy_custom_field_groups must not assume one. Legacy rows
# like taxonomy='ecommerce_coupon' (an old plugin whose model now stores 'coupon')
# hit this on Site#destroy through `has_many :term_taxonomies, dependent: :destroy`.
RSpec.describe 'TermTaxonomy base-class destroy', type: :model do
  let(:conn) { ActiveRecord::Base.connection }
  let(:table) { CamaleonCms::TermTaxonomy.table_name }

  def insert_row(columns)
    now = conn.quote(Time.current)
    cols = "#{columns.keys.join(', ')}, created_at, updated_at"
    vals = "#{columns.values.map { |v| conn.quote(v) }.join(', ')}, #{now}, #{now}"
    conn.execute("INSERT INTO #{table} (#{cols}) VALUES (#{vals})")
    conn.select_value("SELECT MAX(id) FROM #{table}")
  end

  it 'destroys a row with an unmapped taxonomy value cleanly' do
    id = insert_row(taxonomy: 'ecommerce_coupon', name: 'Legacy Coupon')
    record = CamaleonCms::TermTaxonomy.find(id)
    expect(record).to be_instance_of(CamaleonCms::TermTaxonomy)

    expect { record.destroy! }.not_to raise_error
    expect(CamaleonCms::TermTaxonomy.exists?(id)).to be(false)
  end

  it 'destroys a site with such a legacy child row cleanly' do
    site = create(:site)
    id = insert_row(taxonomy: 'ecommerce_coupon', name: 'Legacy Coupon', parent_id: site.id)

    expect { site.destroy! }.not_to raise_error
    expect(CamaleonCms::TermTaxonomy.exists?(id)).to be(false)
  end
end
