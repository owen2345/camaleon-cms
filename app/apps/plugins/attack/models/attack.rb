class Plugins::Attack::Models::Attack < ActiveRecord::Base
  belongs_to :site, class_name: "CamaleonCms::Site"
end
