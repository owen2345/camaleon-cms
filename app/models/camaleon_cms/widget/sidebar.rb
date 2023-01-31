module CamaleonCms
  module Widget
    class Sidebar < CamaleonCms::TermTaxonomy
      has_many :assigned, foreign_key: :post_parent, dependent: :destroy
      belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id

      #scopes
      scope :default_sidebar, -> { where(slug: 'default-sidebar') }
      scope :all_sidebar, -> { where('slug != \'default-sidebar\'') }

      # assign the widget into this sidebar
      # widget: string(slug)/object
      # data: {title, content}
      def add_widget(widget, data = {})
        widget = site.widgets.where(slug: widget).first if widget.is_a?(String)
        data[:widget_id] = widget.id
        self.assigned.create(data)
      end
    end
  end
end
