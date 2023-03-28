module CamaleonCms
  class Post < CamaleonCms::PostDefault
    include CamaleonCms::CategoriesTagsForPosts

    alias_attribute :post_type_id, :taxonomy_id
    default_scope -> { where(post_class: 'Post').order(post_order: :asc, created_at: :desc) }

    # DEPRECATED
    has_many :post_relationships, class_name: 'CamaleonCms::PostRelationship', foreign_key: :objectid,
                                  dependent: :destroy, inverse_of: :post
    has_many :post_types, class_name: 'CamaleonCms::PostType', through: :post_relationships, source: :post_type
    # END DEPRECATED

    has_many :term_relationships, foreign_key: :objectid, dependent: :destroy, inverse_of: :object
    has_many :categories, class_name: 'CamaleonCms::Category', through: :term_relationships, source: :term_taxonomy
    has_many :post_tags, class_name: 'CamaleonCms::PostTag', through: :term_relationships, source: :term_taxonomy
    has_many :comments, class_name: 'CamaleonCms::PostComment', foreign_key: :post_id, dependent: :destroy
    has_many :drafts, lambda {
                        where(status: 'draft_child')
                      }, class_name: 'CamaleonCms::Post', foreign_key: :post_parent, dependent: :destroy
    has_many :children, class_name: 'CamaleonCms::Post', foreign_key: :post_parent, dependent: :destroy,
                        primary_key: :id

    belongs_to :owner, class_name: CamaManager.get_user_class_name, foreign_key: :user_id, required: false
    belongs_to :parent, class_name: 'CamaleonCms::Post', foreign_key: :post_parent, required: false
    belongs_to :post_type, foreign_key: :taxonomy_id, inverse_of: :posts, required: false

    scope :visible_frontend, -> { where(status: 'published') }
    scope :public_posts, lambda {
                           visible_frontend.where(visibility: ['public', ''])
                         } # public posts (not passwords, not privates)
    scope :private_posts, -> { where(visibility: 'private') } # public posts (not passwords, not privates)

    scope :trash, -> { where(status: 'trash') }
    scope :no_trash, -> { where.not(status: 'trash') }
    scope :published, -> { where(status: 'published') }
    scope :root_posts, -> { where(post_parent: [nil, '']) }
    scope :drafts, -> { where(status: %w[draft draft_child]) }
    scope :pending, -> { where(status: 'pending') }
    scope :latest, -> { reorder(created_at: :desc) }

    validates_with CamaleonCms::PostUniqValidator
    attr_accessor :show_title_with_parent

    before_create :fix_post_order, if: ->(p) { !p.post_order.present? || p.post_order.zero? }

    # return all parents for current page hierarchy ordered bottom to top
    def parents
      cama_fetch_cache("parents_#{id}") do
        res = []
        p = parent
        while p
          res << p
          p = p.parent
        end
        res
      end
    end

    # return all children elements for current post (page hierarchy)
    def full_children
      cama_fetch_cache("full_children_#{id}") do
        res = children.to_a
        res.each { |c| res += c.full_children }
        res
      end
    end

    # return the post type of this post (DEPRECATED)
    def get_post_type_depre
      post_types.reorder(nil).first
    end

    # check if this post was published
    def published?
      status == 'published'
    end

    # check if this is in pending status
    def pending?
      status == 'pending'
    end

    # check if this is in draft status
    def draft?
      status == 'draft' || status == 'draft_child'
    end

    def draft_child?
      status == 'draft_child'
    end

    # check if this is in trash status
    def trash?
      status == 'trash'
    end

    # check if current post can manage content
    # return boolean
    def manage_content?(posttype = nil)
      get_option('has_content', (posttype || post_type).get_option('has_content', true))
    end

    # return boolean
    def manage_layout?(posttype = nil)
      get_option('has_layout', (posttype || post_type).get_option('has_layout', false))
    end

    # check if current post can manage template
    # return boolean
    def manage_template?(posttype = nil)
      get_option('has_template', (posttype || post_type).get_option('has_template', true))
    end

    # check if current post can manage summary
    # return boolean
    def manage_summary?(posttype = nil)
      get_option('has_summary', (posttype || post_type).get_option('has_summary', true))
    end

    # check if current post can manage picture
    # return boolean
    def manage_picture?(posttype = nil)
      get_option('has_picture', (posttype || post_type).get_option('has_picture', true))
    end

    # check if current post can manage comments
    # return boolean
    def manage_comments?(posttype = nil)
      get_option('has_comments', (posttype || post_type).get_option('has_comments', false))
    end

    # check if the post can be commented
    # sample: @post.can_commented?
    # return Boolean (true/false)
    # to enable comments for current post, use this: post.set_meta('has_comments', '1'). Note: Parent PostType should be enabled for comments too: post_type.set_option('has_comments', true)
    def can_commented?
      manage_comments? && get_meta('has_comments').to_s == '1'
    end

    # check if is required picture for current post
    def is_required_picture?
      post_type.get_option('is_required_picture', false)
    end

    # define post configuration for current post
    # possible key values (String):
    #   has_content, boolean (default true)
    #   has_summary, boolean (default true)
    #   has_seo, boolean (default true)
    #   has_picture, boolean (default true)
    #   has_template, boolean (default false)
    #   has_comments, boolean (default false)
    #   default_layout:  (string) (default layout) # this is still used if post type was inactivated layout and overwritten by dropdown in post view
    #   default_template:  (string) (default template) # this is still used if post type was inactivated template and overwritten by dropdown in post view
    #   has_layout:  (boolean) (default false)
    #   skip_fields:  (array) (default empty) array of custom field keys to avoid for this post, sample: ["subtitle", "icon"]
    # val: value for the setting
    def set_setting(key, val)
      set_option(key, val)
    end

    # assign multiple settings
    def set_settings(settings = {})
      settings.each do |key, val|
        set_setting(key, val)
      end
    end

    # put a new order position for this post
    # new_order_position: (Integer) position number
    # return nil
    def set_position(new_order_position)
      update_column('post_order', new_order_position)
    end

    # save the summary for current post
    # summary: Text String without html
    def set_summary(summary)
      set_meta('summary', summary)
    end

    # check if current post permit manage seo attrs
    # has_keywords: used until next version (deprecated to use has_seo)
    # return boolean
    def manage_seo?(posttype = nil)
      get_option('has_seo', get_option('has_keywords', false)) || (posttype || post_type).manage_seo?
    end
    alias manage_keywords? manage_seo? # method name deprecated to use manage_seo?

    # save the thumbnail url for current post
    # thumb_url: String url
    def set_thumb(thumb_url)
      set_meta('thumb', thumb_url)
    end

    # save the layout name to be used on render this post
    # layout_name: String layout name: my_layout.html.erb => 'my_layout'
    def set_layout(layout_name)
      set_meta('layout', layout_name)
    end

    # return the layout assigned to this post
    # post_type: post type owner of this post
    def get_layout(posttype = nil)
      return get_option('default_layout') unless manage_layout?(posttype)

      get_meta('layout', get_option('default_layout') || (posttype || post_type).get_option('default_layout', nil))
    end

    # return the template assigned to this post
    # verify default template defined in post type
    # post_type: post type owner of this post
    def get_template(posttype = nil)
      return get_option('default_template') unless manage_template?(posttype)

      get_meta('template',
               get_option('default_template') || (posttype || post_type).get_option('default_template', nil))
    end

    # increment the counter of visitors
    def increment_visits!
      set_meta('visits', total_visits + 1)
    end

    # return the quantity of visits for this post
    def total_visits
      get_meta('visits', 0).to_i
    end

    # return the quantity of comments for this post
    # TODO comments count to move into cache counter
    def total_comments
      get_meta('comments_count', 0).to_i
    end

    # manage the custom decorators for posts
    # sample: my_post_type.set_option('cama_post_decorator_class', 'ProductDecorator')
    # Sample: https://github.com/owen2345/camaleon-ecommerce/tree/master/app/decorators/
    def decorator_class
      begin
        post_type.get_option('cama_post_decorator_class', 'CamaleonCms::PostDecorator')
      rescue StandardError
        'CamaleonCms::PostDecorator'
      end.constantize
    end

    private

    # calculate a post order when it is empty
    def fix_post_order
      last_post = post_type.posts.where.not(id: nil).last
      self.post_order = last_post.present? ? last_post.post_order + 1 : 1
    end
  end
end
