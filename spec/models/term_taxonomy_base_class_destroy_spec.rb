# frozen_string_literal: true

# Rows whose taxonomy value maps to no STI subclass instantiate as the base
# CamaleonCms::TermTaxonomy — find_sti_class falls back to base_class by design,
# on the write path too, so create! persists the unmapped value as the root.
# The base class does not include CommonRelationships (only subclasses receive it
# through the inherited hook), so it has no custom_field_groups association, and
# CustomFieldsRead#_destroy_custom_field_groups must not assume one. Legacy rows
# like taxonomy='ecommerce_coupon' (an old plugin whose model now stores 'coupon')
# hit this on Site#destroy through `has_many :term_taxonomies, dependent: :destroy`.
RSpec.describe 'TermTaxonomy base-class destroy', type: :model do
  def create_legacy_row(attrs = {})
    CamaleonCms::TermTaxonomy.create!({ taxonomy: 'ecommerce_coupon', name: 'Legacy Coupon' }.merge(attrs))
  end

  it 'destroys a row with an unmapped taxonomy value cleanly' do
    id = create_legacy_row.id
    record = CamaleonCms::TermTaxonomy.find(id)
    expect(record).to be_instance_of(CamaleonCms::TermTaxonomy)

    expect { record.destroy! }.not_to raise_error
    expect(CamaleonCms::TermTaxonomy.exists?(id)).to be(false)
  end

  it 'destroys a site with such a legacy child row cleanly' do
    site = create(:site)
    id = create_legacy_row(parent_id: site.id).id

    expect { site.destroy! }.not_to raise_error
    expect(CamaleonCms::TermTaxonomy.exists?(id)).to be(false)
  end
end
