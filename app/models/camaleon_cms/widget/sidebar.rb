module CamaleonCms
  module Widget
    class Sidebar < CamaleonCms::TermTaxonomy
      default_scope { where(taxonomy: :sidebar) }

      has_many :metas, lambda {
                         where(object_class: 'Widget::Sidebar')
                       }, class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy
      has_many :assigned, foreign_key: :post_parent, dependent: :destroy
      belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id

      # scopes
      scope :default_sidebar, -> { where(slug: 'default-sidebar') }
      scope :all_sidebar, -> { where('slug != \'default-sidebar\'') }

      # assign the widget into this sidebar
      # widget: string(slug)/object
      # data: {title, content}
      def add_widget(widget, data = {})
        widget = site.widgets.where(slug: widget).first if widget.is_a?(String)
        data[:widget_id] = widget.id
        assigned.create(data)
      end
    end
  end
end
