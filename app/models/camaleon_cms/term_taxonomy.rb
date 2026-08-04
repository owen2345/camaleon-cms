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
      klass = begin
        "CamaleonCms::#{type_name.camelize}".constantize
      rescue NameError
        nil
      end
      # The ancestry guard keeps a value like "meta" from instantiating an unrelated
      # CamaleonCms class against the term_taxonomy table.
      return klass if klass && klass <= base_class

      # Runtime scan across loaded taxonomy models.
      found = CamaleonCms::TermTaxonomy.descendants.find { |k| k.sti_name == type_name.to_s }
      return found if found

      # `super` resolves fully-qualified external classes (plugin STI outside the CamaleonCms
      # namespace) and enforces ancestry — the scan above only sees classes already loaded, so
      # without this an unloaded plugin taxonomy silently degraded to the base class. Same
      # fallback PostDefault.find_sti_class keeps. Values it cannot place load as the base class,
      # as every row did before native STI.
      begin
        super
      rescue ActiveRecord::SubclassNotFound
        base_class
      end
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
                       inverse_of: false

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
