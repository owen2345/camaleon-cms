class CamaleonCms::PostComment < ActiveRecord::Base
  include CamaleonCms::Metas
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}comments"
  # attr_accessible :user_id, :post_id, :content, :author, :author_email, :author_url, :author_IP, :approved, :agent, :agent, :typee, :comment_parent, :is_anonymous
  attr_accessor :is_anonymous

  #default_scope order('comments.created_at ASC')
  #approved: approved | pending | spam

  has_many :metas, ->{ where(object_class: 'PostComment')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  has_many :children, class_name: "CamaleonCms::PostComment", foreign_key: :comment_parent, dependent: :destroy
  belongs_to :post, class_name: "CamaleonCms::Post", foreign_key: :post_id
  belongs_to :parent, class_name: "CamaleonCms::PostComment", foreign_key: :comment_parent
  belongs_to :user, class_name: PluginRoutes.static_system_info['user_model'].presence || 'CamaleonCms::User', foreign_key: :user_id

  default_scope {order("#{CamaleonCms::PostComment.table_name}.created_at DESC")}

  scope :main, -> { where(:comment_parent => nil) }
  scope :comment_parent, -> { where(:comment_parent => 'is not null') }
  scope :approveds, -> { where(:approved => 'approved') }

  validates :content, :presence => true
  validates_presence_of :author, :author_email, if: Proc.new { |c| c.is_anonymous.present? }
  after_create :update_counter
  after_destroy :update_counter

  # return the owner of this comment
  def comment_user
    self.user
  end

  # check if this comments is already approved
  def is_approved?
    self.approved == 'approved'
  end

  private
  # update comment counter
  def update_counter
    p = self.post
    p.set_meta("comments_count", p.comments.count) if p.present?
  end

end
