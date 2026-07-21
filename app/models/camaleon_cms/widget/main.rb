module CamaleonCms
  module Widget
    class Main < CamaleonCms::TermTaxonomy
      def self.sti_name
        'widget'
      end

      # attr_accessible :excerpt, :renderer
      # name: "title"
      # description: "content for this"
      # slug: "key for this"
      # status = simple or complex (default)
      # excerpt: string for message
      # renderer: string (path to the template for render this widget)

      belongs_to :owner, class_name: CamaManager.get_user_class_name.to_s, foreign_key: :user_id, inverse_of: :widgets,
                         optional: true
      belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id, inverse_of: :widgets, optional: true

      has_many :assigned, class_name: 'CamaleonCms::Widget::Assigned', foreign_key: :visibility, dependent: :destroy,
                          inverse_of: :widget

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
