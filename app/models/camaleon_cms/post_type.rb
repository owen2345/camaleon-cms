module CamaleonCms
  class PostType < CamaleonCms::TermTaxonomy
    normalize_attrs(:description)

    alias_attribute :site_id, :parent_id

    has_many :categories, foreign_key: :parent_id, dependent: :destroy, inverse_of: :post_type_parent
    has_many :post_tags, foreign_key: :parent_id, dependent: :destroy, inverse_of: :post_type
    has_many :posts, foreign_key: :taxonomy_id, dependent: :destroy, inverse_of: :post_type
    has_many :comments, through: :posts
    has_many :posts_through_categories, foreign_key: :objectid, through: :term_relationships, source: :object
    has_many :posts_draft, class_name: 'CamaleonCms::Post', foreign_key: :taxonomy_id, dependent: :destroy,
                           inverse_of: :post_type
    has_many :field_group_taxonomy, -> { where('object_class LIKE ?', 'PostType_%') },
             class_name: 'CamaleonCms::CustomField', foreign_key: :objectid, dependent: :destroy, inverse_of: :owner

    belongs_to :owner, class_name: CamaManager.get_user_class_name.to_s, foreign_key: :user_id, optional: true,
                       inverse_of: false
    belongs_to :site, foreign_key: :parent_id, optional: true, inverse_of: :post_types

    scope :visible_menu, -> { where(term_group: nil) }
    scope :hidden_menu, -> { where(term_group: -1) }

    before_destroy :destroy_field_groups
    after_create :set_default_site_user_roles
    after_create :refresh_routes
    after_destroy :refresh_routes
    after_update :refresh_routes,
                 if: proc { |obj| obj.destroyed_by_association.blank? && obj.saved_change_to_attribute?(:slug) }
    before_update :default_category

    # check if current post type manage categories
    def manage_categories?
      options[:has_category] || options[:has_single_category]
    end

    # hide or show this post type on admin -> contents -> menu
    # true => enable, false => disable
    def toggle_show_for_admin_menu(flag)
      update(term_group: flag == true ? nil : -1)
    end

    # check if this post type is shown on admin -> contents -> menu
    def show_for_admin_menu?
      term_group.nil?
    end

    # check if this post type manage post tags
    def manage_tags?
      options[:has_tags]
    end

    # check if this post type permit to manage seo attrs in posts
    def manage_seo?
      get_option('has_seo', get_option('has_keywords', true))
    end

    # assign settings for this post type
    # default values: {
    #   has_category: false,
    #   has_tags: false,
    #   has_summary: true,
    #   has_content: true,
    #   has_comments: false,
    #   has_picture: true,
    #   has_template: true,
    #   has_seo: true,
    #   not_deleted: false,
    #   has_layout: false,
    #   default_layout: '',
    #   contents_route_format: 'post'
    # }
    def set_settings(settings = {})
      settings.each do |key, val|
        set_option(key, val)
      end
    end

    # set or update a setting for this post type
    def set_setting(key, value)
      set_option(key, value)
    end

    # select full_categories for the post type, include all children categories
    def full_categories
      CamaleonCms::Category.where(site_id: site_id, post_type_id: id)
    end

    # return default category for this post type
    # only return a category for post types that manage categories
    def default_category
      return unless manage_categories?

      cat = categories.find_by_slug('uncategorized') # rubocop:disable Rails/DynamicFindBy
      unless cat
        cat = categories.create({ name: 'Uncategorized', slug: 'uncategorized', parent_id: id })
        cat.set_option('not_deleted', true)
      end
      cat
    end

    # add a post for current model
    #   title: title for post,    => required
    #   content: html text content, => required
    #   thumb: image url, => default (empty). check https://camaleon.website/api-methods.html#section_fileuploads
    #   categories: [1,3,4,5],    => default (empty)
    #   tags: String comma separated, => default (empty)
    #   slug: string key for post,    => default (empty)
    #   summary: String resume (optional)  => default (empty)
    #   post_order: Integer to define the order position in the list (optional)
    #   fields: Hash of values for custom fields, sample => fields: {subtitle: 'abc', icon: 'test' } (optional)
    #   settings: Hash of post settings, sample => settings: (optional, see more in post.set_setting(...))
    #     {has_content: false, has_summary: true, default_layout: 'my_layout', default_template: 'my_template' }
    #   data_metas: {template: "", layout: ""}
    # sample:
    # my_posttype.add_post(
    #   title: "My Title", post_order: 5, content: 'lorem_ipsum',
    #   settings: {
    #     default_template: "home/counters", has_content: false, has_seo: false, skip_fields: ["sub_tite", 'banner']
    #   },
    #   fields: { pattern: true, bg: 'https://www.reallusion.com/de/images/3dx5/whatsnew/3dx5_features_banner_bg_02.jpg' }
    # )
    #   More samples here: https://gist.github.com/owen2345/eba9691585ed78ad6f7b52e9591357bf
    # return created post if it was created, else return errors
    def add_post(args)
      _fields = args.delete(:fields)
      _settings = args.delete(:settings)
      _summary = args.delete(:summary)
      _order_position = args.delete(:order_position)
      args[:data_categories] = _categories = args.delete(:categories)
      args[:data_tags] = args.delete(:tags)
      _thumb = args.delete(:thumb)
      p = posts.new(args)
      p.slug = site.get_valid_post_slug(p.title.parameterize) if p.slug.blank?
      if p.save!
        _settings.each { |k, v| p.set_setting(k, v) } if _settings.present?
        p.set_position(_order_position) if _order_position.present?
        p.set_summary(_summary) if _summary.present?
        p.set_thumb(_thumb) if _thumb.present?
        _fields.each { |k, v| p.save_field_value(k, v) } if _fields.present?
        p.decorate
      else
        p.errors
      end
    end

    # return all available route formats of this post type for content posts
    # rubocop:disable Layout/LineLength
    def contents_route_formats
      {
        'post_of_post_type' => '<code>/group/:post_type_id-:title/:slug</code><br>  (Sample: https://localhost.com/group/17-services/myservice.html)',
        'post_of_category' => '<code>/category/:category_id-:title/:slug</code><br>  (Sample: https://localhost.com/category/17-services/myservice.html)',
        'post_of_category_post_type' => '<code>/:post_type_title/category/:category_id-:title/:slug</code><br>  (Sample: https://localhost.com/services/category/17-services/myservice.html)',
        'post_of_posttype' => '<code>/:post_type_title/:slug</code><br>  (Sample: https://localhost.com/services/myservice.html)',
        'post' => '<code>/:slug</code><br>  (Sample: https://localhost.com/myservice.html)',
        'hierarchy_post' => '<code>/:parent1_slug/:parent2_slug/.../:slug</code><br>  (Sample: https://localhost.com/item-1/item-1-1/item-111.html)'
      }
    end
    # rubocop:enable Layout/LineLength

    # return the configuration of routes for post contents
    def contents_route_format
      get_option('contents_route_format', 'post')
    end

    # verify if this post_type support for page hierarchy (parents)
    def manage_hierarchy?
      get_option('has_parent_structure', false)
    end

    # The option naming the decorator class of this post type's posts (Post#decorator_class). It is
    # loaded as code, so it may name only a CamaleonCms::PostDecorator subclass: any other value is
    # refused at save, for every writer, and one stored before the check is ignored at read and
    # listed by `rake camaleon_cms:security:scan_content`.
    DECORATOR_CLASS_OPTION = 'cama_post_decorator_class'.freeze

    # A class name, which holds nothing but word characters and "::", so a refusal can quote it back.
    DECORATOR_CLASS_NAME_FORMAT = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*\z/
    private_constant :DECORATOR_CLASS_NAME_FORMAT

    # The decorator class the option names: CamaleonCms::PostDecorator for a blank option, the named
    # class when it is a CamaleonCms::PostDecorator subclass, else nil, also for a name that cannot be
    # loaded: safe_constantize still raises for a path through a constant that is not a module ('ENV::X')
    # and for a decorator file that fails to load. One resolver for the save-time check, the read and the
    # security scan, so they agree.
    def self.decorator_class_for(value)
      return CamaleonCms::PostDecorator if value.blank?

      klass = value.to_s.safe_constantize
      klass if klass.is_a?(Class) && klass <= CamaleonCms::PostDecorator
    rescue StandardError, ScriptError
      nil
    end

    # The decorator for this post type's posts: the class its option names, or the default when the
    # option is blank or names no post decorator. Such a stored value predates the save-time check;
    # it is logged and reported, never rewritten.
    def post_decorator_class
      value = get_option(DECORATOR_CLASS_OPTION)
      self.class.decorator_class_for(value) || begin
        Rails.logger.warn("Camaleon CMS - post type #{id} (#{slug}): #{DECORATOR_CLASS_OPTION} '#{value}' " \
                          'names no CamaleonCms::PostDecorator subclass; decorating with the default')
        CamaleonCms::PostDecorator
      end
    end

    # Every way of writing an option (set_option, set_options and its alias, delete_option, the
    # data_options save callback, a direct set_meta) ends here with the whole `_default` options, as a
    # Hash, ActionController::Parameters or a JSON string, so this is where the decorator option is held
    # to the allowlist.
    def set_meta(key, value)
      reject_unknown_decorator_class!(key, value) if key.to_s == '_default'
      super
    end

    private

    # skip save_metas_options callback after save changes (inherit from taxonomy) to call from here manually
    def save_metas_options_skip
      true
    end

    # Refuses, loudly, options whose decorator option names no post decorator, unless the write leaves
    # the stored value as it is: a value stored without passing the check (before it existed, or a
    # removed plugin's decorator) is ignored at read, not a reason to refuse unrelated writes. The
    # writers mutate the memoized options before calling set_meta, so the memo is dropped to keep the
    # record reading what is stored.
    def reject_unknown_decorator_class!(key, options)
      value = decorator_class_option_in(options)
      return if self.class.decorator_class_for(value) || value.to_s == stored_decorator_class_option.to_s

      cama_remove_cache("meta_#{key}")
      errors.add(:base, decorator_class_refusal_message(value))
      raise ActiveRecord::RecordInvalid, self
    end

    # The refusal names the option, and the value when it is a class name, cut short so the flash
    # carrying it fits the session cookie; the admin panel renders that flash raw, so any other value is
    # described, never echoed. Only en.yml carries the keys, so fall back to English.
    def decorator_class_refusal_message(value)
      name = value.to_s
      suffix = name.match?(DECORATOR_CLASS_NAME_FORMAT) ? '' : '_not_a_class_name'
      full_key = "camaleon_cms.admin.post_type.message.decorator_class_refused#{suffix}"
      args = { option: DECORATOR_CLASS_OPTION, value: name.truncate(100) }
      I18n.t(full_key, **args, default: I18n.t(full_key, **args, locale: :en))
    end

    # The decorator option of `options` as get_meta will read it back once set_meta stores them, whatever
    # form the writer passed: the key form written last in a Hash, the parameters' value, the JSON's.
    def decorator_class_option_in(options)
      stored = fix_meta_value(options)
      stored = JSON.parse(stored, allow_duplicate_key: true) if stored.is_a?(String)
      stored[DECORATOR_CLASS_OPTION] if stored.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    # The decorator option as the database holds it before the write under check, from the row get_meta
    # reads; nil for a record not saved yet or an options row that is not a JSON object.
    def stored_decorator_class_option
      return unless persisted?

      row = metas.where(key: '_default').order(:id).first
      stored = JSON.parse(row.value, allow_duplicate_key: true) if row&.value.present?
      stored[DECORATOR_CLASS_OPTION] if stored.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    # assign default roles for this post type
    # define default settings for this post type
    def set_default_site_user_roles
      set_multiple_options(
        { has_category: false, has_tags: false, has_summary: true, has_content: true, has_comments: false,
          has_picture: true, has_template: true, has_seo: true, not_deleted: false, has_layout: false,
          default_layout: '' }.merge(PluginRoutes.fixActionParameter(data_options || {}).to_sym)
      )
      site.set_default_user_roles(self)
      default_category
    end

    # destroy all custom field groups assigned to this post type
    def destroy_field_groups
      if destroyed_by_association.blank? && %w[post page].include?(slug)
        errors.add(:base, 'This post type can not be deleted.')
        return false
      end
      get_field_groups.destroy_all
    end

    # reload routes to enable this post type url, like: http://localhost/my-slug
    def refresh_routes
      PluginRoutes.reload
    end
  end
end
