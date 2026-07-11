# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Widget::Assigned, type: :model do
  let!(:site) { create(:site).decorate }
  let!(:sidebar) do
    CamaleonCms::Widget::Sidebar.create!(
      taxonomy: CamaleonCms::Widget::Sidebar.sti_name,
      name: 'Regression sidebar',
      slug: "regression-sidebar-#{SecureRandom.hex(4)}",
      parent_id: site.id
    )
  end
  let!(:widget) do
    CamaleonCms::Widget::Main.create!(
      taxonomy: CamaleonCms::Widget::Main.sti_name,
      name: 'Regression widget',
      slug: "regression-widget-#{SecureRandom.hex(4)}",
      parent_id: site.id
    )
  end

  def create_assignment(name, item_order)
    described_class.create!(
      title: name,
      slug: "#{name.parameterize}-#{SecureRandom.hex(4)}",
      sidebar: sidebar,
      widget: widget
    ).tap { |assignment| assignment.update!(taxonomy_id: item_order) }
  end

  describe 'native STI compatibility' do
    it 'returns legacy assignments through the sidebar association' do
      legacy_assignment = create_assignment('Legacy assignment', 1)
      legacy_assignment.update!(post_class: 'CamaleonCms::Widget::Assigned')

      expect(sidebar.reload.assigned).to include(legacy_assignment)
      expect(sidebar.assigned.find(legacy_assignment.id).widget).to eq(widget)
    end

    it 'orders mixed legacy and compact assignments by item order' do
      compact_assignment = create_assignment('Compact assignment', 2)
      legacy_assignment = create_assignment('Legacy assignment', 1)
      legacy_assignment.update!(post_class: 'CamaleonCms::Widget::Assigned')

      expect(sidebar.reload.assigned.pluck(:id)).to eq([legacy_assignment.id, compact_assignment.id])
    end

    it 'stores new assignments with the compact discriminator' do
      assignment = create_assignment('New assignment', 1)

      expect(assignment.post_class).to eq('Widget::Assigned')
    end
  end
end
