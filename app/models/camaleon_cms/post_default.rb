module CamaleonCms
  class PostDefault < CamaleonRecord
    include CamaleonCms::Metas
    include CamaleonCms::CustomFieldsRead

    def self.inherited(subclass)
      super

      subclass.class_eval do
        include CamaleonCms::CommonRelationships
      end
    end

    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}posts"

    # attr_accessible :user_id, :title, :slug, :content, :content_filtered, :status,  :visibility, :visibility_value, :post_order, :post_type_key, :taxonomy_id, :published_at, :post_parent, :post_order, :is_feature
    attr_accessor :draft_id

    # attr_accessible :data_options
    # attr_accessible :data_metas
    cattr_accessor :current_user
    cattr_accessor :current_site

    has_many :term_relationships, foreign_key: :objectid, dependent: :destroy, primary_key: :id
    has_many :children, lambda {
                          where(post_class: 'PostDefault')
                        }, class_name: 'CamaleonCms::PostDefault', foreign_key: :post_parent, dependent: :destroy, primary_key: :id
    scope :featured, -> { where(is_feature: true) }

    validates :title, :slug, presence: true

    # callbacks
    before_validation :before_validating
    before_save :before_saved
    before_destroy :destroy_dependencies

    # find a content by slug (support multi language)
    def self.find_by_slug(slug)
      # if current_site.present? && current_site.get_meta("languages_site", []).count <= 1
      #  res = self.where(slug: slug)
      # else
      res = where("#{CamaleonCms::Post.table_name}.slug = ? OR #{CamaleonCms::Post.table_name}.slug LIKE ? ", slug,
                  "%-->#{slug}<!--%")
      # end
      res.reorder('').first
    end

    # return the parent of a post (support for sub contents or tree of posts)
    def parent
      CamaleonCms::Post.where(id: post_parent).first
    end

    # return the author of this Content
    def author
      CamaleonCms::User.find(user_id)
    rescue StandardError
      CamaleonCms::User.admin_scope.first
    end

    # return all menu items in which this post was assigned
    def in_nav_menu_items
      CamaleonCms::NavMenuItem.where(url: id, kind: 'post')
    end

    # Set the meta, field values and the post keywords here
    def set_params(meta, custom_fields, options)
      set_metas(meta)
      set_field_values(custom_fields)
      set_options(options)
    end

    private

    def before_validating
      # self.slug = self.title if self.slug.blank?
      # self.slug = self.slug.to_s.parameterize
    end

    # do all before actions to save the content
    def before_saved
      self.title = 'Untitled' unless title.present?
      self.content_filtered = if content.to_s.include?('<!--:-->')
                                content.translations.transform_values do |value|
                                  value.squish.strip_tags
                                end.to_translate
                              else
                                content.to_s.squish.strip_tags
                              end
    end

    # destroy all dependencies of this content
    # unassign this items from menus
    def destroy_dependencies
      in_nav_menu_items.destroy_all
    end
  end
end
