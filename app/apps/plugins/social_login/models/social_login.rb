class Plugins::SocialLogin::Models::SocialLogin < ActiveRecord::Base
  # here create your models normally
  # notice: your tables in database will be plugins_social_login in plural (check rails documentation)
  attr_accessible :provider, :uid, :content, :user_id, :site_id
  belongs_to :user, class_name: "User", foreign_key: :user_id
  belongs_to :site, class_name: "Site", foreign_key: :site_id

end
