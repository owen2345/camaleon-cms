class PostUniqValidator < ActiveModel::Validator
  def validate(record)
    if record.status != 'draft'
      slug_array = record.slug.to_s.translations_array
      ptype = record.post_type
      if ptype.present? # only for posts that belongs to a post type model
        posts = ptype.site.posts.where("(#{slug_array.map {|s| "posts.slug LIKE '%-->#{s}<!--%'"}.join(" OR ")} ) OR posts.slug = ?",  record.slug).where("posts.status != 'draft'").where(post_parent: nil).where.not(id: record.id)
        if posts.size > 0
          if slug_array.size > 1
            record.errors[:base] << "#{I18n.t('admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map{|slug| record.slug.to_s.translations.map{|lng, r_slug| "#{r_slug} (#{lng})" if slug.translations_array.include?(r_slug) }.join(",") }.join(",").split(",").uniq.clean_empty.join(", ")} "
          else
            record.errors[:base] << "#{I18n.t('admin.post.message.requires_different_slug')}: #{record.slug.to_s} "
          end
        end
      else
        # validation for other classes
      end
    end
  end
end

class Post < PostDefault
  include CategoriesTagsForPosts
  default_scope ->{ where(post_class: self.name) }
  has_many :metas, ->{ where(object_class: 'Post')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :post_relationships, class_name: "PostRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :posts
  has_many :post_types, class_name: "PostType", through: :post_relationships, :source => :post_type
  has_many :term_relationships, class_name: "TermRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :objects
  has_many :categories, class_name: "Category", through: :term_relationships, :source => :term_taxonomies
  has_many :post_tags, class_name: "PostTag", through: :term_relationships, :source => :term_taxonomies
  has_many :comments, class_name: "PostComment", foreign_key: :post_id, dependent: :destroy
  has_many :drafts, ->{where(status: 'draft')}, class_name: "Post", foreign_key: :post_parent, dependent: :destroy
  has_many :children, class_name: "Post", foreign_key: :post_parent, dependent: :destroy, primary_key: :id

  belongs_to :owner, class_name: "User", foreign_key: :user_id
  belongs_to :parent, class_name: "Post", foreign_key: :post_parent

  scope :visible_frontend, -> {where(status: 'published')}
  scope :public_posts, -> {visible_frontend.where(visibility: ['public', ""]) } #public posts (not passwords, not privates)

  scope :trash, -> {where(status: 'trash')}
  scope :no_trash, -> {where.not(status: 'trash')}
  scope :published, -> {where(status: 'published')}
  scope :drafts, -> {where(status: 'draft')}
  scope :pendings, -> {where(status: 'pending')}
  scope :latest, -> {reorder(created_at: :desc)}

  validates_with PostUniqValidator

  def post_type=(pt)
    @_cache_post_type = pt
  end
  def post_type
    @_cache_post_type ||= (post_types.reorder(nil).first || post_relationships.first.post_type)
  end

  # return template assigned to this post
  def template
    get_meta("template", "")
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
    status == 'draft'
  end

  # check if this is in trash status
  def trash?
    status == 'trash'
  end
end
