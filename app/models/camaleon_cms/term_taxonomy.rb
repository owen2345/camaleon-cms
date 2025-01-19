module CamaleonCms
  class TermTaxonomy < CamaleonRecord
    include CamaleonCms::Metas
    include CamaleonCms::CustomFieldsRead

    def self.inherited(subclass)
      super

      subclass.class_eval do
        include CamaleonCms::CommonRelationships
      end
    end

    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}term_taxonomy"
    # attr_accessible :taxonomy, :description, :parent_id, :count, :name, :slug, :term_group, :status, :term_order, :user_id
    # attr_accessible :data_options
    # attr_accessible :data_metas

    # TODO: Remove the 1st branch when support will be dropped of Rails < 7.1
    if ::Rails::VERSION::STRING < '7.1.0'
      before_validation(on: %i[create update]) do
        %i[name description].each do |attr|
          next unless new_record? || attribute_changed?(attr)

          self[attr] = ActionController::Base.helpers.sanitize(
            __send__(attr)&.gsub(TRANSLATION_TAG_HIDE_REGEX, TRANSLATION_TAG_HIDE_MAP)
          )&.gsub(TRANSLATION_TAG_RESTORE_REGEX, TRANSLATION_TAG_RESTORE_MAP)
        end
      end
    else
      normalizes :name, :description, with: lambda { |field|
        ActionController::Base.helpers.sanitize(field.gsub(TRANSLATION_TAG_HIDE_REGEX, TRANSLATION_TAG_HIDE_MAP))
                              .gsub(TRANSLATION_TAG_RESTORE_REGEX, TRANSLATION_TAG_RESTORE_MAP)
      }
    end

    # callbacks
    before_validation :before_validating
    before_destroy :destroy_dependencies

    # validates
    validates :name, :taxonomy, presence: true
    validates_with CamaleonCms::UniqValidator

    # relations
    has_many :term_relationships, class_name: 'CamaleonCms::TermRelationship', foreign_key: :term_taxonomy_id,
                                  dependent: :destroy
    # has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
    belongs_to :parent, class_name: 'CamaleonCms::TermTaxonomy', foreign_key: :parent_id, required: false
    belongs_to :owner, class_name: CamaManager.get_user_class_name, foreign_key: :user_id, required: false

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
