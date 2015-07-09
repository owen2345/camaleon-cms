class Plugins::VisitsCounter::Models::VisitsCounter < ActiveRecord::Base
  # here create your models normally
  # notice: your tables in database will be plugins_social_login in plural (check rails documentation)
  attr_accessible :user_id, :post_id, :session_id, :site_id, :ip, :referrer, :data, :user_agent
  belongs_to :site, class_name: "Site", foreign_key: :site_id
end
