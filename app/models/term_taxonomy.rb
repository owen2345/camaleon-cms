class UniqValidator < ActiveModel::Validator
  def validate(record)
    #record.errors[:base] << "#{I18n.t('admin.users.message.requires_different_name')}" if TermTaxonomy.where(name: record.name).where.not(id: record.id).where("term_taxonomy.taxonomy" => record.taxonomy).where("term_taxonomy.parent_id" => record.parent_id).size > 0
    record.errors[:base] << "#{I18n.t('admin.post.message.requires_different_slug')}" if TermTaxonomy.where(slug: record.slug).where.not(id: record.id).where("term_taxonomy.taxonomy" => record.taxonomy).where("term_taxonomy.parent_id" => record.parent_id).size > 0
  end
end
class TermTaxonomy < ActiveRecord::Base
  include Metas
  include CustomFieldsRead
  self.table_name = "term_taxonomy"
  attr_accessible :taxonomy, :description, :parent_id, :count, :name, :slug, :term_group, :status, :term_order

  # callbacks

  after_create :set_default_options
  before_validation :before_validating
  before_destroy :destroy_dependencies
  # validates
  validates :name, :taxonomy, presence: true
  validates_with UniqValidator

  #default_scope order('users.role ASC')
  # relations
  has_many :term_relationships, :class_name => "TermRelationship", :foreign_key => :term_taxonomy_id, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  belongs_to :parent, class_name: "TermTaxonomy", foreign_key: :parent_id
  has_many :user_relationships, :class_name => "UserRelationship", :foreign_key => :term_taxonomy_id, dependent: :destroy
  has_many :users, through: :user_relationships, :source => :user

  def self.wp_taxonomies
    data = {}
    data[:category] = {
        options: {
        },
        options_editable:{

        }
    }
    data[:post_tag] = {
        options: {
        },
        options_editable:{

        }
    }
    data[:nav_menu] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:nav_menu_item] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:post_type] = {
        options: {
            has_category: false,
            has_tags: false,
            has_summary: true,
            has_content: true,
            has_comments: true,
            has_picture: true,
            has_template: true,
            not_deleted: false
        },
        options_editable:{
            has_category:{type: 'checkbox', label: 'Has Category'},
            has_tags:{type: 'checkbox', label: 'Has Tags'}
        }
    }
    data[:site] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:widget] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:form] = {
        options: {
        },
        options_editable:{
        }
    }
    data.to_sym
  end

  def self.find_by_slug(slug)
    self.where("term_taxonomy.slug = ? OR term_taxonomy.slug LIKE ? ", slug, "%-->#{slug}<!--%").reorder("").first
  end

  def short_code
    # "[#{taxonomy} id=#{id}]"
    "[#{taxonomy} \"#{slug}\"]"
  end


  def add_post(object)
    post_id = defined?(object.id) ? object.id : object.to_i
    term_relationships.create({objectid: post_id}) if post_id > 0
  end
  def add_user(user)
    user_id = defined?(user.id) ? user.id : user.to_i
    user_relationships.create({user_id: user_id}) if user_id > 0
  end


  def term_children(taxy='')
    TermTaxonomy.where(taxonomy: taxy).where("term_taxonomy.parent_id = ?", self.id)
  end

  def children
    TermTaxonomy.where("term_taxonomy.parent_id = ?", self.id)
  end


  def set_options_from_form(metas = [])
    if metas.present?
      metas.each do |key, value|
        self.set_option(key, value)
      end
    end
  end

  def in_nav_menu_items
    NavMenuItem.joins(:metas).where("value LIKE ?","%\"object_id\":\"#{self.id}\"%").where("value LIKE ?","%\"type\":\"#{self.taxonomy}\"%").readonly(false)
  end

  private

  def set_default_options
    begin
      values = TermTaxonomy::wp_taxonomies[taxonomy.to_sym][:options]
      self.set_meta('_default', values) if self.id.present? && values.present?
      values
    rescue
      # TODO what happend here (values = TermTaxonomy::wp_taxonomies[taxonomy.to_sym][:options]) undefined method `[]' for nil:NilClass
    end
  end

  def before_validating
    slug = self.slug
    slug = self.name if slug.blank?
    self.name = slug unless self.name.present?
    if slug.to_s.translations.present?
      self.slug = slug.to_s.translations.inject({}) { |h, (k, v)| h[k] = v.to_s.parameterize; h }.to_translate
    else
      self.slug = slug.to_s.parameterize
    end
  end

  def destroy_dependencies
    in_nav_menu_items.destroy_all
  end


end
