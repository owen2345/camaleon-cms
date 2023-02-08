# custom class for site
CamaleonCms::Site.class_eval do
  has_many :attack, class_name: 'Plugins::Attack::Models::Attack'
end

module Plugins
  module Attack
    module Config
      class CustomModels; end
    end
  end
end
