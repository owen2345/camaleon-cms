class Plugins::Attack::Models::Attack < ActiveRecord::Base
  attr_accessible :path, :browser_key
  belongs_to :site
end
