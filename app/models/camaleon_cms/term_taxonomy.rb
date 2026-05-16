module CamaleonCms
  class TermTaxonomy < CamaleonRecord
    include CamaleonCms::Metas
    include CamaleonCms::CustomFieldsRead

    extend CamaleonCms::NormalizeAttrs

    def self.inherited(subclass)
      super

      subclass.class_eval do
        include CamaleonCms::CommonRelationships
      end
    end

    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}term_taxonomy"
    # attr_accessible :taxonomy, :description, :parent_id, :count, :name, :slug, :term_group, :status, :term_order,
    #                 :user_id
    # attr_accessible :data_options
    # attr_accessible :data_metas

    self.inheritance_column = :taxonomy

    def self.sti_name
      name.demodulize.underscore
    end

    def self.polymorphic_name
      name.demodulize
    end

    def self.find_sti_class(type_name)
      # Handle explicit exceptions where database string doesn't match namespacing layout
      case type_name.to_s
      when 'widget'
        return CamaleonCms::Widget::Main
      when 'sidebar'
        return CamaleonCms::Widget::Sidebar
      end

      # Standard conversion for "site" -> "CamaleonCms::Site"
      # or "nav_menu_item" -> "CamaleonCms::NavMenuItem"
      full_class_name = "CamaleonCms::#{type_name.camelize}"
      full_class_name.constantize
    rescue NameError
      # Universal safety net: runtime scan across loaded taxonomy memory models
      found_subclass = CamaleonCms::TermTaxonomy.descendants.find do |klass|
        klass.sti_name == type_name.to_s
      end

      found_subclass || super
    end

    # callbacks
    before_validation :before_validating
    before_destroy :destroy_dependencies

    # validates
    validates :name, :taxonomy, presence: true
    validates_with CamaleonCms::UniqValidator

    # relations
    has_many :term_relationships, class_name: 'CamaleonCms::TermRelationship',
                                  dependent: :destroy
    # has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
    belongs_to :parent, class_name: 'CamaleonCms::TermTaxonomy', optional: true
    belongs_to :owner, class_name: CamaManager.get_user_class_name.to_s, foreign_key: :user_id, optional: true,
                       inverse_of: :term_taxonomies

    # return all children taxonomy
    # sample: sub categories of a category
    def children
      CamaleonCms::TermTaxonomy.where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id = ?", id)
    end

    # return all menu items in which this taxonomy was assigned
    def in_nav_menu_items
      CamaleonCms::NavMenuItem.where(url: id, kind: taxonomy)
    end

    # permit to skip slug validations for children models, like menu items
    def skip_slug_validation?
      false
    end

    private

    # callback before validating
    def before_validating
      slug = self.slug
      slug = name if slug.blank?
      self.name = slug if name.blank?
      self.slug = slug.to_s.parameterize.try(:downcase)
    end

    # destroy all dependencies
    # unassign all items from menus
    def destroy_dependencies
      in_nav_menu_items.destroy_all
    end
  end
end
