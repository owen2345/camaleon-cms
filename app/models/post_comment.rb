class PostComment < ActiveRecord::Base
  include Metas
  self.table_name = "comments"
  attr_accessible :user_id, :post_id, :content, :author, :author_email, :author_url, :author_IP,
                  :approved, :agent, :agent, :typee, :comment_parent

  #default_scope order('comments.created_at ASC')
  #approved: approved | pending | spam

  has_many :metas, ->{ where(object_class: 'PostComment')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :children, class_name: "PostComment", foreign_key: :comment_parent, dependent: :destroy
  belongs_to :post, class_name: "Post", foreign_key: :post_id
  belongs_to :parent, class_name: "PostComment", foreign_key: :comment_parent
  belongs_to :user, class_name: "User", foreign_key: :user_id

  default_scope {order('comments.created_at DESC')}

  scope :main, -> { where(:comment_parent => nil) }
  scope :comment_parent, -> { where(:comment_parent => 'is not null') }
  scope :approveds, -> { where(:approved => 'approved') }

  validates :content, :presence => true

  # return the owner of this comment
  def comment_user
    self.user
  end

  # check if this comments is already approved
  def is_approved?
    self.approved == 'approved'
  end

  private

end
