module CamaleonCms
  module Widget
    class Assigned < CamaleonCms::PostDefault
      default_scope -> { order(:taxonomy_id) }

      def self.type_condition(table = arel_table)
        super.or(table[inheritance_column].eq(name))
      end

      # post_parent: sidebar_id
      # visibility: widget_id
      # comment_count: item_order
      # TODO rename all attribute names (changed comment_count into taxonomy_id)
      alias_attribute :widget_id, :visibility
      alias_attribute :sidebar_id, :post_parent
      alias_attribute :item_order, :taxonomy_id

      # attr_accessible :widget_id, :sidebar_id, :item_order

      belongs_to :sidebar, class_name: 'CamaleonCms::Widget::Sidebar', foreign_key: :post_parent, inverse_of: :assigned,
                           optional: true
      belongs_to :widget, class_name: 'CamaleonCms::Widget::Main', foreign_key: :visibility, inverse_of: :assigned,
                          optional: true

      after_initialize :fix_slug2
      before_create :set_order

      def fix_slug2
        self.slug = 'slug_assigned' if slug.blank?
      end

      private

      def set_order
        self.item_order = sidebar.assigned.count + 1
      end
    end
  end
end
