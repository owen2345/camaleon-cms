module CamaleonCms
  module Widget
    class Main < CamaleonCms::TermTaxonomy
      default_scope { where(taxonomy: :widget) }
      # attr_accessible :excerpt, :renderer
      # name: "title"
      # description: "content for this"
      # slug: "key for this"
      # status = simple or complex (default)
      # excerpt: string for message
      # renderer: string (path to the template for render this widget)

      has_many :metas, lambda {
                         where(object_class: 'Widget::Main')
                       }, class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy
      belongs_to :owner, class_name: CamaManager.get_user_class_name, foreign_key: :user_id
      belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id

      has_many :assigned, class_name: 'CamaleonCms::Widget::Assigned', foreign_key: :visibility, dependent: :destroy
      before_save :check_excerpt
      def is_simple?
        status == 'simple'
      end

      attr_writer :excerpt, :renderer

      def excerpt
        get_option('excerpt')
      end

      def renderer
        get_option('renderer')
      end

      def short_code
        "[widget #{slug}]"
      end

      private

      def check_excerpt
        set_option('excerpt', @excerpt)
        set_option('renderer', @renderer)
      end
    end
  end
end
